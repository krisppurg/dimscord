## Currently handling the discord voice gateway (WIP)
## Playing audio will be added later.
import asyncdispatch, ws, asyncnet
import objects, json, times, constants
import strutils, nativesockets, streams, sequtils
import libsodium/sodium, libsodium/sodium_sizes
import osproc, endians, net
import flatty/binny, random
randomize()

const
    opIdentify = 0
    opSelectProtocol = 1
    opReady = 2
    opHeartbeat = 3
    opSessionDescription = 4
    opSpeaking = 5
    opHeartbeatAck = 6
    opResume = 7
    opHello = 8
    opResumed = 9
    opClientDisconnect = 13

when defined(windows):
    const libsodium_fn* = "libsodium.dll"
elif defined(macosx):
    const libsodium_fn* = "libsodium.dylib"
else:
    const libsodium_fn* = "libsodium.so(.18|.23)"

{.pragma: sodium_import, importc, dynlib: libsodium_fn.}

template cpt(target: string): untyped =
    cast[ptr cuchar](cstring(target))

template cpsize(target: string): untyped =
    csize(target.len)

template culen(target: string): untyped =
    culonglong(target.len)

proc crypto_secretbox_easy(
    c: ptr cuchar,
    m: ptr cuchar,
    mlen: culonglong,
    n: ptr cuchar,
    k: ptr cuchar,
):cint {.sodium_import.}

# var OPUS_APPLICATION_AUDIO {.importc, header: "<opus/opus.h>".}: cint

# type OpusEncoderVal = object
# type OpusDecoderVal = object

# type OpusEncoder* = ptr OpusEncoderVal
# type OpusDecoder* = ptr OpusDecoderVal

# {.passl: "-lopus".}

# proc opus_encode (st: ptr OpusEncoderVal, pcm: ptr uint16, frame_size: cint, data: pointer, max_data_bytes: int32): int32 {.importc, header: "<opus/opus.h>".}
# proc opus_encoder_create (fs: int32, channels: cint, application: cint, error: ptr cint): ptr OpusEncoderVal {.importc, header: "<opus/opus.h>".}
# proc opus_encoder_ctl (st: ptr OpusEncoderVal, request: int): cint {.importc, varargs, header: "<opus/opus.h>".}

# proc opus_decoder_create (fs: int32, channels: cint, error: ptr cint): ptr OpusDecoderVal {.importc, header: "<opus/opus.h>".}
# proc opus_decode (st: ptr OpusDecoderVal, data: pointer, len: int32, pcm: ptr int16, frame_size: cint, decode_fec: cint): cint {.importc, header: "<opus/opus.h>".}

# # FIXME: destroy the decoder/encoder object with destructor!

# const channels = 2

# proc newOpusDecoder*(): OpusDecoder =
#     var err: cint
#     result = opus_decoder_create(48000, channels, addr err)
#     if err != 0: raise newException(Exception, "cannot create opus decoder")

# proc decode*(self: OpusDecoder, encoded: Buffer): Buffer =
#     const maxSamples = 24000
#     let buf = newBuffer(maxSamples * 2 * channels)
#     let samples = opus_decode(self, addr encoded[0], encoded.len.int32,
#                                 cast[ptr int16](addr buf[0]), maxSamples, 0)
#     if samples < 0:
#         raise newException(Exception, "opus_decode failed")

#     return buf.slice(0, samples * 2 * channels)

# proc newOpusEncoder*(): OpusEncoder =
#     var err: cint
#     result = opus_encoder_create(48000, channels, OPUS_APPLICATION_AUDIO, addr err)
#     if err != 0: raise newException(Exception, "cannot create opus decoder")

# proc encode*(self: OpusEncoder, samples: Buffer): Buffer =
#     doAssert samples.len mod (2 * channels) == 0
#     var outBuffer = newBuffer(samples.len + 100)

#     var encodedSize: int32 = opus_encode(
#         self,
#         cast[ptr uint16](addr samples[0]), cint(samples.len div (2 * channels)),
#         addr outBuffer[0], outBuffer.len.int32)

#     if encodedSize < 0:
#         raise newException(Exception, "opus_encode failed")

#     return outBuffer.slice(0, encodedSize)

proc crypto_secretbox_easy_nonce(key: string, msg: string): string =
    assert key.len == crypto_secretbox_KEYBYTES()
    let nonce = randombytes(crypto_secretbox_NONCEBYTES().int)
    var
        cnonce = cpt nonce

    let
        ciphertext = newString msg.len + crypto_secretbox_MACBYTES()
        c_ciphertext = cpt ciphertext
        cmsg = cpt msg
        mlen = culen msg
        ckey = cpt key
    discard crypto_secretbox_easy(c_ciphertext, cmsg, mlen, cnonce, ckey)
    return ciphertext & nonce

var
    ip: string
    port: int
    ssrc: int
    secret_key: seq[int]
    playing = false
    stopped = false
    reconnectable = true
    discovering = false
proc writeBigUint16(strm: StringStream, num: uint16) = 
    var
        tmp: uint16
        num = num
    bigEndian16(addr tmp, addr num)
    strm.write(tmp)

proc writeBigUint32(strm: StringStream, num: uint32) = 
    var
        tmp: uint32
        num = num
    bigEndian32(addr tmp, addr num)
    strm.write(tmp)

