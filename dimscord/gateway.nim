import zip/zlib, httpclient, websocket, asyncnet, asyncdispatch
import strformat, options, sequtils, strutils, restapi, dispatch
import tables, random, times, constants, objects, json, math

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

proc newShard(id: int, client: DiscordClient): Shard =
    result = Shard(
        id: id,
        client: client,
        retry_info: (ms: 1000, attempts: 0)
    )

proc debugMsg(msg: string, info: seq[string] = @[]) =
    when defined(dimscordDebug):        
        var finalmsg = &"[Lib]: {msg}"

        if info.len > 0:
            finalmsg = &"{finalmsg}:"
            for i, e in info:
                finalmsg &= (if (i and 1) == 0: &"\n  {e}: " else: &"{e}")

        echo finalmsg

proc debugMsg(s: Shard, msg: string, info: seq[string] = @[]) =
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

    s.debugMsg("Sending OP: " & $opcode)

    if len($data) > 4096:
        raise newException(Exception,
            "There was an attempt on sending a payload over 4096 characters.")

    await s.connection.sendText($(%*{
        "op": opcode,
        "d": data
    }))

proc waitWhenReady(s: Shard) {.async.} =
    while not s.ready:
        await sleepAsync 500

proc handleDisconnect(s: Shard, msg: string): bool =
    let closeData = extractCloseData(msg)

    s.debugMsg("Socket suspended", @[
        "code", $closeData.code,
        "reason", closeData.reason
    ])

    if s.authenticating: s.authenticating = false
    if s.resuming: s.resuming = false

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
        debugMsg("Fatal error: " & closeData.reason)

proc sockClosed(s: Shard): bool =
    return s.connection == nil or s.connection.sock.isClosed

proc updateStatus*(s: Shard, game = none GameStatus;
        status = "online";
        afk = false) {.async.} =
    ## Updates the shard's status.
    if s.stop or s.sockClosed: return
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

    s.debugMsg("Identifying...")

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

    s.debugMsg("Attempting to resume", @[
        "session_id", s.session_id,
        "events", $s.sequence
    ])
    await s.sendSock(opResume, %*{
        "token": s.client.token,
        "session_id": s.session_id,
        "seq": s.sequence
    })

proc requestGuildMembers*(s: Shard, guild_id: seq[string];
        query = ""; limit: int;
        presences = false; nonce = "";
        user_ids: seq[string] = @[]) {.async.} =
    ## Requests the offline members to a guild.
    ## (See: https://discord.com/developers/docs/topics/gateway#request-guild-members)
    if s.authenticating or s.sockClosed: return

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
    if s.authenticating or s.sockClosed: return

    if guild_id == "":
        raise newException(Exception, "You need to specify a guild id.")

    await s.sendSock(opVoiceStateUpdate, %*{
        "guild_id": guild_id,
        "channel_id": channel_id
    })

proc handleDispatch(s: Shard, event: string, data: JsonNode) {.async.} =
    s.debugMsg("Received event: " & event)

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

            debugMsg(&"{shards}/{s.client.max_shards} shards authenticated.")

            s.debugMsg("Successfully identified.")

            await s.client.events.on_ready(s, newReady(data))
        of "RESUMED":
            s.resuming = false
            s.authenticating = false
            s.ready = true

            s.debugMsg("Successfuly resumed.")
        else:
            await s.client.events.on_dispatch(s, event, data)
            await s.handleEventDispatch(event, data)

