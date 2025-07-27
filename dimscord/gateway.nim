## Interact with the discord api gateway.
## Especially `startSession`, `updateStatus`.

import httpclient, ws, asyncnet, asyncdispatch
import strformat, options, strutils, ./restapi/user
import tables, random, times, constants, objects, json
import nativesockets, helpers, dispatch {.all.}, sequtils

when defined(discordEtf):
    import etf
    type DataValue = Term
else:
    type DataValue = JsonNode

when defined(discordCompress): import zippy

randomize()

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
    backoff = false
    reconnectable = true
    invididualShard = false

proc reset(s: Shard) {.used.} =
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

proc logShard(s: Shard, msg: string, info: tuple) =
    when defined(dimscordDebug):
        var finalmsg = "[shard: " & $s.id & "]: " & msg
        let tup = $info

        finalmsg = finalmsg & "\n    " & tup[1..tup.high - 1]

        echo finalmsg

proc logShard(s: Shard, msg: string) =
    when defined(dimscordDebug):
        echo "[shard: " & $s.id & "]: " & msg

proc sockClosed(s: Shard): bool {.used.} =
    return s.connection == nil or s.connection.tcpSocket.isClosed or s.stop

when defined(discordEtf):
    proc term(x: bool): Term = Term(tag: tagAtom, atom: Atom $x)
    proc term(x: string): Term = binary x
    proc term(x: int): Term =
        if x in uint8.low.int..uint8.high.int:
            term x.uint8
        else:
            term x.int32

    proc term(x: Table[string, Term], useatom=false): Term =
        var v: seq[(Term, DataValue)] = @[]
        for k in x.keys:
            let key = block:
                if useatom:
                    Term(tag: tagAtom, atom: Atom k)
                else:
                    binary(k)
            v.add (
                key,
                x[k]
            )
        result = term(toOpenArray(v, v.low, v.high))

    proc term [T: Table[string, Term]](x: seq[T]): Term =
        term toOpenArray(x.mapIt(term(it,false)), x.low, x.high)

    proc term [T: not Table[string, Term]](x: seq[T]): Term =
        term toOpenArray(x.mapIt(term(it)), x.low, x.high)

    proc toUgly(result: var string, x: DataValue; fieldname = "") =
        var comma = false

        case x.tag:
        of tagList:
            result.add "["
            for child in x.lst:
                if comma: result.add ","
                else: comma = true

                result.toUgly child
            result.add "]"
        of tagMap:
            result.add "{"
            for (key, value) in x.map:
                if comma: result.add ","
                else: comma = true
                var fld = ""

                case key.tag:
                of tagAtom: fld = string(key.atom)
                of tagBinary: fld = key.bin
                else: discard

                fld.escapeJson(result)
                result.add ":"
                result.toUgly value, fld
            result.add "}"
        of tagString:
            var res: seq[int] = @[]
            for chr in cast[seq[char]](x.str):
                res.add(int chr)

            result.toUgly res.term
        of tagAtom:
            let v = string x.atom

            case v:
            of "nil": result.add("null")
            of "true": result.add("true")
            of "false": result.add("false")
            else:
                escapeJson(v, result)
        of tagBinary: escapeJson(x.bin, result)
        of tagInt32: result.addInt(x.i32)
        of tagUint8: result.addInt(x.u8)
        of tagSmallBigInt:
            var u: uint64
            copyMem(addr u, unsafeAddr x.bigint.data[0], x.bigint.data.len)

            if x.bigint.data.len in 7..8 or "id" in fieldname:
                result.add('"'&($u)&'"')
            else:
                result.add($u)
        of tagFloat64: result.addFloat(x.f64)
        of tagNil: result.add "[]"
        else:
            discard

    proc len(x: DataValue): int =
        case x.tag:
        of tagList: result = x.lst.len
        of tagMap: result = x.map.len
        else: discard

    proc toJson(x: DataValue): string =
        result = newStringOfCap(x.len shl 1)
        toUgly(result, x)

