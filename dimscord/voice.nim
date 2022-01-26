## Currently handling the discord voice gateway (WIP)
## Playing audio will be added later.
import asyncdispatch, ws, asyncnet
import objects, json, constants
import strutils, nativesockets, streams, sequtils
import libsodium/sodium, libsodium/sodium_sizes
import osproc, asyncnet
import flatty/binny, random
import std/strformat
import opussum
import std/[monotimes, times]
import std/streams

randomize()

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

when defined(windows):
    const libsodium_fn* = "libsodium.dll"
elif defined(macosx):
    const libsodium_fn* = "libsodium.dylib"
else:
    const libsodium_fn* = "libsodium.so(.18|.23)"

{.pragma: sodium_import, importc, dynlib: libsodium_fn.}

proc crypto_secretbox_easy(
    c: ptr cuchar,
    m: cstring,
    mlen: culonglong,
    n: cstring,
    k: cstring,
):cint {.sodium_import.}

const
    nonceLen = 24
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
        echo fmt"[Voice]: {msg}"

proc logVoice(msg: string, extra: any) =
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
    var cipherText = cast[ptr UncheckedArray[cuchar]](createShared(cuchar, length))
    defer: freeShared cipherText

    let rc = crypto_secretbox_easy(
        cast[ptr cuchar](cipherText),
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

    echo closeData.code
    if closeData.code in [4004, 4006, 4012, 4014]:
        result = false
        logVoice("Fatal error: " & closeData.reason)

proc sendSock(v: VoiceClient, opcode: VoiceOp, data: JsonNode) {.async.} =
    logVoice "Sending OP: " & $opcode
    assert v.connection != nil, "Connection needs to be open first"
    await v.connection.send($(%*{
        "op": opcode.ord,
        "d": data
    }))

proc sockClosed(v: VoiceClient): bool {.used.} =
    return v.connection == nil or v.connection.tcpSocket.isClosed or v.stop

proc resume*(v: VoiceClient) {.async.} =
    if v.resuming or v.sockClosed: return

    # v.resuming = true

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

        if (await withTimeout(future, 25000)) == false:
            logVoice "Websocket timed out.\n\n  Retrying connection..."

            await v.reconnect()
            return

        v.connection = await future
        v.hbAck = true

        v.retry_info.attempts = 0
        v.retry_info.ms = max(v.retry_info.ms - 5000, 1000)

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


proc disconnect*(v: VoiceClient) {.async.} =
    ## Disconnects a voice client.
    if v.sockClosed: return

    logVoice "Voice Client disconnecting..."

    v.stop = true

    if v.connection != nil:
        v.connection.close()


    logVoice "Shard reconnecting after disconnect..."
    # TODO: Don't reconnect if not meant too e.g. if was kicked from a call
    # TODO: Don't reconnect if explicitly disconnecting
    #await v.reconnect()

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

        if hbTime < v.interval - 8000 and v.lastHBTransmit != 0.0:
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
        logVoice $VoiceOp(data["op"].num)

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
            logVoice "Heartbeat Acknowledged by Discord."

            v.hbAck = true
        of Ready:
            v.dstIP = data["d"]["ip"].str
            v.dstPort = data["d"]["port"].getInt
            v.ssrc = uint32 data["d"]["ssrc"].getInt
            v.udp = newAsyncSocket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
            logVoice fmt"Connecting to {v.dstIP} and {v.dstPort}"
            # We need to get our IP
            await v.sendDiscovery()
            await v.recvDiscovery()
            v.ready = true
            await v.selectProtocol()

        of Resumed:
            v.resuming = false
        of SessionDescription:
            logVoice "Got session description"
            v.encryptMode = parseEnum[VoiceEncryptionMode](data["d"]["mode"].getStr())
            v.secret_key = data["d"]["secret_key"].elems.mapIt(chr(it.getInt)).join("")
            await v.voice_events.on_ready(v)
        else: discard
    if not v.reconnectable: return

    if packet[0] == Close:
        v.shouldReconnect = v.handleDisconnect(packet[1])
    v.stop = true

    if shouldReconnect:
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

        if (await withTimeout(future, 25000)) == false:
            logVoice "Websocket timed out.\n\n  Retrying connection..."
            await v.startSession()
            return
        v.connection = await future
        v.hbAck = true

        logVoice "Socket opened."
    except:
        v.stopped = true
        raise newException(Exception, getCurrentExceptionMsg())
    try:
        logVoice "handlong socket"
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

proc sendAudioPacket*(v: VoiceClient, data: string) {.async.} =
    ## Sends opus encoded packet
    var header = ""
    header.addUint8(0x80)
    header.addUint8(0x78)
    header.addUint16(toBigEndian uint16 v.sequence)
    header.addUint32(toBigEndian uint32 v.time)
    header.addUint32(toBigEndian uint32(v.ssrc))
    let nonce = v.makeNonce(header)
    # echo "Sending ", data.len, " bytes of data"

    var packet = header & crypto_secretbox_easy(v.secret_key, data, nonce)
    if v.encryptMode != Normal:
        packet &= nonce
    await v.sendUDPPacket(packet)

proc incrementPacketHeaders(v: VoiceClient) =
    # Increment headers, make sure to loop back around
    if v.sequence + 10 < uint16.high:
        v.sequence += 1
    else:
        v.sequence = 0
    if v.time + 9600 < uint32.high:
        v.time += 960
    else:
        v.time = 0

proc play*(v: VoiceClient, input: Stream | Process, waitForData: int = 100000) {.async.} =
  ## Plays audio data that comes from a stream or process.
  ## Audio **must** be 2 channel, 48k sample rate, PCM encoded byte stream.
  ## Make sure to use sendSpeaking_ before sending any audio
  ##
  ## * **waitForData**: How many milliseconds to allow for data to start coming through
  await v.sendSpeaking(true)

  when input is Stream:
    let stream = input
    let atEnd = proc (): bool = stream.atEnd
  else:
    let stream = input.outputStream
    let atEnd = proc (): bool = not input.running

  var slept = 0
  while stream.atEnd and slept < waitForData:
    await sleepAsync 1000
    slept += 1000
    echo "Sleeping"

  doAssert stream != nil, "Stream is not open"
  let encoder = createEncoder(48000, 2, 960, Voip)
  while not atEnd() and not v.stopped:
    var sleepTime = idealLength
    var data = newStringOfCap(dataSize)
    let startTime = getMonoTime()

    while v.paused:
      await sleepAsync 1000

    # Try and read needed data
    var attempts = 3
    while data.len != dataSize and attempts > 0:
      data &= stream.readStr(dataSize - data.len)
      dec attempts
      await sleepAsync 5

    if attempts == 0:
      logVoice "Couldn't read needed amount of data in time"
      return

    let
      encoded = encoder.encode(data.toPCMData(encoder))

    let encodingTime = getMonoTime() # Allow us to track time to encode
    await sendAudioPacket(v, $encoded)
    incrementPacketHeaders v

    # Sleep so each packet will be sent 20 ms apart
    let
      now = getMonoTime()
      diff = (now - startTime).inMilliseconds
    sleepTime = int(idealLength - diff)
    await sleepAsync sleepTime

  v.stopped = false
  # Send 5 silent frames to clear buffer
  for i in 1..5:
    await v.sendAudioPacket(silencePacket)
    incrementPacketHeaders v
    await sleepAsync idealLength
  await v.sendSpeaking(false)

proc playFFMPEG*(v: VoiceClient, path: string) {.async.} =
    ## Gets audio data by passing input to ffmpeg (so input can be anything that ffmpeg supports).
    ## Requires `ffmpeg` be installed.
    let
        args = @[
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
    let pid = startProcess("ffmpeg", args = args, options = {poUsePath, poEchoCmd})
    defer: pid.close()
    await v.play(pid)

proc playYTDL*(v: VoiceClient, url: string) {.async.} =
  ## Plays a youtube link using yt-dlp.
  ## Requires `yt-dlp` to be installed
  let args = @[
    "-f",
    "bestaudio", # We want best audio, maybe make this configurable?
    "--get-url", # We only the url which will be passed to ffmpeg
    url
  ]
  let url = execProcess("yt-dlp", args = args, options = {poStdErrToStdOut, poUsePath})
  await v.playFFMPEG(url)
