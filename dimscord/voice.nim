# Play audio in voice channel via ytdl/ffmpeg.
## Please note that playing audio is either buggy on windows, but we aren't currently sure exactly why though.
import asyncdispatch, ws, asyncnet
import objects, json, constants
import strutils, nativesockets, streams, sequtils
import libsodium/sodium, libsodium/sodium_sizes
import osproc
import flatty/binny, random
import std/strformat
import opussum
import std/[monotimes, times]
import std/os

randomize()

when (NimMajor, NimMinor, NimPatch) >= (1, 6, 0):
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
    c: ptr uint8,
    m: cstring,
    mlen: culonglong,
    n: cstring,
    k: cstring,
):cint {.sodium_import.}

const
    # nonceLen = 24 apparently this hasn't been used
    dataSize = 960 * 2 * 2 # Frame size is 960 16 bit integers and we need 2 channels worth
    idealLength = 19 # How long one voice packet should ideally be in milliseconds

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
    logVoice(msg & "\n" & $extra)

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

proc resume*(v: VoiceClient) {.async.} =
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
    if v.sockClosed: return
    await v.sendSock(SelectProtocol, %*{
        "protocol": "udp",
        "data": {
            "address": v.srcIP,
            "port": v.srcPort,
            "mode": $v.encryptMode
        }
    })

proc sendSpeaking*(v: VoiceClient, speaking: bool | set[VoiceSpeakingFlags]) {.async.} =
    if v.sockClosed: return

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
        v.migrate = false

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

    logVoice "Voice Client disconnecting..."

    v.stop = true

    if v.connection != nil:
        v.connection.close()
    if migrate: v.migrate = true

proc heartbeat(v: VoiceClient) {.async.} =
    if v.sockClosed: return

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
    await v.udp.sendTo(v.dstIP, Port(v.dstPort), packet)

proc recvUDPPacket(v: VoiceClient, size: int): Future[string] {.async.} =
    ## Recvs a UDP packet from anyone (Could be security issue? couldn't get other proc to work though)
    result = v.udp.recvFrom(size).await().data

proc sendDiscovery(v: VoiceClient) {.async.} =
    ## Sends ip/port discovery packet to discord.
    ## After calling this, call recvDiscovery to make `v` set its external IP
    var packet: string
    packet.addUint32(toBigEndian uint32(v.ssrc))
    packet.add chr(0).repeat(66)
    await v.sendUDPPacket(packet)

proc recvDiscovery(v: VoiceClient) {.async.} =
    ## Recvs external ip/port from discord
    let packet = await v.recvUDPPacket(70)
    v.srcIP = packet[4..^3].replace($chr(0), "")
    v.srcPort = (packet[^2].ord) or (packet[^1].ord shl 8)

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

            if exceptn.startsWith("The semaphore timeout period has expired."):
                logVoice "A network error has been detected."

                v.networkError = true
                break
            else:
                break

        var data: JsonNode

        try:
            data = parseJson(packet[1])
        except:
            logVoice "An error occurred while parsing data: " & packet[1]
            await v.disconnect()
            await v.voice_events.on_disconnect(v)
            break

        case VoiceOp(data["op"].num)
        of Hello:
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
            v.ready = true
            await v.selectProtocol()
        of Resumed:
            v.resuming = false
            logVoice "Successfully resumed."
        of SessionDescription:
            logVoice "Received session description."
            v.encryptMode = parseEnum[VoiceEncryptionMode](data["d"]["mode"].getStr())
            v.secret_key = data["d"]["secret_key"].elems.mapIt(
                chr(it.getInt)).join("")
            asyncCheck v.voice_events.on_ready(v)
        else: discard
    # if not v.reconnectable: return
    # v.
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
        raise getCurrentException()
    try:
        # logVoice "handlong socket" ???
        await v.handleSocketMessage()
    except:
        if not getCurrentExceptionMsg()[0].isAlphaNumeric: return
        raise newException(Exception, getCurrentExceptionMsg())

proc pause*(v: VoiceClient) {.async.} =
    ## Pause the current audio
    v.paused = true

