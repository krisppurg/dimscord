## Play audio in voice channel via ytdl/ffmpeg.
## Please note that playing audio may be buggy, please do let us know and we'll try to fix.
import asyncdispatch, ws, asyncnet
import objects, json, constants, options
import strutils, nativesockets, streams, sequtils
import libsodium/sodium, libsodium/sodium_sizes
import osproc
import flatty/binny, random
import opussum
import std/[monotimes, times]
import std/[os, strformat]
randomize()

{.warning[HoleEnumConv]: off.}
{.warning[CaseTransition]: off.}

type
    VoiceOp* = enum
        Identify = 0
        SelectProtocol = 1
        Ready = 2
        Heartbeat = 3
        SessionDescription = 4
        Speaking = 5
        HeartbeatAck = 6
        Resume = 7
        Hello = 8
        Resumed = 9
        ClientDisconnect = 13
        Something = 14

when defined(windows):
    const libsodium_fn* = "libsodium.dll"
elif defined(macosx):
    const libsodium_fn* = "libsodium.dylib"
else:
    const libsodium_fn* = "libsodium.so(|.18|.23)"

{.pragma: sodium_import, importc, dynlib: libsodium_fn.}

proc crypto_secretbox_easy(
    c: ptr uint8, m: cstring,
    mlen: culonglong,
    n: cstring, k: cstring,
): cint {.sodium_import.}

const
    # nonceLen = 24 apparently this hasn't been used
    dataSize = 960 * 2 * 2 # Frame size is 960 16 bit integers and we need 2 channels worth
    idealLength = 20 # How long one voice packet should ideally be in milliseconds

const silencePacket = block:
    var packet: string
    packet.addInt(0xF8)
    packet.addInt(0xFF)
    packet.addInt(0xFE)
    packet

proc logVoice(msg: string) =
    when defined(dimscordDebug):
        echo fmt"[voice]: {msg}"
    else:
        discard

proc logVoice(msg: string, extra: auto) =
    when defined(dimscordDebug):
        logVoice(msg & "\n  ->  " & $extra)

proc makeNonce(v: VoiceClient, header: string): string =
    ## Generate a nonce for an audio packet header
    case v.encryptMode
    of Normal:
        # The nonce bytes are the RTP header
        # Copy the RTP header
        result = header & 0x00.chr.repeat(12) # Append 12 null bytes to get to 24
    of Suffix:
        # The nonce bytes are 24 bytes appended to the payload of the RTP packet
        # Generate 24 random bytes
        result = randombytes(24)
    of Lite:
        # The nonce bytes are 4 bytes appended to the payload of the RTP packet.
        # Incremental 4 bytes (32bit) int value
        result.addUInt32 v.nonce
        inc v.nonce

proc crypto_secretbox_easy(key, msg, nonce: string): string =
    assert key.len == crypto_secretbox_KEYBYTES()
    let length = crypto_secretbox_MACBYTES() + msg.len
    result = newString length
    var cipherText = cast[ptr UncheckedArray[uint8]](createShared(uint8, length))
    defer: freeShared cipherText

    let rc = crypto_secretbox_easy(
        cast[ptr uint8](cipherText),
        msg.cstring,
        msg.len.culonglong,
        nonce.cstring,
        key.cstring
    )
    if rc != 0:
        raise newException(SodiumError, "return code: $#" % $rc)
    # Copy data from cipher text to result
    for i in 0..<length:
        result[i] = cast[char](cipherText[i])

proc extractCloseData(data: string): tuple[code: int, reason: string] = # Code from: https://github.com/niv/websocket.nim/blame/master/websocket/shared.nim#L230
    var data = data
    result.code =
        if data.len >= 2:
            cast[ptr uint16](addr data[0])[].htons.int
        else:
            0
    result.reason = if data.len > 2: data[2..^1] else: ""

