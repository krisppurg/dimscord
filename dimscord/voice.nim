## Currently handling the discord voice gateway (WIP)
## Playing audio will be added later.
import asyncdispatch, ws, asyncnet
import objects, json, times, constants
import strutils, nativesockets, streams, sequtils
import libsodium/sodium, libsodium/sodium_sizes
import osproc, asyncnet
import flatty/binny, random
import std/strformat
import opussum
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

template cpt(target: string): untyped =
    cast[ptr cuchar](cstring(target))

template culen(target: string): untyped =
    culonglong(target.len)

proc crypto_secretbox_easy(
    c: ptr cuchar,
    m: ptr cuchar,
    mlen: culonglong,
    n: ptr cuchar,
    k: ptr cuchar,
):cint {.sodium_import.}

const
    nonceLen = 24
    dataSize = 1920 * 2

const silencePacket = block:
    var packet: string
    packet.addInt(0xF8)
    packet.addInt(0xFF)
    packet.addInt(0xFE)
    packet


proc makeNonce(v: VoiceClient, header: string): string =
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
    # result = newString msg.len + nonceLen
    let cipherText = newString msg.len + nonceLen
    let
        c_ciphertext = cpt cipherText
        cmsg = cpt msg
        mlen = culen msg
        ckey = cpt key
        cnonce = cpt nonce
    let rc = crypto_secretbox_easy(c_ciphertext, cmsg, mlen, cnonce, ckey)
    if rc != 0:
        raise newException(SodiumError, "return code: $#" % $rc)
    result = cipherText
    # doAssert crypto_secretbox_open_easy(key, nonce & cipherText) == msg


proc reset(v: VoiceClient) {.used.} =
    v.resuming = false

    v.hbAck = false
    v.hbSent = false
    v.ready = false

    v.ip = ""
    v.secretKey = ""
    if v.encryptMode == Lite:
        v.nonce = 0
    v.sequence = 0
    v.time = 0
    v.port = -1

    v.heartbeating = false
    v.retry_info = (ms: 1000, attempts: 0)
    v.lastHBTransmit = 0
    v.lastHBReceived = 0

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

    log("Socket suspended", (
        code: closeData.code,
        reason: closeData.reason
    ))
    v.stop = true
    v.reset()

    result = true

    echo closeData.code
    if closeData.code in [4004, 4006, 4012, 4014]:
        result = false
        log("Fatal error: " & closeData.reason)

proc sendSock(v: VoiceClient, opcode: VoiceOp, data: JsonNode) {.async.} =
    log "Sending OP: " & $opcode
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

    log "Attempting to resume\n" &
        "  server_id: " & v.guild_id & "\n" &
        "  session_id: " & v.session_id

    await v.sendSock(Resume, %*{
        "server_id": v.guild_id,
        "session_id": v.session_id,
        "token": v.token
    })

proc identify(v: VoiceClient) {.async.} =
    if v.sockClosed and not v.resuming: return

    log "Sending identify."

    await v.sendSock(Identify, %*{
        "server_id": v.guild_id,
        "user_id": v.shard.user.id,
        "session_id": v.session_id,
        "token": v.token
    })

proc selectProtocol*(v: VoiceClient) {.async.} =
    if v.sockClosed: return

    await v.sendSock(SelectProtocol, %*{
        "protocol": "udp",
        "data": {
            "address": v.ip,
            "port": v.port,
            "mode": $v.encryptMode
        }
    })

proc sendSpeaking*(v: VoiceClient, speaking: bool) {.async.} =
    if v.sockClosed: return
    await v.sendSock(Speaking, %* {
        "speaking": 5,
        "delay": 0
    })