proc writeString(strm: StringStream, num: string) =
    var
        tmp: string
        num = num
    strm.write(num)

proc reset(v: VoiceClient) {.used.} =
    v.resuming = false

    v.hbAck = false
    v.hbSent = false
    v.ready = false

    ip = ""
    port = -1

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

    if closeData.code in [4004, 4006, 4012, 4014]:
        result = false
        log("Fatal error: " & closeData.reason)

proc sendSock(v: VoiceClient, opcode: int, data: JsonNode) {.async.} =
    log "Sending OP: " & $opcode

    await v.connection.send($(%*{
        "op": opcode,
        "d": data
    }))

proc sockClosed(v: VoiceClient): bool {.used.} =
    return v.connection == nil or v.connection.tcpSocket.isClosed or v.stop

proc resume(v: VoiceClient) {.async.} =
    if v.resuming or v.sockClosed: return

    # v.resuming = true

    log "Attempting to resume\n" &
        "  server_id: " & v.guild_id & "\n" &
        "  session_id: " & v.session_id

    await v.sendSock(opResume, %*{
        "server_id": v.guild_id,
        "session_id": v.session_id,
        "token": v.token
    })

proc identify(v: VoiceClient) {.async.} =
    if v.sockClosed and not v.resuming: return

    log "Sending identify."

    await v.sendSock(opIdentify, %*{
        "server_id": v.guild_id,
        "user_id": v.shard.user.id,
        "session_id": v.session_id,
        "token": v.token
    })

proc selectProtocol(v: VoiceClient) {.async.} =
    if v.sockClosed: return

    await v.sendSock(opSelectProtocol, %*{
        "protocol": "udp",
        "data": {
            "address": ip,
            "port": port,
            "mode": "xsalsa20_poly1305_suffix"
        }
    })

proc reconnect(v: VoiceClient) {.async.} =
    if (v.reconnecting or not v.stop) and not reconnectable: return
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

    await v.sendSock(opHeartbeat,
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

        if data["op"].num == opHello:
            log "Received 'HELLO' from the voice gateway."
            v.interval = int data["d"]["heartbeat_interval"].getFloat

            await v.identify()

            if not v.heartbeating:
                v.heartbeating = true
                asyncCheck v.setupHeartbeatInterval()
        elif data["op"].num == opHeartbeatAck:
            v.lastHBReceived = getTime().toUnixFloat()
            v.hbSent = false
            log "Heartbeat Acknowledged by Discord."

            v.hbAck = true
        elif data["op"].num == opReady:
            ip = data["d"]["ip"].str
            port = data["d"]["port"].getInt
            ssrc = data["d"]["ssrc"].getInt

            v.ready = true
            await v.selectProtocol()
        elif data["op"].num == opResumed:
            v.resuming = false
        elif data["op"].num == opSessionDescription:
            secret_key = data["d"]["secret_key"].elems.mapIt(it.getInt)
            await v.voice_events.on_ready(v)
        else:
            discard

    if not reconnectable: return

    if packet[0] == Close:
        shouldReconnect = v.handleDisconnect(packet[1])
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
    let pid = startProcess(cmd, args = args, options = {
        poUsePath, poStdErrToStdOut
    })

    let outStream = pid.outputStream
    let errStream = pid.errorStream

    while pid.running:
        let d = readDataStr(outStream, buf, 0 ..< size)
        yield buf[0 .. d - 1]

proc pause(v: VoiceClient) {.async.} =
    if playing:
        playing = false

proc sendAudio(v: VoiceClient, input: string) {.async.} = # uncomplete/unfinished code
    let
        udp = newSocket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
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
            "libopus",
            "-loglevel",
            "quiet",
            "pipe:1"
        ]
    var
        sequence = 0
        timestamp = uint32 0
        chunked = ""

    playing = true
    for chunk in chunkedStdout("ffmpeg", args, 300):
        var data = ""
        chunked.add chunk
        if chunked.len >= 1500:
            for c in chunked:
                data.add c
            data = data[0..(if data.high >= 1500: 1500 else: data.high)]

        var packet: string
        if 1 + sequence == 65535:
            sequence = 0
        if 9600 + timestamp == uint32 4294967295:
            timestamp = 0

        sequence += 1

        if not playing:
            for i in 1..5:
                packet.addInt(0xF8)
                packet.addInt(0xFF)
                packet.addInt(0xFE)
                udp.sendTo(ip, Port(port), packet)

                await v.sendSock(opSpeaking, %*{"speaking": false})
            while not playing:
                poll()
        if stopped: break

        var key: string
        for c in secret_key:
            key.add chr(c)
        timestamp += 960

        packet.addUint8(0x80)
        packet.addUint8(0x78)
        packet.addUint16(uint16 sequence)
        packet.addUint32(uint32 timestamp)
        packet.addUint32(uint32 ssrc)

        packet.add crypto_secretbox_easy_nonce(key, data)
        udp.sendTo(ip, Port(port), packet)

        await sleepAsync 20

proc playFFmpeg*(v: VoiceClient, input: string) {.async.} =
    ## Play audio through ffmpeg, input can be a url or a path.
    await v.sendSock(opSpeaking, %*{"speaking": true})
    await v.sendAudio(input)
    await v.sendSock(opSpeaking, %*{"speaking": false})

# proc latency*(v: VoiceClient) {.async.} =
#     ## Get latency of the voice client.
#     discard