proc handleDisconnect(v: VoiceClient, msg: string): bool {.used.} =
    let closeData = extractCloseData(msg)

    logVoice("Socket suspended", (
        code: closeData.code,
        reason: closeData.reason
    ))
    v.stop = true

    result = true

    if closeData.code in [4004, 4006, 4012, 4014]:
        result = false
        if not v.migrate:
            v.stopped = true
            v.time = 0
            v.sequence = 0
            v.paused = false
            v.sent = 0
        v.start = 0.0
        v.loops = 0
        logVoice("Fatal error: " & closeData.reason)

proc sockClosed(v: VoiceClient): bool {.used.} =
    return v.connection == nil or v.connection.tcpSocket.isClosed or v.stop

proc sendSock(v: VoiceClient, opcode: VoiceOp, data: JsonNode) {.async.} =
    if v.sockClosed: return
    # assert v.connection != nil, "Connection needs to be open first"
    logVoice "Sending OP: " & $(int opcode)

    let fut = v.connection.send($(%*{
        "op": opcode.ord,
        "d": data
    }))

    if not (await withTimeout(fut, 20000)):
        logVoice "Payload was taking longer to send. Retrying in 5000ms..."
        await sleepAsync 5000
        await v.sendSock(opcode, data)
        return
    else:
        await fut

proc resumeConnection(v: VoiceClient) {.async, used.} =# To be continued...
    if v.resuming or v.sockClosed: return

    v.resuming = true#might cause issues

    logVoice "Attempting to resume\n" &
        "  server_id: " & v.guild_id & "\n" &
        "  session_id: " & v.session_id

    await v.sendSock(Resume, %*{
        "server_id": v.guild_id,
        "session_id": v.session_id,
        "token": v.token
    })

proc identify(v: VoiceClient) {.async.} =
    if v.sockClosed and not v.resuming: return

    logVoice "Sending identify."

    await v.sendSock(Identify, %*{
        "server_id": v.guild_id,
        "user_id": v.shard.user.id,
        "session_id": v.session_id,
        "token": v.token
    })

proc selectProtocol*(v: VoiceClient) {.async.} =
    ## Tell discord our external IP/port and encryption mode
    if v.sockClosed or not v.gateway_ready: return
    await v.sendSock(SelectProtocol, %*{
        "protocol": "udp",
        "data": {
            "address": v.srcIP,
            "port": v.srcPort,
            "mode": $v.encryptMode
        }
    })

proc sendSpeaking*(v: VoiceClient;
        speaking: bool | set[VoiceSpeakingFlags]) {.async.} =
    if v.sockClosed or not v.gateway_ready: return

    await v.sendSock(Speaking, %* {
        "speaking": cast[int](speaking),
        "delay": 0,
        "ssrc": v.ssrc
    })

proc reconnect*(v: VoiceClient) {.async.} =
    if (v.reconnecting or not v.stop) and not v.reconnectable: return
    v.reconnecting = true
    v.retry_info.attempts += 1

    var url = v.endpoint

    if v.retry_info.attempts > 3:
        if not v.networkError:
            v.networkError = true
            logVoice "A network error has been detected."

    let prefix = if url.startsWith("gateway"): "ws://" & url else: url

    logVoice "Connecting to " & $prefix

    try:
        let future = newWebSocket(prefix)

        v.reconnecting = false
        v.stop = false

        if not (await withTimeout(future, 25000)):
            logVoice "Websocket timed out.\n\n  Retrying connection..."

            await v.reconnect()
            return

        v.connection = await future
        v.hbAck = true

        v.retry_info.attempts = 0
        v.retry_info.ms = max(v.retry_info.ms - 5000, 1000)
        # if not v.migrate: v.start = 0.0

        if v.networkError:
            logVoice "Connection established after network error."
            v.retry_info = (ms: 1000, attempts: 0)
            v.networkError = false
    except:
        logVoice "Error occurred: \n" & getCurrentExceptionMsg()

        log("Failed to connect, reconnecting in " & $v.retry_info.ms & "ms", (
            attempt: v.retry_info.attempts
        ))
        v.reconnecting = false
        await sleepAsync v.retry_info.ms
        await v.reconnect()
        return