proc `%%`(v: openarray[(string, DataValue)]): Table[string, DataValue] =
    v.toTable

proc toTerm [T: auto](x: T): DataValue =
    when x is seq:
        if x.len == 0: term nil
    else: term x

proc `&`[T: auto](v: T): DataValue =
    when defined(discordEtf):
        when v is Option:
            if v.isSome: term(v.get) else: Term(tag: tagAtom, atom: Atom "nil")
        else:
            term(v)
    else:
        %*v

proc `$`(p: Table[string, DataValue]): string =
    when defined(discordEtf): toEtf term(p) else: json.`$`(p)

proc sendSock(s: Shard, opcode: int, data: Table[string, DataValue] | DataValue;
        ignore = false) {.async.} =
    if s.sockClosed: return # I think I finally solved the segfault issue after a long time.
    if not ignore and s.session_id == "": return

    s.logShard("Sending OP: " & $opcode)

    let payload = %%{
        "op": &uint8 opcode,
        "d": when data is not DataValue: &data else: data
    }
    var tosend: (string, Opcode)

    when defined(discordEtf):
        tosend = (term(payload).toEtf, Opcode.Binary)
    else:
        tosend = ($payload, Opcode.Text)

    doAssert(len(tosend[0]) <= 4096,
        "There was an attempt on sending a payload over 4096 characters."
    )
    let fut = s.connection.send(tosend[0], tosend[1])

    if not (await withTimeout(fut, 20000)):
        s.logShard("Payload OP " & $opcode & " was taking longer to send. Retrying in 5000ms...")
        await sleepAsync 5000
        await s.sendSock(opcode, data, ignore)
        return
    else:
        await fut

proc waitWhenReady(s: Shard) {.async.} =
    while not s.ready:
        await sleepAsync 500 # Incase if we get INVALID_SESSIONs.

proc extractCloseData(data: string): tuple[code: int, reason: string] = # Code from: https://github.com/niv/websocket.nim/blame/master/websocket/shared.nim#L230
    var data = data
    result.code =
        if data.len >= 2:
            cast[ptr uint16](addr data[0])[].htons.int
        else:
            0
    result.reason = if data.len > 2: data[2..^1] else: ""

proc handleDisconnect(s: Shard, msg: string): bool {.used.} =
    let closeData = extractCloseData(msg)

    s.logShard("Socket suspended", (
        code: closeData.code,
        reason: closeData.reason
    ))
    if not s.stop:
        s.stop = true
        asyncCheck s.client.events.on_disconnect(s)

    s.reset()

    result = true

    if closeData.code in [4003, 4004, 4005, 4007, 4010, 4011, 4012, 4013, 4014]:
        result = false
        log("Fatal error: " & closeData.reason)

proc updateStatus*(s: Shard, activities: seq[ActivityStatus] = @[];
        status = "online";
        afk = false) {.async.} =
    ## Updates the shard's status.
    if s.sockClosed or not s.ready: return
    var acts: seq[Table[string, DataValue]] = @[]
    var payload = %%{
        "since": &uint8 0,
        "afk": &afk,
        "status": &status,
        "activities": &initTable[string, DataValue]()
    }

    payload["activities"] = &activities.mapIt(%%{
        "type": &uint8 it.kind,
        "name": &it.name,
        "url": &it.url,
        "state": &it.state
    })
    
    await s.sendSock(opStatusUpdate, payload)

proc updateStatus*(s: Shard, activity = none ActivityStatus;
        status = "online";
        afk = false) {.async.} =
    ## Updates the shard's status.
    await s.updateStatus(
        activities = (if activity.isSome: @[activity.get] else: @[]),
        status = status,
        afk = afk
    )

