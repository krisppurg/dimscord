import zip/zlib, httpclient, ws, asyncnet, asyncdispatch
import strformat, options, sequtils, strutils, restapi, dispatch
import tables, random, times, constants, objects, json, math
import nativesockets

randomize()
{.hint[XDeclaredButNotUsed]: off.}
{.warning[UnusedImport]: off.}

const
    opDispatch = 0
    opHeartbeat = 1
    opIdentify = 2
    opStatusUpdate = 3
    opVoiceStateUpdate = 4
    opResume = 6
    opReconnect = 7
    opRequestGuildMembers = 8
    opInvalidSession = 9
    opHello = 10
    opHeartbeatAck = 11

var
    gateway: tuple[shards: int, url: string]
    backoff = false
    reconnectable = true

proc logShard(s: Shard, msg: string, info: seq[string] = @[]) =
    when defined(dimscordDebug):
        var finalmsg = &"[gateway - SHARD: {s.id}]: {msg}"

        if info.len > 0:
            finalmsg = &"{finalmsg}:"
            for i, e in info:
                finalmsg &= (if (i and 1) == 0: &"\n  {e}: " else: &"{e}")

        echo finalmsg

proc sendSock(s: Shard,
            opcode: int,
            data: JsonNode,
            ignore = false) {.async.} =
    if not ignore and s.session_id == "": return

    s.logShard("Sending OP: " & $opcode)

    if len($data) > 4096:
        raise newException(Exception,
            "There was an attempt on sending a payload over 4096 characters.")

    await s.connection.send($(%*{
        "op": opcode,
        "d": data
    }))

proc waitWhenReady(s: Shard) {.async.} =
    while not s.ready:
        await sleepAsync 500

proc extractCloseData(data: string): tuple[code: int, reason: string] = # Code from: https://github.com/niv/websocket.nim/blame/master/websocket/shared.nim#L230
    var data = data
    result.code =
        if data.len >= 2:
            cast[ptr uint16](addr data[0])[].htons.int
        else:
            0
    result.reason = if data.len > 2: data[2..^1] else: ""

proc handleDisconnect(s: Shard, msg: string): bool =
    let closeData = extractCloseData(msg)

    s.logShard("Socket suspended", @[
        "code", $closeData.code,
        "reason", closeData.reason
    ])

    s.authenticating = false
    s.resuming = false

    s.hbAck = false
    s.hbSent = false
    s.ready = false
    backoff = false
    s.heartbeating = false
    s.retry_info = (ms: 1000, attempts: 0)
    s.lastHBTransmit = 0
    s.lastHBReceived = 0

    result = true

    if closeData.code in [4003, 4004, 4005, 4007, 4010, 4011, 4012, 4013, 4014]:
        result = false
        log("Fatal error: " & closeData.reason)

proc sockClosed(s: Shard): bool =
    return s.connection == nil or s.connection.readyState == Closed

proc updateStatus*(s: Shard, game = none GameStatus;
        status = "online";
        afk = false) {.async.} =
    ## Updates the shard's status.
    if s.stop or s.sockClosed and not s.ready: return
    let payload = %*{
        "since": 0,
        "afk": afk,
        "status": status
    }

    if game.isSome:
        payload["game"] = newJObject()
        payload["game"]["type"] = %game.get.kind
        payload["game"]["name"] = %game.get.name

        if game.get.url.isSome:
            payload["game"]["url"] = %get game.get.url

    asyncCheck s.sendSock(opStatusUpdate, payload)

proc identify(s: Shard) {.async.} =
    if s.authenticating or s.sockClosed: return

    if backoff:
        await sleepAsync 5000
        await s.identify()
        return

    s.authenticating = true
    backoff = true

    s.logShard("Identifying...")

    let payload = %*{
        "token": s.client.token,
        "properties": %*{
            "$os": system.hostOS,
            "$browser": libName,
            "$device": libName
        },
        "compress": s.compress,
        "guild_subscriptions": s.client.guildSubscriptions
    }

    if s.client.max_shards > 1:
        payload["shard"] = %[s.id, s.client.max_shards]

    if s.client.largeThreshold >= 50 and s.client.largeThreshold <= 250:
        payload["large_threshold"] = %s.client.largeThreshold

    if s.client.intents.len > 0:
        payload["intents"] = %cast[int](s.client.intents)

    await s.sendSock(opIdentify, payload, ignore = true)
    if s.client.max_shards > 1: await sleepAsync 5000