# Conversions from here https://stackoverflow.com/a/2182184
proc toBigEndian(num: uint16): uint16 {.inline.} =
    when cpuEndian == bigEndian:
        result = num
    else:
        result = (num shr 8) or (num shl 8)

proc toBigEndian(num: uint32): uint32 {.inline.} =
    when cpuEndian == bigEndian:
        result = num
    else:
        template shrAnd(places, a: uint32): uint32 = ((num shr places) and a)
        template shlAnd(places, a: uint32): uint32 = ((num shl places) and a)
        result = shrAnd(24, 0xff) or
                 shlAnd(8, 0xff0000) or
                 shrAnd(8, 0xf00) or
                 shlAnd(24, uint32 0xff000000)


proc disconnect*(v: VoiceClient, migrate = false) {.async.} =
    ## Disconnects a voice client.
    if v.sockClosed: return

    v.stop = true

    if v.connection != nil:
        logVoice "Voice Client disconnecting..."
        v.connection.close()
    if migrate: v.migrate = true

proc heartbeat(v: VoiceClient) {.async.} =
    if v.sockClosed or not v.gateway_ready: return

    # if not v.hbAck and v.session_id != "":
    #     logVoice "A zombied connection has been detected"
    #     await v.disconnect()
    #     return

    logVoice "Sending heartbeat."
    v.hbAck = false

    await v.sendSock(Heartbeat,
        newJInt getTime().toUnix().BiggestInt * 1000
    )
    v.lastHBTransmit = getTime().toUnixFloat()
    v.hbSent = true

proc setupHeartbeatInterval(v: VoiceClient) {.async.} =
    if not v.heartbeating: return
    v.heartbeating = true

    while not v.sockClosed:
        let hbTime = int((getTime().toUnixFloat() - v.lastHBTransmit) * 1000)

        # Anything less than 8 seconds is unacceptable so discard them
        if hbTime < v.interval - (8 * 1000) and v.lastHBTransmit < 0.2:
            break

        await v.heartbeat()
        await sleepAsync v.interval

proc sendUDPPacket(v: VoiceClient, packet: string) {.async.} =
    ## Sends a UDP packet to the discord servers
    try:
        await v.udp.sendTo(v.dstIP, Port(v.dstPort), packet)
    except:
        logVoice(fmt(
            "Error, packet has been dropped\n  sequence:{v.sequence} time:{v.time}"
        ))

proc recvUDPPacket(v: VoiceClient, size: int): Future[string] {.async.} =
    ## Recvs a UDP packet from anyone (Could be security issue? couldn't get other proc to work though)
    result = v.udp.recvFrom(size).await().data

proc addUint16BE(buffer: var string, val: uint16) =
  buffer.addUint16(toBigEndian val)

proc addUint32BE(buffer: var string, val: uint32) =
  buffer.addUint32(toBigEndian val)


proc sendDiscovery(v: VoiceClient) {.async.} =
    ## Sends ip/port discovery packet to discord.
    ## After calling this, call recvDiscovery to make `v` set its external IP
    var packet: string
    packet.addUint16BE(0x1) # Requesting IP
    packet.addUint16BE(70) # Length minus this and previous field
    packet.addUint32BE(uint32(v.ssrc))
    packet.add chr(0).repeat(66)
    await v.sendUDPPacket(packet)

proc recvDiscovery(v: VoiceClient) {.async.} =
    ## Recvs external ip/port from discord
    var packet = await v.recvUDPPacket(74)
    v.srcIP = packet[8..^3]
    # Find first null byte then strip to that
    for i in 0..<v.srcIP.len:
      if v.srcIP[i] == '\0':
        v.srcIP.setLen(i)
        break
    # Read the port at the end
    v.srcPort = (packet[^2].ord) or (packet[^1].ord shl 8)