proc reconnect*(v: VoiceClient) {.async.} =
    if (v.reconnecting or not v.stop) and not v.reconnectable: return
    v.reconnecting = true
    v.retry_info.attempts += 1

    var url = v.endpoint

    if v.retry_info.attempts > 3:
        if not v.networkError:
            v.networkError = true
            log "A network error has been detected."

    let prefix = if url.startsWith("gateway"): "ws://" & url else: url

    log "Connecting to " & $prefix

    try:
        let future = newWebSocket(prefix)

        v.reconnecting = false
        v.stop = false

        if (await withTimeout(future, 25000)) == false:
            log "Websocket timed out.\n\n  Retrying connection..."

            await v.reconnect()
            return

        v.connection = await future
        v.hbAck = true

        v.retry_info.attempts = 0
        v.retry_info.ms = max(v.retry_info.ms - 5000, 1000)

        if v.networkError:
            log "Connection established after network error."
            v.retry_info = (ms: 1000, attempts: 0)
            v.networkError = false
    except:
        log "Error occurred: \n" & getCurrentExceptionMsg()

        log("Failed to connect, reconnecting in " & $v.retry_info.ms & "ms", (
            attempt: v.retry_info.attempts
        ))
        v.reconnecting = false
        await sleepAsync v.retry_info.ms
        await v.reconnect()
        return


proc disconnect*(v: VoiceClient) {.async.} =
    ## Disconnects a voice client.
    if v.sockClosed: return

    log "Voice Client disconnecting..."

    v.stop = true
    v.reset()

    if v.connection != nil:
        v.connection.close()


    log "Shard reconnecting after disconnect..."
    await v.reconnect()

proc heartbeat(v: VoiceClient) {.async.} =
    if v.sockClosed: return

    # if not v.hbAck and v.session_id != "":
    #     log "A zombied connection has been detected"
    #     await v.disconnect()
    #     return

    log "Sending heartbeat."
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

proc handleSocketMessage(v: VoiceClient) {.async.} =
    var packet: (Opcode, string)

    var shouldReconnect = true
    while not v.sockClosed:
        try:
            packet = await v.connection.receivePacket()
        except:
            let exceptn = getCurrentExceptionMsg()
            log "Error occurred in websocket ::\n" & getCurrentExceptionMsg()

            v.stop = true
            v.heartbeating = false

            if exceptn.startsWith("The semaphore timeout period has expired."):
                log "A network error has been detected."

                v.networkError = true
                break
            else:
                break

        var data: JsonNode

        try:
            data = parseJson(packet[1])
        except:
            log "An error occurred while parsing data: " & packet[1]
            await v.disconnect()
            await v.voice_events.on_disconnect(v)
            break
        log $VoiceOp(data["op"].num)
        case VoiceOp(data["op"].num)
        of Hello:
            log "Received 'HELLO' from the voice gateway."
            v.interval = int data["d"]["heartbeat_interval"].getFloat

            await v.identify()

            if not v.heartbeating:
                v.heartbeating = true
                asyncCheck v.setupHeartbeatInterval()
        of HeartbeatAck:
            v.lastHBReceived = getTime().toUnixFloat()
            v.hbSent = false
            log "Heartbeat Acknowledged by Discord."

            v.hbAck = true
        of Ready:
            v.ip = data["d"]["ip"].str
            v.port = data["d"]["port"].getInt
            v.ssrc = uint32 data["d"]["ssrc"].getInt
            v.udp = newAsyncSocket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
            log fmt"Connecting from {v.ip} and {v.port}"
            v.ready = true
            await v.selectProtocol()
        of Resumed:
            v.resuming = false
        of SessionDescription:
            log "Got session description"
            v.secret_key = data["d"]["secret_key"].elems.mapIt(chr(it.getInt)).join("")
            await v.voice_events.on_ready(v)
        else: discard
    if not v.reconnectable: return

    if packet[0] == Close:
        v.shouldReconnect = v.handleDisconnect(packet[1])
    v.stop = true
    v.reset()

    if shouldReconnect:
        await v.reconnect()
        await sleepAsync 2000

        if not v.networkError: await v.handleSocketMessage()
    else:
        return