proc identify(s: Shard) {.async, used.} =
    if s.authenticating or s.sockClosed: return

    if backoff:
        await sleepAsync 5000
        await s.identify()
        return

    s.authenticating = true
    backoff = true

    s.logShard("Identifying...")

    var payload = %%{
        "token": &s.client.token,
        "properties": &(%%{
            "os": &system.hostOS,
            "browser": &libName,
            "device": &libName
        }),
        "compress": &defined(discordCompress)
    }

    if s.client.max_shards > 1:
        payload["shard"] = & @[s.id, s.client.max_shards]

    if s.client.largeThreshold >= 50 and s.client.largeThreshold <= 250:
        payload["large_threshold"] = &int32 s.client.largeThreshold

    if s.client.intents.len > 0:
        payload["intents"] = &cast[int](s.client.intents)

    await s.sendSock(opIdentify, payload, ignore = true)
    if s.client.max_shards > 1 and not invididualShard:
        await sleepAsync 5000

proc resume*(s: Shard) {.async.} =
    if s.authenticating or s.sockClosed: return

    s.authenticating = true
    s.resuming = true

    s.logShard(
        "Attempting to resume\n" &
        "  session_id: " & s.session_id & "\n" &
        "  sequence: " & $s.sequence
    )
    await s.sendSock(opResume, %%{
        "token": &s.client.token,
        "session_id": &s.session_id,
        "seq": & s.sequence
    })

proc requestGuildMembers*(s: Shard, guild_id: string or seq[string];
        limit = none int; query = none string; nonce = "";
        presences = false; user_ids: seq[string] = @[]) {.async.} =
    ## Requests the offline members to a guild.
    ## (See: https://discord.com/developers/docs/topics/gateway#request-guild-members)
    if s.sockClosed or not s.ready: return

    if guild_id.len == 0:
        raise newException(Exception, "You need to specify a guild ID.")

    var payload = %%{
        "guild_id": &guild_id,
        "presences": &presences
    }
    if query.isSome:
        assert(
            limit.isSome,
            "You need to specify the limit once you've specified query."
        )
        payload["query"] = &query
    if limit.isSome:
        payload["limit"] = &limit
    if user_ids.len > 0:
        payload["user_ids"] = &user_ids
    if nonce != "":
        payload["nonce"] = &nonce

    await s.sendSock(opRequestGuildMembers, payload)

proc getGuildMember*(s: Shard;
        guild_id, user_id: string;
        presence = false): Future[Member] {.async.} =
    ## Gets a guild member by using `requestGuildMembers`.
    ## - `presence` Have members presence when returned (member.presence).
    await s.requestGuildMembers(guild_id,
        user_ids = @[user_id],
        presences = presence
    )

    proc handled(g: Guild, e: GuildMembersChunk): bool =
        return e.members.len >= 0

    let evt = await s.client.waitFor(deGuildMembersChunk, handled)

    if evt.m.members.len == 0: raise newException(Exception, "Member not found")
    result = evt.m.members[0]
    if evt.m.presences.len != 0: result.presence = evt.m.presences[0]

proc voiceStateUpdate*(s: Shard,
        guild_id: string, channel_id = none string;
        self_mute, self_deaf = false) {.async.} =
    ## Allows the shard to either join, move to, or disconnect.
    ## If channel_id param is not provided. It will disconnect.
    if s.sockClosed or not s.ready: return

    if guild_id == "":
        raise newException(Exception, "You need to specify a guild id.")

    await s.sendSock(opVoiceStateUpdate, %%{
        "guild_id": &guild_id,
        "channel_id": &channel_id,
        "self_mute": &self_mute,
        "self_deaf": &self_deaf,
    })

proc handleDispatch(s: Shard, event: string, data: JsonNode) {.async, used.} =
    when defined(dimscordDebugNoSubscriptionLogs):
      if event notin @["PRESENCE_UPDATE", "TYPING_START"]:
            s.logShard("Received event: " & event)
    else:
        s.logShard("Received event: " & event) # please do not enable dimscordDebug while you are on a large guild.

    case event:
    of "READY":
        s.session_id = data["session_id"].str
        s.resumeGatewayUrl = data["resume_gateway_url"].str
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

        asyncCheck s.client.events.on_ready(s, newReady(data))
    of "RESUMED":
        s.resuming = false
        s.authenticating = false
        s.ready = true

        s.logShard("Successfuly resumed.")
    else:
        asyncCheck s.client.events.on_dispatch(s, event, data)
        s.client.checkIfAwaiting(Unknown, (event, data))
        let eventKind = parseEnum[DispatchEvent](event, Unknown)

        asyncCheck s.handleEventDispatch(eventKind, data)