proc waitForReady*(v: VoiceClient) {.async.} =
    ## Wait for when the bot is ready to play audio, this is necessary before
    ## using `playFFmpeg` or `playYTDL`.
    while not v.ready:
        await sleepAsync 0

proc updateSpeaking(v: VoiceClient, should_speak: bool) {.async.} =
    await v.sendSpeaking(should_speak)
    v.speaking = should_speak
    asyncCheck v.voice_events.on_speaking(v, should_speak)

proc resume*(v: VoiceClient) {.async.} =
    ## Continue playing audio
    await v.updateSpeaking(true)
    v.paused = false
    v.start = float64(getMonoTime().ticks.int / 1_000_000_000)
    v.loops = 0

proc handleSocketMessage(v: VoiceClient) {.async.} =
    var packet: (Opcode, string)

    var shouldReconnect = true
    while not v.sockClosed:
        try:
            packet = await v.connection.receivePacket()
        except:
            let exceptn = getCurrentExceptionMsg()
            logVoice "Error occurred in websocket ::\n" & getCurrentExceptionMsg()

            v.stop = true
            v.heartbeating = false
            v.gateway_ready = false
            v.ready = false

            if exceptn.startsWith("The semaphore timeout period has expired."):
                logVoice "A network error has been detected."

                v.networkError = true
                break
            else:
                break

        var
            data: JsonNode
            dataVoiceOp = Something

        try:
            data = parseJson(packet[1])
        except:
            logVoice "An error occurred while parsing data: " & packet[1]
            await v.disconnect()
            v.gateway_ready = false
            v.ready = false
            asyncCheck v.voice_events.on_disconnect(v)
            break

        if data["op"].num in VoiceOp.low.ord..VoiceOp.high.ord:
            dataVoiceOp = VoiceOp(data["op"].num)

        case dataVoiceOp
        of Hello: # TODO: resume (after v1.6.0)
            logVoice "Received 'HELLO' from the voice gateway."
            v.interval = int data["d"]["heartbeat_interval"].getFloat

            await v.identify()

            if not v.heartbeating:
                v.heartbeating = true
                asyncCheck v.setupHeartbeatInterval()
        of HeartbeatAck:
            v.lastHBReceived = getTime().toUnixFloat()
            v.hbSent = false
            logVoice "Received heartbeat ACK."

            v.hbAck = true
        of Ready:
            v.gateway_ready = true
            v.dstIP = data["d"]["ip"].str
            v.dstPort = data["d"]["port"].getInt
            v.ssrc = uint32 data["d"]["ssrc"].getInt
            v.udp = newAsyncSocket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
            logVoice(
                fmt"Successfully identified, connecting to {v.dstIP}:{v.dstPort}"
            )
            # We need to get our IP
            await v.sendDiscovery()
            await v.recvDiscovery()
            await v.selectProtocol()
        of Resumed:
            v.resuming = false
            logVoice "Successfully resumed."
        of SessionDescription:
            logVoice "Received session description."
            v.encryptMode = parseEnum[VoiceEncryptionMode](
                data["d"]["mode"].getStr)
            v.secret_key = data["d"]["secret_key"].elems.mapIt(
                chr(it.getInt)).join("")
            v.ready = true
            if v.migrate:
                v.migrate = false
                if v.paused: await v.resume()# we should speak as we resume

            asyncCheck v.voice_events.on_ready(v)
        else: discard
    if packet[0] == Close:
        shouldReconnect = v.handleDisconnect(packet[1])
    v.stop = true

    if shouldReconnect or v.migrate:
        await v.reconnect()
        await sleepAsync 2000

        if not v.networkError: await v.handleSocketMessage()
    else:
        return