proc reconnect(s: Shard) {.async.} =
    if s.reconnecting or not s.stop: return
    s.reconnecting = true
    s.retry_info.attempts += 1

    var url = "gateway.discord.gg"

    try: 
        url = await s.client.api.getGateway()
    except:
        s.debugMsg("Error occurred:: \n" & getCurrentExceptionMsg())
        s.reconnecting = false

        s.retry_info.ms = min(s.retry_info.ms + max(rand(6000), 3000), 30000)

        s.debugMsg(&"Reconnecting in {s.retry_info.ms}ms", @[
            "attempt", $s.retry_info.attempts
        ])

        await sleepAsync s.retry_info.ms
        await s.reconnect()
        return

    let prefix = if url.startsWith("wss://"): url[6..url.high] else: url

    s.debugMsg("Connecting to " & $prefix & "/?v=" & $s.client.gatewayVer)

    try:
        s.connection = await newAsyncWebsocketClient(
            prefix,
            Port 443,
            "/?v=" & $s.client.gatewayVer,
            true,
            userAgent = libAgent
        )
        s.hbAck = true
        s.stop = false
        s.reconnecting = false

        if s.networkError:
            s.debugMsg("Connection established after network error.")
            s.retry_info = (ms: 1000, attempts: 0)
            s.networkError = false
    except:
        s.debugMsg("Error occurred: \n" & getCurrentExceptionMsg())

        s.debugMsg(&"Failed to connect, reconnecting in {s.retry_info.ms}ms",@[
            "attempt", $s.retry_info.attempts
        ])
        await sleepAsync s.retry_info.ms
        await s.reconnect()
        return

    if s.session_id == "" and s.sequence == 0:
        await s.identify()
    else:
        await s.resume()

proc disconnect*(s: Shard, code = 4000; should_reconnect = true) {.async.} =
    if s.stop: return
    s.stop = true

    if s.connection != nil or not s.connection.sock.isClosed:
        s.debugMsg("Sending close code: " & $code & " to disconnect.")
        await s.connection.close(code)

    if should_reconnect:
        await s.reconnect()
    else:
        reconnectable = false

proc heartbeat(s: Shard, requested = false) {.async.} =
    if not s.hbAck and not requested:
        s.debugMsg("A zombied connection has been detected.")
        await s.disconnect(should_reconnect = true)
        return

    s.debugMsg("Sending heartbeat.")
    s.hbAck = false

    await s.sendSock(opHeartbeat, %* s.sequence, ignore = true)
    s.lastHBTransmit = getTime().toUnixFloat()
    s.hbSent = true

proc setupHeartbeatInterval(s: Shard) {.async.} =
    if not s.heartbeating: return
    s.heartbeating = true

    while not s.stop and not s.connection.sock.isClosed:
        let hbTime = int((getTime().toUnixFloat() - s.lastHBTransmit) * 1000)

        if hbTime < s.interval - 8000 and s.lastHBTransmit != 0.0:
            break

        asyncCheck s.heartbeat()
        await sleepAsync s.interval

proc handleSocketMessage(s: Shard) {.async.} =
    await s.identify()

    var packet: tuple[opcode: Opcode, data: string]
    var shouldReconnect = s.client.autoreconnect

    while not s.connection.sock.isClosed and not s.stop:
        try:
            packet = await s.connection.readData()
        except:
            var exceptn = getCurrentExceptionMsg()
            echo "Error occurred in websocket ::\n", getCurrentExceptionMsg()

            if not s.stop: s.stop = true
            if s.heartbeating: s.heartbeating = false

            if exceptn.startsWith("The semaphore timeout period has expired."):
                s.debugMsg("A network error has been detected.")

                s.networkError = true
                break
            else:
                break

        var data: JsonNode

        if s.compress and packet.opcode == Opcode.Binary:
            packet.data = zlib.uncompress(packet.data)

        try:
            data = parseJson(packet.data)
        except:
            echo "An error occurred while parsing data: " & packet.data
            shouldReconnect = s.handleDisconnect(packet.data)

            await s.disconnect(should_reconnect = shouldReconnect)
            break

        if data["s"].kind != JNull and not s.resuming:
            s.sequence = data["s"].getInt()

        case data["op"].num
            of opHello:
                s.debugMsg("Received 'HELLO' from the gateway.")
                s.interval = data["d"]["heartbeat_interval"].getInt()

                if not s.heartbeating:
                    s.heartbeating = true
                    asyncCheck s.setupHeartbeatInterval()
            of opHeartbeatAck:
                s.lastHBReceived = getTime().toUnixFloat()
                s.hbSent = false
                s.debugMsg("Heartbeat Acknowledged by Discord.")

                s.hbAck = true
            of opHeartbeat:
                s.debugMsg("Discord is requesting for a heartbeat.")
                await s.heartbeat(true)
            of opDispatch:
                asyncCheck s.handleDispatch(data["t"].str, data["d"])
            of opReconnect:
                s.debugMsg("Discord is requesting for a client reconnect.")
                await s.disconnect(should_reconnect = shouldReconnect)
            of opInvalidSession:
                var interval = 5000

                if s.resuming:
                    interval = rand(1000..5000)
                    s.resuming = false
                s.authenticating = false

                s.debugMsg("Session invalidated", @[
                    "resumable", $data["d"].getBool
                ])

                if data["d"].getBool:
                    await s.resume()
                else:
                    s.session_id = ""
                    s.sequence = 0
                    s.cache.clear()

                    s.debugMsg(&"Identifying in {interval}ms...")

                    await sleepAsync interval
                    await s.identify()
            else:
                discard
    if packet.opcode == Close:
        shouldReconnect = s.handleDisconnect(packet.data)

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
    for shard in cl.shards.values:
        await shard.disconnect(should_reconnect = false)
        shard.cache.clear()