proc startSession*(v: VoiceClient) {.async.} =
    ## Start a discord voice session.
    log "Connecting to voice gateway"

    try:
        v.endpoint = v.endpoint.replace(":443", "")
        let future = newWebSocket(v.endpoint)

        if (await withTimeout(future, 25000)) == false:
            log "Websocket timed out.\n\n  Retrying connection..."
            await v.startSession()
            return
        v.connection = await future
        v.hbAck = true

        log "Socket opened."
    except:
        v.stop = true
        raise newException(Exception, getCurrentExceptionMsg())
    try:
        await v.handleSocketMessage()
    except:
        if not getCurrentExceptionMsg()[0].isAlphaNumeric: return
        raise newException(Exception, getCurrentExceptionMsg())

# proc playFile*(v: VoiceClient) {.async.} =
#     ## Play an audio file.
#     discard

# proc openYTDLStream*(v: VoiceClient)

iterator chunkedStdout(cmd: string,
        args: openArray[string], size: int): string = # credit to haxscramper
    var buf: string = " ".repeat(size + 20)
    echo cmd & " " & args.join(" ")
    let pid = startProcess(cmd, args = args, options = {poUsePath})
    let outStream = pid.outputStream
    let errStream = pid.errorStream
    while pid.running:
        # if not errStream.atEnd:
        #     echo "got error"
        #     echo errStream.readALl()
        let d = readDataStr(outStream, buf, 0 ..< size)
        yield buf[0 .. d - 1]


proc pause*(v: VoiceClient) {.async.} =
    if v.playing:
        v.playing = false

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

proc sendAudioPacket*(v: VoiceClient, data: string) {.async.} =
    ## Sends opus encoded packet
    var header = ""
    header.addUint8(0x80)
    header.addUint8(0x78)
    header.addUint16(toBigEndian uint16 v.sequence)
    header.addUint32(toBigEndian uint32 v.time)
    header.addUint32(toBigEndian uint32 v.ssrc)
    let nonce = v.makeNonce(header)
    echo "Sending ", data.len, " bytes of data"

    var packet = header & crypto_secretbox_easy(v.secret_key, data, nonce)
    if v.encryptMode != Normal:
        packet &= nonce
    await v.udp.sendTo(v.ip, Port(v.port), packet)

proc incrementPacketHeaders(v: VoiceClient) =
    # Don't know if this is needed or other libraries just implemented it
    # because there language cant handle overflows, guess I'll never know
    if v.sequence + 10 < uint16.high:
        v.sequence += 1
    else:
        v.sequence = 0
    if v.time + 9600 < uint32.high:
        v.time += 960
    else:
        v.time = 0

proc sendAudio(v: VoiceClient, input: string) {.async.} = # uncomplete/unfinished code
    let
        args = @[
            "-i",
            $input,
            "-ac",
            "2",
            "-ar",
            "48k",
            "-f",
            "s16le",
            "-acodec",
            "pcm_s16le",
            "-loglevel",
            "quiet",
            "-nostdin",
            "pipe:1"
        ]
    var
        chunked = ""
    let encoder = createEncoder(48000, 2, 960, Voip)
    for data in chunkedStdout("ffmpeg", args, 1920 * 2):
        # chunked.add chunk
        # if chunked.len >= 1500:
        #     for c in chunked:
        #         data.add c
        #     data = data[0..(if data.high >= 1500: 1500 else: data.high)]

        incrementPacketHeaders v
        if data == "": continue

        await sendAudioPacket(v, $encoder.encode(data.toPCMBytes(encoder)).cstring)
        await sleepAsync 100
    # Send 5 silent frames to clear buffer
    for i in 1..5:
        incrementPacketHeaders v
        echo "Sound of silence"
        await v.sendAudioPacket(silencePacket)

    await v.sendSock(Speaking, %*{"speaking": false})

proc playFFmpeg*(v: VoiceClient, input: string) {.async.} =
    ## Play audio through ffmpeg, input can be a url or a path.
    await v.sendSpeaking(true)
    log "Sending audio"
    await v.sendAudio(input)
    await v.sendSpeaking(true)

# proc latency*(v: VoiceClient) {.async.} =
#     ## Get latency of the voice client.
#     discard