proc startSession*(v: VoiceClient) {.async.} =
    ## Start a discord voice session.
    logVoice "Connecting to voice gateway"

    try:
        v.endpoint = v.endpoint.replace(":443", "")
        let future = newWebSocket(v.endpoint)

        if not (await withTimeout(future, 25000)):
            logVoice "Websocket timed out.\n\n  Retrying connection..."
            await v.startSession()
            return
        v.connection = await future
        v.hbAck = true

        logVoice "Socket opened."
    except:
        v.stopped = true
        raise
    try:
        # logVoice "handlong socket" ???
        await v.handleSocketMessage()
    except:
        if not getCurrentExceptionMsg()[0].isAlphaNumeric: return
        raise

proc stopPlaying*(v: VoiceClient) =
    ## Stop the current audio
    v.stopped = true
    v.data = ""

proc elapsed*(v: VoiceClient): float =
    ## Shows the elapsed time in seconds.
    (v.sent*20)/1000

proc sendAudioPacket*(v: VoiceClient, data: string) {.async.} =
    ## Sends opus encoded packet
    var header = newStringOfCap(12)
    header.addUint8(0x80)
    header.addUint8(0x78)
    header.addUint16(toBigEndian uint16 v.sequence)
    header.addUint32(toBigEndian uint32 v.time)
    header.addUint32(toBigEndian uint32(v.ssrc))
    let
        nonce = v.makeNonce(header)
        encrypted = crypto_secretbox_easy(v.secret_key, data, nonce)

    var packet = newStringOfCap(header.len + encrypted.len)
    packet &= header
    packet &= encrypted

    if v.encryptMode != Normal:
        packet &= nonce
    await v.sendUDPPacket(packet)

proc incrementPacketHeaders(v: VoiceClient) =
    # Increment headers, make sure to loop back around
    if v.sequence + 10 < uint16.high:
        v.sequence += 1
    else:
        v.sequence = 0
    if v.time + 9600 < uint32.high or v.time + 9600 < v.time: # Check for wraparound
        v.time += 960
    else:
        v.time = 0

proc pause*(v: VoiceClient) {.async.} =
    ## Pause the current audio
    v.paused = true
    for i in 1..5:
        await v.sendAudioPacket silencePacket
        incrementPacketHeaders v
        await sleepAsync idealLength
    await v.updateSpeaking(false)

proc unpause*(v: VoiceClient) {.async.} =
    ## (Alias) same as resume
    await v.resume()