proc reconnect(s: Shard) {.async.} =
    if (s.reconnecting or not s.stop) and not reconnectable: return
    if s.authenticating: return
    s.reconnecting = true
    s.retry_info.attempts += 1

    var url = s.resumeGatewayUrl
    var query = "?v=" & $s.client.gatewayVersion
    when defined(discordEtf): query &= "&encoding=etf"
    if not url.endsWith("/"): url &= "/"

    if s.retry_info.attempts > 3:
        if not s.networkError:
            s.networkError = true
            s.logShard("A potential network error has been detected.")

    s.logShard("Connecting to " & url & query)

    try:
        let future = newWebSocket(url & query)

        s.reconnecting = false
        s.stop = false

        if not (await withTimeout(future, 25000)):
            s.logShard("Websocket timed out.\n\n  Retrying connection...")

            await s.reconnect()
            return

        s.connection = await future
        s.hbAck = true

        s.retry_info.attempts = 0
        s.retry_info.ms = max(s.retry_info.ms - 5000, 1000)

        if s.networkError:
            s.logShard("Connection established after network error.")
            s.retry_info = (ms: 1000, attempts: 0)
            s.networkError = false
    except:
        s.logShard("Error occurred:: \n" & getCurrentExceptionMsg())
        s.reconnecting = false

        s.retry_info.ms = min(
            s.retry_info.ms + max(rand(6000), 3000), 30000)

        s.logShard(&"Reconnecting in {s.retry_info.ms}ms", (
            attempt: s.retry_info.attempts
        ))

        await sleepAsync s.retry_info.ms
        await s.reconnect()
        return

    if s.session_id == "" and s.sequence == 0:
        await s.identify()
    else:
        await s.resume()

proc disconnect*(s: Shard, should_reconnect = true) {.async.} =
    ## Disconnects a shard.
    if s.sockClosed: return

    s.logShard("Shard disconnecting...")

    s.stop = true
    s.reset()

    if s.connection != nil:
        s.connection.close()
        await s.client.events.on_disconnect(s)

    if should_reconnect:
        s.logShard("Shard reconnecting after disconnect...")
        await s.reconnect()
    else:
        raise newException(
            Exception,
            "Shard(s) disconnected."
        )

proc heartbeat(s: Shard, requested = false) {.async.} =
    if s.sockClosed or s.resuming: return

    if not requested:
        if not s.hbAck:
            s.logShard("A zombied connection was detected.")
            await s.disconnect(should_reconnect = true)
            return
        s.hbAck = false
    s.logShard("Sending heartbeat.")

    await s.sendSock(opHeartbeat, &s.sequence, ignore = true)
    s.lastHBTransmit = getTime().toUnixFloat()
    s.hbSent = true

proc setupHeartbeatInterval(s: Shard) {.async.} =
    if not s.heartbeating: return
    s.heartbeating = true

    while not s.sockClosed:
        let hbTime = int((getTime().toUnixFloat() - s.lastHBTransmit) * 1000)

        if hbTime < s.interval - 8000 and s.lastHBTransmit != 0.0:
            break

        await s.heartbeat()
        await sleepAsync s.interval