proc startSession(s: Shard, url: string, query: string) {.async.} =
    s.debugMsg("Connecting to " & url & query)
    try:
        s.connection = await newAsyncWebsocketClient(
                url[6..url.high],
                Port 443,
                query,
                true,
                userAgent = libAgent
            )
        s.hbAck = true
        s.debugMsg("Socket is open.")
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
            large_threshold = 50;
            gateway_version = 6;
            max_shards = 1;
            cache_users, cache_guilds, guild_subscriptions = true;
            cache_guild_channels, cache_dm_channels = true) {.async.} =
    ## Connects the client to Discord via gateway.
    ##
    ## - `gateway_intents` Allows you to subscribe to pre-defined events.
    ## - `compress` The zlib1(.dll|.so.1|.dylib) file needs to be in your directory.
    ## - `large_threshold` The number that would be considered a large guild (50-250).
    ## - `guild_subscriptions` Whether or not to receive presence_update, typing_start events.

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

    var query = "/?v=" & $gateway_version

    if gateway.url == "":
        debugMsg("Starting the session.")
        var info: GatewayBot

        try:
            info = await cl.api.getGatewayBot()
        except OSError:
            if getCurrentExceptionMsg().startsWith("No such host is known."):
                debugMsg("A network error has been detected.")
                return

        debugMsg("Successfully retrived gateway information from Discord", @[
            "url", info.url,
            "shards", $info.shards,
            "session_start_limit", $info.session_start_limit
        ])

        if info.session_start_limit.remaining == 10:
            debugMsg("WARNING: Your session start limit has reached to 10.")

        if info.session_start_limit.remaining == 0:
            let time = getTime().toUnix() - info.session_start_limit.reset_after

            debugMsg("Your session start limit has reached its limit", @[
                "sleep_time", $time
            ])
            await sleepAsync time.int

        gateway = (info.shards, info.url)

    if max_shards == 1 and gateway.shards > 1:
        cl.max_shards = gateway.shards

    if max_shards > 1:
        for i in 0..cl.max_shards - 2:
            let s = newShard(i, cl)
            cl.shards.add(i, s)
            s.compress = compress
            s.cache = newCacheTable(cache_users, cache_guilds,
                cache_guild_channels, cache_dm_channels)

            asyncCheck s.startSession(gateway.url, query)

            await s.waitWhenReady()

    let s = newShard(cl.max_shards - 1, cl)
    cl.shards.add(cl.max_shards - 1, s)
    s.compress = compress
    s.cache = newCacheTable(cache_users, cache_guilds,
        cache_guild_channels, cache_dm_channels)

    await s.startSession(gateway.url, query)

proc latency*(s: Shard): int =
    ## Gets the shard's latency ms.
    result = int((s.lastHBReceived - s.lastHBTransmit) * 1000)