proc play*(v: VoiceClient, input: Stream | Process) {.async.} =
    ## Plays audio data that comes from a stream or process.
    ## Audio **must** be 2 channel, 48k sample rate, PCM encoded byte stream.
    ## Make sure to use sendSpeaking before sending any audio
    ## Note: if you are playing voice on windows there **might** be some interuptions.
    if v.paused: v.paused = false
    v.stopped = false

    while v.start != 0.0:
        await sleepAsync 20

    await v.updateSpeaking(true)

    when input is Stream:
        let stream = input
    else:
        let stream = input.outputStream

    while stream.atEnd:
        await sleepAsync 1000

    doAssert stream != nil, "Stream is not open"
    let encoder = createEncoder(48000, 2, 960, Voip)

    var
        start:   float64
        counts:  float64
        elapsed: float64
    while (not stream.atEnd() or input.running) and not v.stopped:
        if v.loops == 0:
            if v.start == 0.0:
                v.start = float64(getMonoTime().ticks.int / 1_000_000_000)
                start = v.start
            start = v.start

        v.data = newStringOfCap(dataSize)

        # Try and read needed data
        var attempts = 3
        while attempts > 0:
            v.data &= stream.readStr(dataSize - v.data.len)
            dec attempts
            if v.data.len != dataSize:
                await sleepAsync 1000
            else:
                break

        if attempts == 0:
            logVoice("Couldn't read needed amount of data in time\n  Data size: " & $v.data.len)
            continue

        v.sent += 1
        v.loops += 1
        counts += 1

        let encoded = encoder.encode(v.data.toPCMData(encoder))

        # Build the packet
        var buf = newString(encoded.len)
        for i in 0 ..< encoded.len:
            buf[i] = cast[char](encoded[i])

        await sendAudioPacket(v, buf)
        incrementPacketHeaders v
        elapsed = (counts*20)/1000

        # Sleep so each packet will be sent 20 ms apart
        # funfact: this took me over a week to almost fix this
        let
            now = float64(getMonoTime().ticks.int/1_000_000_000)

            delay = max(0.0, 0.02'f64 + float64(
                    (v.start + (0.02'f64 * v.loops.float64)) - now
                )
            )

        var offset = rand(0.5..1.0) + v.sleep_offset
        if v.offset_override:
            if v.adjust_range != 0.0..0.0: v.adjust_range = 10.0..20.0
            if elapsed in v.adjust_range: # at this part is where the interruptions may occur
                if elapsed >= v.adjust_range.b-1: # reset the time, so that diff would start from 0
                    counts = 0
                    start = float64(getMonoTime().ticks.int / 1_000_000_000)
                    if v.adjust_offset==0:
                        offset = rand(7.2..8.0)
                    else:
                        offset = v.adjust_offset
        else:
            if v.sleep_offset == 0.0:
                if v.adjust_offset==0:
                    offset = rand(7.2..8.0)
                else:
                    offset = v.adjust_offset

        await sleepAsync float(delay * 1000) + offset

        while v.paused:
            await sleepAsync 1

    v.start = 0.0
    v.loops = 0
    v.stopped = false
    v.data = ""
    v.paused = false
    v.sent = 0
    v.time = 0
    v.sequence = 0
    # Send 5 silent frames to clear buffer
    for i in 1..5:
        await v.sendAudioPacket silencePacket
        incrementPacketHeaders v
        await sleepAsync idealLength

    await v.updateSpeaking(false)

proc exeExists(exe: string): bool =
    ## Returns true if `exe` can be found
    result = findExe(exe) != ""

proc playFFMPEG*(v: VoiceClient, path: string) {.async.} =
    ## Gets audio data by passing input to ffmpeg (so input can be anything that ffmpeg supports).
    ## Requires `ffmpeg` be installed.
    var args = @[
        "-i",
        path,
        "-loglevel",
        "0",
        "-f",
        "s16le",
        "-ar",
        "48000",
        "-ac",
        "2",
        "pipe:1"
    ]
    if path.startsWith("http"):
        args = concat(@["-reconnect", "1"], args)
    elif not path.fileExists:
        raise (ref IOError)(msg: fmt"File {path} does not exist")

    doAssert exeExists("ffmpeg"), "Cannot find ffmpeg, make sure it is installed"
    let pid = startProcess("ffmpeg", args = args, options = {
        poUsePath, poEchoCmd, poStdErrToStdOut, poDaemon})
    defer: pid.close()
    await v.play(pid)

proc playYTDL*(v: VoiceClient, url: string; command = "yt-dlp") {.async.} =
    ## Plays a youtube link using yt-dlp by default
    ## Requires `yt-dlp` to be installed, if you want to use youtube-dl, then you can specify it.
    doAssert exeExists(command), "You need to install " & command

    let output = execProcess(
        command, args = ["--get-url", url, "--no-warnings"],
        options = {poUsePath, poStdErrToStdOut}
    )
    # doAssert exitCode == 0, "An error occurred:\n" & output
    let first = output.split("\n")[0]
    let sec = output.split("\n")[1]

    if not first.startsWith("http") and not sec.startsWith("http"):
        raise newException(Exception, "error occurred:\n\n" & output)

    if not sec.startsWith("http"):
        await v.playFFMPEG(first)
    else:
        await v.playFFmpeg(sec)