proc resume(s: Shard) {.async.} =
    if s.authenticating or s.sockClosed: return

    s.authenticating = true
    s.resuming = true

    s.logShard("Attempting to resume", @[
        "session_id", s.session_id,
        "events", $s.sequence
    ])
    await s.sendSock(opResume, %*{
        "token": s.client.token,
        "session_id": s.session_id,
        "seq": s.sequence
    })

proc requestGuildMembers*(s: Shard, guild_id: seq[string];
        limit: int;
        query, nonce = "";
        presences = false;
        user_ids: seq[string] = @[]) {.async.} =
    ## Requests the offline members to a guild.
    ## (See: https://discord.com/developers/docs/topics/gateway#request-guild-members)
    if s.sockClosed or not s.ready: return

    if guild_id.len == 0:
        raise newException(Exception, "You need to specify a guild id.")

    let payload = %*{
        "guild_id": guild_id,
        "query": query,
        "limit": limit,
        "presences": presences
    }
    if user_ids.len > 0:
        payload["user_ids"] = %user_ids
    if nonce != "":
        payload["nonce"] = %nonce

    await s.sendSock(opRequestGuildMembers, payload)

proc voiceStateUpdate*(s: Shard, guild_id: string,
        channel_id = none string;
        self_mute, self_deaf = false) {.async.} =
    ## Allows the shard to either join, move to, or disconnect.
    ## If channel_id param is not provided. It will disconnect.
    if s.sockClosed or not s.ready: return

    if guild_id == "":
        raise newException(Exception, "You need to specify a guild id.")

    await s.sendSock(opVoiceStateUpdate, %*{
        "guild_id": guild_id,
        "channel_id": channel_id
    })

proc handleDispatch(s: Shard, event: string, data: JsonNode) {.async.} =
    s.logShard("Received event: " & event) # please do not enable dimscordDebug while you are on a large guild.

    case event:
        of "READY":
            s.session_id = data["session_id"].str
            s.authenticating = false
            s.user = newUser(data["user"])
            s.ready = true
            backoff = false
            var shards = 0

            if s.client.shards.len == s.client.max_shards:
                for sh in s.client.shards.values:
                    if sh.ready:
                        shards += 1
            else:
                shards = s.id + 1

            log(&"{shards}/{s.client.max_shards} shards authenticated.")

            s.logShard("Successfully identified.")

            await s.client.events.on_ready(s, newReady(data))
        of "RESUMED":
            s.resuming = false
            s.authenticating = false
            s.ready = true

            s.logShard("Successfuly resumed.")
        else:
            await s.client.events.on_dispatch(s, event, data)
            await s.handleEventDispatch(event, data)

proc reconnect(s: Shard) {.async.} =
    if s.reconnecting or not s.stop: return
    s.reconnecting = true
    s.retry_info.attempts += 1

    var url = s.gatewayUrl

    if s.retry_info.attempts > 3:
        try:
            url = await s.client.api.getGateway()
            s.gatewayUrl = url
        except:
            s.logShard("Error occurred:: \n" & getCurrentExceptionMsg())
            s.reconnecting = false

            s.retry_info.ms = min(s.retry_info.ms + max(rand(6000), 3000), 30000)

            s.logShard(&"Reconnecting in {s.retry_info.ms}ms", @[
                "attempt", $s.retry_info.attempts
            ])

            await sleepAsync s.retry_info.ms
            await s.reconnect()
            return

    let prefix = if url.startsWith("gateway"): "ws://" & url else: url

    s.logShard("Connecting to " & $prefix & "/?v=" & $s.client.gatewayVer)

    try:
        s.connection = await newWebSocket(prefix &
            "/?v=" & $s.client.gatewayVer)
        s.hbAck = true
        s.stop = false
        s.reconnecting = false
        s.retry_info.attempts = 0
        s.retry_info.ms = max(s.retry_info.ms - 5000, 1000)

        if s.networkError:
            s.logShard("Connection established after network error.")
            s.retry_info = (ms: 1000, attempts: 0)
            s.networkError = false
    except:
        s.logShard("Error occurred: \n" & getCurrentExceptionMsg())

        s.logShard(&"Failed to connect, reconnecting in {s.retry_info.ms}ms",@[
            "attempt", $s.retry_info.attempts
        ])
        s.reconnecting = false
        await sleepAsync s.retry_info.ms
        await s.reconnect()
        return

    if s.session_id == "" and s.sequence == 0:
        await s.identify()
    else:
        await s.resume()