proc unpause*(v: VoiceClient) =
    ## Continue playing audio
    v.paused = false

proc stop*(v: VoiceClient) =
    ## Stop the current audio
    v.stopped = true
    v.data = ""

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

proc play*(v: VoiceClient, input: Stream | Process, waitForData: int = 100000) {.async.} =
    ## Plays audio data that comes from a stream or process.
    ## Audio **must** be 2 channel, 48k sample rate, PCM encoded byte stream.
    ## Make sure to use sendSpeaking_ before sending any audio
    ##
    ## * **waitForData**: How many milliseconds to allow for data to start coming through
    if v.paused: v.paused = false

    await v.sendSpeaking(true)
    v.speaking = true
    asyncCheck v.voice_events.on_speaking(v, true)

    when input is Stream:
        let stream = input
        let atEnd = proc (): bool = stream.atEnd
    else:
        let stream = input.outputStream
        let atEnd = proc (): bool = not input.running

    while stream.atEnd:
        await sleepAsync 1000

    doAssert stream != nil, "Stream is not open"
    let encoder = createEncoder(48000, 2, 960, Voip)

    var count: uint = 0 # Keep track of packets sent 
    while not atEnd() and not v.stopped:
        var sleepTime = idealLength
        v.data = newStringOfCap(dataSize)
        let 
            startTime = getMonoTime()
            shouldAdjust = (count mod 100) == 0
            
        while v.paused:
            await sleepAsync 1000

        # Try and read needed data
        var attempts = 3
        while attempts > 0:
            v.data &= stream.readStr(dataSize - v.data.len)
            dec attempts
            if v.data.len != dataSize:
                await sleepAsync 500
            else:
                break

        if attempts == 0:
            logVoice "Couldn't read needed amount of data in time"
            # echo input.waitForExit()
            return

        let encoded = encoder.encode(v.data.toPCMData(encoder))

        # Build the packet
        var buf = newString(encoded.len)
        for i in 0 ..< encoded.len:
            buf[i] = cast[char](encoded[i])

        await sendAudioPacket(v, buf)
        incrementPacketHeaders v

        # Sleep so each packet will be sent 20 ms apart
        if shouldAdjust:
            let
                now = getMonoTime()
                diff = (now - startTime).inMilliseconds
            sleepTime = int(idealLength - diff)
            if sleepTime > 0:
                await sleepAsync sleepTime
        else:
            logVoice "Audio encoding/sending took long >20ms. Check for network/hardware issues"

    v.stopped = false
    if not v.paused: v.data = ""
    # Send 5 silent frames to clear buffer
    for i in 1..5:
        await v.sendAudioPacket silencePacket
        incrementPacketHeaders v
        await sleepAsync idealLength

    await v.sendSpeaking(false)
    v.speaking = false
    asyncCheck v.voice_events.on_speaking(v, false)

proc exeExists(exe: string): bool =
    ## Returns true if `exe` can be found
    result = findExe(exe) != ""

proc playFFMPEG*(v: VoiceClient, path: string) {.async.} =
    ## Gets audio data by passing input to ffmpeg (so input can be anything that ffmpeg supports).
    ## Requires `ffmpeg` be installed.
    let args = @[
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

    if not path.fileExists and not path.startsWith("http"):
      raise (ref IOError)(msg: fmt"File {path} does not exist")

    doAssert exeExists("ffmpeg"), "Cannot find ffmpeg, make sure it is installed"
    let pid = startProcess("ffmpeg", args = args, options = {
        poUsePath, poEchoCmd, poStdErrToStdOut})
    defer: pid.close()
    await v.play(pid)

proc playYTDL*(v: VoiceClient, url: string) {.async.} =
    ## Plays a youtube link using yt-dlp.
    ## Requires `yt-dlp` to be installed
    let (output, exitCode) = execCmdEx("yt-dlp -f bestaudio --get-url " & url)
    doAssert exitCode == 0, "yt-dlp failed:\n" & output
    await v.playFFMPEG(output)