proc handleSocketMessage(s: Shard) {.async.} =
    await s.identify()

    var
        packet: (Opcode, string)
        autoreconnect = s.client.autoreconnect

    while not s.sockClosed:
        try:
            packet = await s.connection.receivePacket()
        except:
            let exceptn = getCurrentExceptionMsg()
            s.logShard(
                "Error occurred in websocket ::\n" & getCurrentExceptionMsg()
            )
            if not s.stop:
                s.stop = true
                await s.client.events.on_disconnect(s)
            s.heartbeating = false

            if exceptn.startsWith("The semaphore timeout period has expired."):
                s.logShard("A network error has been detected.")

                s.networkError = true
                break
            else:
                break

        var data: JsonNode

        when defined(discordCompress):
            if packet[0] == Binary:
                packet[1] = uncompress(packet[1])
                # buffer &= packet[1]
                # if len(packet[1]) >= 4:
                #     if packet[1][^4..^1] == zlib_suffix:
                #         packet[1] = uncompress(buffer)
                #         buffer = ""
                #     else:
                #         return
                # else:
                #     return

        try:
            when defined(discordEtf):
                packet[1] = toJson packet[1].parseEtf
            data = parseJson(packet[1])
        except:
            if not s.hbAck and not defined(discordEtf):
                s.logShard("A zombied connection was detected.")
            else:
                s.logShard(
                    "An error occurred while parsing data: "&packet[1]
                )
            autoreconnect = s.handleDisconnect(packet[1])

            await s.disconnect(should_reconnect = autoreconnect)
            break

        if data["s"].kind != JNull and not s.resuming:
            s.sequence = data["s"].getInt

        case data["op"].num:
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
            await s.heartbeat true
        of opDispatch:
            asyncCheck s.handleDispatch(data["t"].str, data["d"])
        of opReconnect:
            s.logShard("Discord is requesting for a client reconnect.")

            await s.disconnect(should_reconnect = autoreconnect)
            await s.client.events.on_disconnect(s)
        of opInvalidSession:
            var interval = 5000

            if s.resuming:
                interval = rand(1000..5000)
                s.resuming = false
            s.authenticating = false

            s.logShard("Session invalidated", (
                resumable: data["d"].getBool
            ))

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
    if not reconnectable:
        raise newException(Exception, "Fatal error occurred.")

    if packet[0] == Close:
        if not autoreconnect:
            autoreconnect = s.handleDisconnect(packet[1])

    s.stop = true
    s.reset()

    if autoreconnect:
        await s.reconnect()
        await sleepAsync 2000

        if not s.networkError: await s.handleSocketMessage()
    else:
        let info = extractCloseData(packet[1])
        raise newException(
            Exception,
            "Fatal discord gateway error: "&"["&($info.code)&"] "&info.reason
        )

proc endSession*(discord: DiscordClient) {.async.} =
    ## Ends the session.
    for shard in discord.shards.values:
        await shard.disconnect(should_reconnect = false)
        shard.cache.clear()

proc setupShard(discord: DiscordClient, i: int;
        cache_prefs: CacheTablePrefs): Shard {.used.} =
    result = newShard(i, discord)
    discord.shards[i] = result

    result.cache.preferences = cache_prefs

proc startSession(s: Shard, url, query: string) {.async.} =
    s.logShard("Connecting to " & url & query)

    try:
        let future = newWebsocket(url & query)

        if not (await withTimeout(future, 25000)):
            s.logShard("Websocket timed out.\n\n  Retrying connection...")
            await s.startSession(url, query)
            return
        s.connection = await future
        s.hbAck = true
        s.logShard("Socket connection established.")
        # s.logShard("Socket state:\n  ->  " & $s.connection[])
    except:
        s.stop = true
        raise

    try:
        await s.handleSocketMessage()
    except:
        if not getCurrentExceptionMsg()[0].isAlphaNumeric: return
        raise