proc disconnect*(s: Shard, should_reconnect = true) {.async.} =
    ## Disconnects a shard.
    if s.stop: return
    s.stop = true

    if not s.stop or not s.sockClosed:
        s.connection.close()

    if should_reconnect:
        await s.reconnect()
    else:
        reconnectable = false

proc heartbeat(s: Shard, requested = false) {.async.} =
    if not s.hbAck and not requested:
        s.logShard("A zombied connection has been detected.")
        await s.disconnect(should_reconnect = true)
        return

    s.logShard("Sending heartbeat.")
    s.hbAck = false

    await s.sendSock(opHeartbeat, %* s.sequence, ignore = true)
    s.lastHBTransmit = getTime().toUnixFloat()
    s.hbSent = true

proc setupHeartbeatInterval(s: Shard) {.async.} =
    if not s.heartbeating: return
    s.heartbeating = true

    while not s.sockClosed or not s.stop:
        let hbTime = int((getTime().toUnixFloat() - s.lastHBTransmit) * 1000)

        if hbTime < s.interval - 8000 and s.lastHBTransmit != 0.0:
            break

        asyncCheck s.heartbeat()
        await sleepAsync s.interval

proc handleSocketMessage(s: Shard) {.async.} =
    await s.identify()

    var packet: (Opcode, string)
    var shouldReconnect = s.client.autoreconnect

    while not s.sockClosed and not s.stop:
        try:
            packet = await s.connection.receivePacket()
        except:
            var exceptn = getCurrentExceptionMsg()
            s.logShard(
                "Error occurred in websocket ::\n" & getCurrentExceptionMsg()
            )

            if not s.stop: s.stop = true
            if s.heartbeating: s.heartbeating = false

            if exceptn.startsWith("The semaphore timeout period has expired."):
                s.logShard("A network error has been detected.")

                s.networkError = true
                break
            else:
                break

        var data: JsonNode

        if s.compress and packet[0] == Binary:
            packet[1] = zlib.uncompress(packet[1])

        try:
            data = parseJson(packet[1])
        except:
            s.logShard("An error occurred while parsing data: " & packet[1])
            shouldReconnect = s.handleDisconnect(packet[1])

            await s.disconnect(should_reconnect = shouldReconnect)
            break

        if data["s"].kind != JNull and not s.resuming:
            s.sequence = data["s"].getInt()

        case data["op"].num
            of opHello:
                s.logShard("Received 'HELLO' from the gateway.")
                s.interval = data["d"]["heartbeat_interval"].getInt()

                if not s.heartbeating:
                    s.heartbeating = true
                    asyncCheck s.setupHeartbeatInterval()
            of opHeartbeatAck:
                s.lastHBReceived = getTime().toUnixFloat()
                s.hbSent = false
                s.logShard("Heartbeat Acknowledged by Discord.")

                s.hbAck = true
            of opHeartbeat:
                s.logShard("Discord is requesting for a heartbeat.")
                await s.heartbeat(true)
            of opDispatch:
                asyncCheck s.handleDispatch(data["t"].str, data["d"])
            of opReconnect:
                s.logShard("Discord is requesting for a client reconnect.")
                await s.disconnect(should_reconnect = shouldReconnect)
            of opInvalidSession:
                var interval = 5000

                if s.resuming:
                    interval = rand(1000..5000)
                    s.resuming = false
                s.authenticating = false

                s.logShard("Session invalidated", @[
                    "resumable", $data["d"].getBool
                ])

                if data["d"].getBool:
                    await s.resume()
                else:
                    s.session_id = ""
                    s.sequence = 0
                    s.cache.clear()

                    s.logShard(&"Identifying in {interval}ms...")

                    await sleepAsync interval
                    await s.identify()
            else:
                discard
    if packet[0] == Close:
        shouldReconnect = s.handleDisconnect(packet[1])

    s.stop = true
    s.resuming = false
    s.authenticating = false
    s.ready = false
    s.hbAck = false
    s.hbSent = false
    s.lastHBReceived = 0
    s.lastHBTransmit = 0

    if shouldReconnect and reconnectable:
        await s.reconnect()
        await sleepAsync 2000
        if not s.networkError: await s.handleSocketMessage()
    else:
        return

proc endSession*(cl: DiscordClient) {.async.} =
    ## Ends the session.
    for shard in cl.shards.values:
        await shard.disconnect(should_reconnect = false)
        shard.cache.clear()

proc setupShard(cl: DiscordClient, i: int;
        compress: bool; cache_prefs: CacheTablePrefs): Shard =
    result = newShard(i, cl)
    cl.shards.add(i, result)
    result.compress = compress

    result.cache.preferences = cache_prefs

proc startSession(s: Shard, url, query: string) {.async.} =
    s.logShard("Connecting to " & url & query)

    try:
        s.connection = await newWebsocket(url & query)
        s.hbAck = true
        s.logShard("Socket is open.")
    except:
        s.stop = true
        raise newException(Exception, getCurrentExceptionMsg())

    try:
        await s.handleSocketMessage()
    except:
        if getCurrentExceptionMsg()[0].isAlphaNumeric: return

proc startSession*(cl: DiscordClient,
            compress = false;
            autoreconnect = true;
            gateway_intents: set[GatewayIntent] = {};
            large_message_threshold, large_threshold = 50;
            max_message_size = 5_000_000;
            gateway_version = 6;
            max_shards = 1;
            cache_users, cache_guilds, guild_subscriptions = true;
            cache_guild_channels, cache_dm_channels = true) {.async.} =
    ##[
        Connects the client to Discord via gateway.

        - `gateway_intents` Allows you to subscribe to pre-defined events.
        - `compress` The zlib1(.dll|.so.1|.dylib) file needs to be in your directory.
        - `large_threshold` The number that would be considered a large guild (50-250).
        - `guild_subscriptions` Whether or not to receive presence_update, typing_start events.
        - `autoreconnect` Whether the client should reconnect whenever a network error occurs.
        - `max_message_size` Max message JSON size (MESSAGE_CREATE) the client should cache in bytes.
        - `large_message_threshold` Max message limit (MESSAGE_CREATE)
    ]##
    if cl.restMode:
        raise newException(Exception, "(╯°□°)╯ REST mode is enabled! (╯°□°)╯")
    elif cl.token == "Bot  ":
        raise newException(Exception, "The token you specified was empty.")

    cl.autoreconnect = autoreconnect
    cl.intents = gateway_intents
    cl.largeThreshold = large_threshold
    cl.guildSubscriptions = guild_subscriptions
    cl.max_shards = max_shards
    cl.gatewayVer = gateway_version

    var
        query = "/?v=" & $gateway_version
        info: GatewayBot

    if cl.shards.len == 0:
        log("Starting gateway session.")

        try:
            info = await cl.api.getGatewayBot()
        except OSError:
            if getCurrentExceptionMsg().startsWith("No such host is known."):
                log("A network error has been detected.")
                return

        log("Successfully retrived gateway information from Discord", @[
            "url", info.url,
            "shards", $info.shards,
            "session_start_limit", $info.session_start_limit
        ])

        if info.session_start_limit.remaining == 10:
            log("WARNING: Your session start limit has reached to 10.")

        if info.session_start_limit.remaining == 0:
            let time = getTime().toUnix() - info.session_start_limit.reset_after

            log("Your session start limit has reached its limit", @[
                "sleep_time", $time
            ])
            await sleepAsync time.int

        if max_shards == 1 and info.shards > 1:
            cl.max_shards = info.shards

    for id in 0..cl.max_shards - 1:
        let s = cl.setupShard(id, compress, CacheTablePrefs(
            cache_users: cache_users,
            cache_guilds: cache_guilds,
            cache_guild_channels: cache_guild_channels,
            cache_dm_channels: cache_dm_channels,
            large_message_threshold: large_message_threshold,
            max_message_size: max_message_size
        ))
        s.gatewayUrl = info.url

        if id == max_shards - 1: # Last shard.
            await s.startSession(s.gatewayUrl, query)
        else:
            asyncCheck s.startSession(s.gatewayUrl, query)

        await s.waitWhenReady()

proc latency*(s: Shard): int =
    ## Gets the shard's latency ms.
    result = int((s.lastHBReceived - s.lastHBTransmit) * 1000)