proc startSession*(discord: DiscordClient,
            autoreconnect = true;
            gateway_intents: set[GatewayIntent] = {
                    giGuilds, giGuildMessages,
                    giDirectMessages, giGuildVoiceStates,
                    giMessageContent
            }; large_message_threshold, large_threshold = 50;
            max_message_size = 5_000_000;
            gateway_version = 10;
            max_shards = none int; shard_id = 0;
            cache_users, cache_guilds, guild_subscriptions = true;
            cache_guild_channels, cache_dm_channels = true) {.async.} =
    ## Connects the client to Discord via gateway.
    ##
    ## - `gateway_intents` Allows you to subscribe to pre-defined events.
    ##    **NOTE:** When not specified this will default to:
    ##    `giGuilds, giGuildMessages, giDirectMessages, giGuildVoiceStates, giMessageContent`
    ##
    ## - `large_threshold` The number that would be considered a large guild (50-250).
    ## - `guild_subscriptions` **DEPRECATED** Whether or not to receive presence_update, typing_start events.
    ## - `autoreconnect` Whether the client should reconnect whenever a network error occurs.
    ## - `max_message_size` Max message JSON size (MESSAGE_CREATE) the client should cache in bytes.
    ## - `large_message_threshold` Max message limit (MESSAGE_CREATE)

    if discord.restMode:
        raise newException(Exception, "(╯°□°)╯ REST mode is enabled! (╯°□°)╯")
    elif discord.token == "Bot  ":
        raise newException(Exception, "The token you specified was empty.")

    discord.autoreconnect = autoreconnect

    # assert gateway_intents.len == 0, "Gateway intents cannot be empty."
    discord.intents = gateway_intents

    if giMessageContent notin discord.intents:
        log("Warning: giMessageContent not specified this might cause issues.")

    discord.largeThreshold = large_threshold
    if guild_subscriptions:
        log("Warning: guild_subscriptions is deprecated.")
        discord.intents = discord.intents + {
            giGuildMessageTyping,
            giDirectMessageTyping,
            giGuildPresences
        }
        discord.guildSubscriptions = true

    discord.max_shards = max_shards.get(-1)
    discord.gatewayVersion = gateway_version
    # when defined(discordv8):
    #     discord.gatewayVersion = 8
    when defined(discordv9):
        discord.gatewayVersion = 9

    log "Dimscord (v" & $libVer & ") - v" & $discord.gatewayVersion

    var
        query = "/?v=" & $discord.gatewayVersion
        info: GatewayBot

    when defined(discordEtf):
        query &= "&encoding=etf"

    # when defined(discordCompress):
    #     query &= "&compress=zlib-stream"

    if discord.shards.len == 0:
        log("Starting gateway session.")

        try:
            info = await discord.api.getGatewayBot()
        except OSError:
            if getCurrentExceptionMsg().startsWith("No such host is known."):
                log("A network error has been detected.")
                return

        log("Successfully retrived gateway information from Discord:" &
            "\n  shards: $1,\n  session_start_limit: $2" % [
            $info.shards,
            $info.session_start_limit
        ])

        if info.session_start_limit.remaining == 10:
            log("WARNING: Your session start limit has reached to 10.")

        if info.session_start_limit.remaining == 0:
            let time = info.session_start_limit.reset_after - getTime().toUnix()
            log("Your session start limit has reached its limit", (
                sleep_time: time
            ))
            await sleepAsync time.int

        if max_shards.isNone:
            discord.max_shards = info.shards

    for id in 0..discord.max_shards - 1:
        var sid = id
        if shard_id != 0:
            invididualShard = true
            sid = shard_id

        let s = discord.setupShard(sid, CacheTablePrefs(
            cache_users: cache_users,
            cache_guilds: cache_guilds,
            cache_guild_channels: cache_guild_channels,
            cache_dm_channels: cache_dm_channels,
            large_message_threshold: large_message_threshold,
            max_message_size: max_message_size
        ))
        s.gatewayUrl = info.url

        if id == discord.max_shards - 1 or invididualShard: # Last shard.
            await s.startSession(s.gatewayUrl, query)
        else:
            asyncCheck s.startSession(s.gatewayUrl, query)

        await s.waitWhenReady()
        if invididualShard: break

proc latency*(s: Shard): int =
    ## Gets the shard's latency ms.
    result = int((s.lastHBReceived - s.lastHBTransmit) * 1000)
