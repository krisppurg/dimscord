import zip/zlib, math, httpclient, websocket, asyncdispatch, json, locks, tables, strutils, times, constants, asyncnet, strformat, options, sequtils, random, objects, cacher

randomize() # I hate that function.
{.hint[XDeclaredButNotUsed]: off.}
{.warning[UnusedImport]: off.} # It says that it's not used, but it actually is used in unexported procedures. 

type
    Events* = ref object ## Event handler object. Exists param checks message is cached or not. Other cachable objects dont have them.
        message_create*: proc (s: Shard, m: Message)
        on_ready*: proc (s: Shard, r: Ready)
        message_delete*: proc (s: Shard, m: Message, exists: bool)
        channel_create*: proc (s: Shard, g: Option[Guild], c: Option[GuildChannel], d: Option[DMChannel])
        channel_update*: proc (s: Shard, g: Guild, c: GuildChannel, o: Option[GuildChannel])
        channel_delete*: proc (s: Shard, g: Option[Guild], c: Option[GuildChannel], d: Option[DMChannel])
        channel_pins_update*: proc (s: Shard, c: string, g: Option[Guild], last_pin: Option[string])
        presence_update*: proc (s: Shard, p: Presence, o: Option[Presence])
        message_update*: proc (s: Shard, m: Message, o: Option[Message], exists: bool)
        message_reaction_add*: proc (s: Shard, m: Message, u: User, r: Reaction, exists: bool)
        message_reaction_remove*: proc (s: Shard, m: Message, u: User, r: Reaction, exists: bool)
        message_reaction_remove_all*: proc (s: Shard, m: Message, exists: bool)
        message_reaction_remove_emoji*: proc (s: Shard, m: Message, e: Emoji, exists: bool)
        message_delete_bulk*: proc (s: Shard, m: seq[tuple[msg: Message, exists: bool]])
        typing_start*: proc (s: Shard, t: TypingStart)
        guild_ban_add*: proc (s: Shard, g: Guild, u: User)
        guild_ban_remove*: proc (s: Shard, g: Guild, u: User)
        guild_emojis_update*: proc (s: Shard, g: Guild, e: seq[Emoji])
        guild_integrations_update*: proc (s: Shard, g: Guild)
        guild_member_add*: proc (s: Shard, g: Guild, m: Member)
        guild_member_update*: proc (s: Shard, g: Guild, m: Member, o: Option[Member])
        guild_member_remove*: proc (s: Shard, g: Guild, m: Member)
        guild_update*: proc (s: Shard, g: Guild, o: Option[Guild])
        guild_create*: proc (s: Shard, g: Guild)
        guild_delete*: proc (s: Shard, g: Guild)
        guild_members_chunk*: proc (s: Shard, g: Guild, m: GuildMembersChunk)
        guild_role_create*: proc (s: Shard, g: Guild, r: Role)
        guild_role_update*: proc (s: Shard, g: Guild, r: Role, o: Option[Role])
        guild_role_delete*: proc (s: Shard, g: Guild, r: Role)
        invite_create*: proc (s: Shard, c: GuildChannel, i: InviteMetadata)
        invite_delete*: proc (s: Shard, c: GuildChannel, code: string, g: Option[Guild])
        user_update*: proc (s: Shard, u: User, o: Option[User])
        voice_state_update*: proc (s: Shard, v: VoiceState, o: Option[VoiceState])
        webhooks_update*: proc (s: Shard, g: Guild, c: GuildChannel)
    DiscordClient* = ref object ## The Discord Client.
        token*: string
        api*: RestApi
        user*: User
        restMode*: bool
        events*: Events
        cache*: CacheTable
        shards*: Table[int, Shard] ## A table of shard indexes
        gateway: tuple[shards: int, url: string]
        shard*: int
        limiter: GatewayLimiter
        intents*: seq[int] ## A sequence of gateway intents
        autoreconnect*: bool
        debug*: bool
    Shard* = ref object
        id*: int
        client*: DiscordClient
        compress*: bool
        heartbeating: bool
        resuming: bool
        reconnecting: bool
        authenticating: bool
        retryInfo: tuple[ms: int, attempts: int]
        networkError: bool
        lastHBTransmit*: float
        lastHBReceived*: float
        hbAck*: bool
        hbSent*: bool
        connection*: AsyncWebsocket
        stop*: bool
        session_id: string
        interval: int
        sequence: int
    GatewayLimiter = ref object
        limit: int
        remaining: int
        interval: int
        reset: int
        processing: bool
        queue: seq[proc (cb: proc ()){.closure.}]
    SessionLimit = object
        total: int
        remaining: int
        reset_after: int
    GatewayInfo = object
        url: string 
        shards: int
        session_start_limit: SessionLimit

var reconnectable = true
var encode = "json"
var gateway: tuple[shards: int, url: string] = (shards: 0, url: "")

proc newGatewayLimiter(limit: int, interval: int): GatewayLimiter =
    result = GatewayLimiter(
        limit: limit,
        remaining: limit,
        interval: interval,
        reset: int(getTime().utc.toTime.toUnix + interval)
    )

proc newDiscordClient*(token: string; rest_mode: bool = false; debug: bool = false;
            cache_users: bool = true; cache_guilds: bool = true;
            cache_guild_channels: bool = true; cache_dm_channels: bool = true): DiscordClient =
    ## Construct a client.
    result = DiscordClient(
        token: token,
        api: newRestApi(token = if token.startsWith("Bot "): token else: "Bot " & token),
        shard: 1,
        restMode: rest_mode,
        debug: debug,
        cache: newCacheTable(cache_users, cache_guilds, cache_guild_channels, cache_dm_channels),
        events: Events(
            message_create: proc (s: Shard, m: Message) = return,
            on_ready: proc (s: Shard, r: Ready) = return,
            message_delete: proc (s: Shard, m: Message, exists: bool) = return,
            channel_create: proc (s: Shard, g: Option[Guild], c: Option[GuildChannel], d: Option[DMChannel]) = return,
            channel_update: proc (s: Shard, g: Guild, c: GuildChannel, o: Option[GuildChannel]) = return,
            channel_delete: proc (s: Shard, g: Option[Guild], c: Option[GuildChannel], d: Option[DMChannel]) = return,
            channel_pins_update: proc (s: Shard, c: string, g: Option[Guild], last_pin: Option[string]) = return,
            presence_update: proc (s: Shard, p: Presence, o: Option[Presence]) = return,
            message_update: proc (s: Shard, m: Message, o: Option[Message], exists: bool) = return,
            message_reaction_add: proc (s: Shard, m: Message, u: User, r: Reaction, exists: bool) = return,
            message_reaction_remove: proc (s: Shard, m: Message, u: User, r: Reaction, exists: bool) = return,
            message_reaction_remove_all: proc (s: Shard, m: Message, exists: bool) = return,
            message_reaction_remove_emoji: proc (s: Shard, m: Message, e: Emoji, exists: bool) = return,
            message_delete_bulk: proc (s: Shard, m: seq[tuple[msg: Message, exists: bool]]) = return,
            typing_start: proc (s: Shard, t: TypingStart) = return,
            guild_ban_add: proc (s: Shard, g: Guild, u: User) = return,
            guild_ban_remove: proc (s: Shard, g: Guild, u: User) = return,
            guild_emojis_update: proc (s: Shard, g: Guild, e: seq[Emoji]) = return,
            guild_integrations_update: proc (s: Shard, g: Guild) = return,
            guild_member_add: proc (s: Shard, g: Guild, m: Member) = return,
            guild_member_update: proc (s: Shard, g: Guild, m: Member, o: Option[Member]) = return,
            guild_member_remove: proc (s: Shard, g: Guild, m: Member) = return,
            guild_update: proc (s: Shard, g: Guild, o: Option[Guild]) = return,
            guild_create: proc (s: Shard, g: Guild) = return,
            guild_delete: proc (s: Shard, g: Guild) = return,
            guild_members_chunk: proc (s: Shard, g: Guild, m: GuildMembersChunk) = return,
            guild_role_create: proc (s: Shard, g: Guild, r: Role) = return,
            guild_role_update: proc (s: Shard, g: Guild, r: Role, o: Option[Role]) = return,
            guild_role_delete: proc (s: Shard, g: Guild, r: Role) = return,
            invite_create: proc (s: Shard, c: GuildChannel, i: InviteMetadata) = return,
            invite_delete: proc (s: Shard, c: GuildChannel, code: string, g: Option[Guild]) = return,
            user_update: proc (s: Shard, u: User, o: Option[User]) = return,
            voice_state_update: proc (s: Shard, v: VoiceState, o: Option[VoiceState]) = return,
            webhooks_update: proc (s: Shard, g: Guild, c: GuildChannel) = return
        ))

proc getShardID*(id: string, shard: int): SomeInteger =
    result = (parseBiggestInt(id) shl 22) mod shard

proc newShard*(id: int, client: DiscordClient): Shard =
    result = Shard(
        id: id,
        client: client,
        retryInfo: (ms: 1000, attempts: 0)
    )

proc getGatewayBot(cl: DiscordClient): Future[GatewayInfo] {.async.} =
    let client = newAsyncHttpClient("DiscordBot (https://github.com/krisppurg/dimscord, v" & libVer & ")")

    client.headers["Authorization"] = if cl.token.startsWith("Bot "): cl.token else: "Bot " & cl.token
    let resp = await client.get(base & "/gateway/bot")

    if int(resp.code) == 200:
        result = (await resp.body).parseJson.to(GatewayInfo)

proc getGateway(): Future[string] {.async.} =
    let client = newAsyncHttpClient("DiscordBot (https://github.com/krisppurg/dimscord, v" & libVer & ")")
    let resp = await client.get(base & "/gateway")

    result = (await resp.body).parseJson()["url"].str

proc debugMsg(cl: DiscordClient, msg: string, info: Option[seq[string]] = none(seq[string])) =
    var finalmsg = msg
    if not cl.debug: return

    finalmsg = &"[Lib]: {msg}"

    if info.isSome:
        finalmsg = &"{finalmsg}:"
        var infoSeq = get(info)
        var index = 0

        for e in infoSeq:
            index += 1

            if (index and 1) != 0:
                finalmsg = finalmsg & (&"\n  {e}: ")
            else:
                finalmsg = finalmsg & e
    echo finalmsg

proc debugMsg(s: Shard, msg: string, mentionWhere: bool = false, info: Option[seq[string]] = none(seq[string])) =
    var finalmsg = msg
    if not s.client.debug: return

    if mentionWhere:
        finalmsg = &"[gateway - SHARD: {s.id}]: {msg}"

    if info.isSome:
        finalmsg = &"{finalmsg}:"
        var infoSeq = get(info)
        var index = 0

        for e in infoSeq:
            index += 1

            if (index and 1) != 0:
                finalmsg = finalmsg & (&"\n  {e}: ")
            else:
                finalmsg = finalmsg & e
    echo finalmsg

proc handleDisconnect(s: Shard, msg: string): bool = # handle disconnect actually prints out sock suspended then returns a bool whether to reconnect.
    let closeData = extractCloseData(msg)

    s.debugMsg("Socket suspended", true, some(@["code", $closeData.code, "reason", $closeData.reason]))

    if s.authenticating: s.authenticating = false
    if s.resuming:
        s.resuming = false

    s.hbAck = false
    s.hbSent = false
    s.retryInfo = (ms: 1000, attempts: 0)
    s.lastHBTransmit = 0
    s.lastHBReceived = 0

    result = true

    var unreconnectableCodes = @[4003, 4004, 4005, 4007, 4010, 4011, 4012, 4013]
    if unreconnectableCodes.contains(closeData.code):
        result = false
        s.client.debugMsg("Unable to reconnect to gateway, because one your options sent to gateway are invalid.")

proc updateStatus*(s: Shard; game: Option[GameStatus] = none(GameStatus); status: string = "online"; afk: bool = false) {.async.} =
    ## Updates the shard's status.
    if s.stop or (s.connection == nil or s.connection.sock.isClosed): return
    var payload = %*{
        "since": 0,
        "afk": afk,
        "status": status
    }

    if game.isSome:
        payload["game"] = %*{}
        payload["game"]["type"] = %* get(game).kind
        payload["game"]["name"] = %* get(game).name

        if get(game).url.isSome:
            payload["game"]["url"] = %* get(get(game).url)

    await s.connection.sendText($(%*{
        "op": opStatusUpdate,
        "d": payload
    }))

proc check(l: GatewayLimiter) {.async.} =
    if l.processing: return
    l.processing = true

    if getTime().utc.toTime.toUnix > l.reset:
        l.remaining = l.limit
        l.reset = int(getTime().utc.toTime.toUnix) + l.interval

    if l.remaining == 0:
        l.remaining = l.limit
        await sleepAsync l.interval

    if l.queue.len > 0:
        l.remaining -= 1

        procCall(l.queue[0](proc () =
            l.processing = false
            l.queue.del(0)
            waitFor l.check()
        ))

proc updateStatus*(cl: DiscordClient; game: Option[GameStatus] = none(GameStatus); status: string = "online"; afk: bool = false) {.async.} =
    ## Updates all the client's shard's status.
    for i in 0..cl.shards.len - 1:
        let s = cl.shards[i]
        await s.updateStatus(game, status, afk)

proc identify(s: Shard) {.async.} =
    if s.authenticating and not s.connection.sock.isClosed: return

    s.client.limiter.queue.add(proc (cb: proc ()) =
        s.authenticating = true

        var payload = %*{
            "token": s.client.token,
            "properties": %*{
                "$os": system.hostOS,
                "$browser": libName,
                "$device": libName
            },
            "compress": s.compress
        }

        if s.client.shard > 1:
            payload["shard"] = %[s.id, s.client.shard]

        if s.client.intents.len > 0:
            var intent = 0

            for itent in s.client.intents:
                intent = intent or itent
            payload["intents"] = %intent

        waitFor s.connection.sendText($(%*{
            "op": opIdentify,
            "d": payload
        }))

        cb())

    await s.client.limiter.check()

proc handleDispatch(s: Shard, event: string, data: JsonNode) {.async.} =
    let cl = s.client
    if cl.debug: echo event

    case event:
        of "READY":
            s.session_id = data["session_id"].str
            s.authenticating = false
            cl.user = newUser(data["user"])

            s.debugMsg("Successfully identified.", true)

            cl.events.on_ready(s, newReady(data))
        of "VOICE_STATE_UPDATE":
            var guild = Guild(id: data["guild_id"].str)
            let voiceState = newVoiceState(data)
            var oldVoiceState: Option[VoiceState] = none(VoiceState)

            if cl.cache.preferences.cache_guilds:
                guild = cl.cache.guilds[guild.id]
                guild.members[voiceState.user_id].voice_state = some(voiceState)

                if guild.voice_states.hasKey(voiceState.user_id):
                    oldVoiceState = some(guild.voice_states[voiceState.user_id])
                    guild.voice_states[voiceState.user_id] = voiceState
                else:
                    guild.voice_states.add(voiceState.user_id, voiceState)

            cl.events.voice_state_update(s, voiceState, oldVoiceState)
        of "CHANNEL_PINS_UPDATE":
            var guild: Option[Guild] = none(Guild)
            var last_pin: Option[string] = none(string)

            if data.hasKey("last_pin_timestamp"):
                last_pin = some(data["last_pin_timestamp"].str)

            if data.hasKey("guild_id"):
                guild = some(Guild(id: data["guild_id"].str))
                if cl.cache.preferences.cache_guilds:
                    guild = some(cl.cache.guilds[data["guild_id"].str])

            cl.events.channel_pins_update(s, data["channel_id"].str, guild, last_pin)
        of "GUILD_EMOJIS_UPDATE":
            var g = Guild(id: data["guild_id"].str)

            if cl.cache.preferences.cache_guilds:
                g = cl.cache.guilds[g.id]

            var emojis: seq[Emoji] = @[]
            for emji in data["emojis"]:
                emojis.add(newEmoji(emji))
                g.emojis.add(emji["id"].str, newEmoji(emji))

            cl.events.guild_emojis_update(s, g, emojis)
        of "USER_UPDATE":
            let user = newUser(data)
            var oldUser: Option[User] = none(User)
            cl.user = user

            cl.events.user_update(s, user, oldUser)
        of "PRESENCE_UPDATE":
            var oldPresence: Option[Presence] = none(Presence)
            var presence = newPresence(data)
            if cl.cache.preferences.cache_guilds:
                let guild = cl.cache.guilds[presence.guild_id]

                if guild.presences.hasKey(presence.user.id):
                    oldPresence = some(guild.presences[presence.user.id])

                var member = guild.members[presence.user.id]

                if (presence.user.username != "" and presence.user.username != member.user.username) or (presence.user.discriminator != "" and presence.user.discriminator != member.user.discriminator) or (presence.user.avatar.isSome and get(presence.user.avatar) != get(member.user.avatar)):
                        if presence.user.username != "": member.user.username = presence.user.username
                        if presence.user.discriminator != "": member.user.discriminator = presence.user.discriminator
                        if presence.user.avatar.isSome: member.user.avatar = presence.user.avatar

                if presence.status == "offline":
                    guild.presences.del(presence.user.id)
                elif @["offline", ""].contains(member.presence.status) and presence.status != "offline":
                    guild.presences.add(presence.user.id, presence)

                if guild.presences.hasKey(presence.user.id):
                    guild.presences[presence.user.id] = presence

                member.presence = presence

            cl.events.presence_update(s, presence, oldPresence)
        of "MESSAGE_CREATE":
            let msg = newMessage(data)

            if cl.cache.preferences.cache_guild_channels or cl.cache.preferences.cache_dm_channels:
                if cl.cache.kind(msg.channel_id) != ctDirect:
                    if cl.cache.preferences.cache_guild_channels:
                        let chan = cl.cache.guildChannels[msg.channel_id]

                        chan.messages.add(msg.id, msg)
                        chan.last_message_id = msg.id
                else:
                    if cl.cache.preferences.cache_dm_channels:
                        let chan = cl.cache.dmChannels[msg.channel_id]

                        chan.messages.add(msg.id, msg)
                        chan.last_message_id = msg.id

            cl.events.message_create(s, msg)
        of "MESSAGE_REACTION_ADD":
            var msg = Message(id: data["message_id"].str, channel_id: data["channel_id"].str)
            var emoji = newEmoji(data["emoji"])
            var user = User(id: data["user_id"].str)
            var reaction = Reaction(emoji: emoji)
            var exists = false

            if cl.cache.preferences.cache_users:
                user = cl.cache.users[user.id]

            if cl.cache.preferences.cache_guild_channels or cl.cache.preferences.cache_dm_channels:
                if cl.cache.kind(msg.channel_id) != ctDirect:
                    if cl.cache.preferences.cache_guild_channels:
                        let chan = cl.cache.guildChannels[msg.channel_id]

                        if chan.messages.hasKey(msg.id):
                            msg = chan.messages[msg.id]
                            exists = true
                else:
                    if cl.cache.preferences.cache_dm_channels:
                        let chan = cl.cache.dmChannels[msg.channel_id]

                        if chan.messages.hasKey(msg.id):
                            msg = chan.messages[msg.id]
                            exists = true

            if data.hasKey("guild_id"):
                msg.guild_id = data["guild_id"].str
                msg.member = newMember(data["member"])

            if msg.reactions.hasKey($emoji):
                reaction.count = msg.reactions[$emoji].count + 1

                if data["user_id"].str == cl.user.id:
                    reaction.reacted = true

                msg.reactions[$emoji] = reaction
            else:
                reaction.count += 1
                reaction.reacted = data["user_id"].str == cl.user.id
                msg.reactions.add($emoji, reaction)

            cl.events.message_reaction_add(s, msg, user, reaction, exists)
        of "MESSAGE_REACTION_REMOVE":
            var msg = Message(id: data["message_id"].str, channel_id: data["channel_id"].str)
            var emoji = newEmoji(data["emoji"])
            var user = User(id: data["user_id"].str)
            var reaction = Reaction(emoji: emoji)
            var exists = false

            if cl.cache.preferences.cache_users:
                user = cl.cache.users[user.id]

            if cl.cache.preferences.cache_guild_channels or cl.cache.preferences.cache_dm_channels:
                if cl.cache.kind(msg.channel_id) != ctDirect:
                    if cl.cache.preferences.cache_guild_channels:
                        let chan = cl.cache.guildChannels[msg.channel_id]

                        if chan.messages.hasKey(msg.id):
                            msg = chan.messages[msg.id]
                            exists = true
                else:
                    if cl.cache.preferences.cache_dm_channels:
                        let chan = cl.cache.dmChannels[msg.channel_id]

                        if chan.messages.hasKey(msg.id):
                            msg = chan.messages[msg.id]
                            exists = true

            if data.hasKey("guild_id"):
                msg.guild_id = data["guild_id"].str

            if msg.reactions.hasKey($emoji) and msg.reactions[$emoji].count != 1:
                reaction.count = msg.reactions[$emoji].count - 1

                if data["user_id"].str == cl.user.id:
                    reaction.reacted = false

                msg.reactions[$emoji] = reaction
            else:
                msg.reactions.del($emoji)

            cl.events.message_reaction_remove(s, msg, user, reaction, exists)
        of "MESSAGE_REACTION_REMOVE_EMOJI":
            var msg = Message(id: data["message_id"].str, channel_id: data["channel_id"].str)
            var emoji = newEmoji(data["emoji"])
            var exists = false

            if cl.cache.preferences.cache_guild_channels or cl.cache.preferences.cache_dm_channels:
                if cl.cache.kind(msg.channel_id) != ctDirect:
                    if cl.cache.preferences.cache_guild_channels:
                        let chan = cl.cache.guildChannels[msg.channel_id]

                        if chan.messages.hasKey(msg.id):
                            msg = chan.messages[msg.id]
                            exists = true
                else:
                    if cl.cache.preferences.cache_dm_channels:
                        let chan = cl.cache.dmChannels[msg.channel_id]

                        if chan.messages.hasKey(msg.id):
                            msg = chan.messages[msg.id]
                            exists = true

            if data.hasKey("guild_id"):
                msg.guild_id = data["guild_id"].str

            if msg.reactions.hasKey($emoji):
                msg.reactions.del($emoji)

            cl.events.message_reaction_remove_emoji(s, msg, emoji, exists)
        of "MESSAGE_REACTION_REMOVE_ALL":
            var msg = Message(id: data["message_id"].str, channel_id: data["channel_id"].str)
            var exists = false

            if cl.cache.preferences.cache_guild_channels or cl.cache.preferences.cache_dm_channels:
                if cl.cache.kind(msg.channel_id) != ctDirect:
                    if cl.cache.preferences.cache_guild_channels:
                        let chan = cl.cache.guildChannels[msg.channel_id]

                        if chan.messages.hasKey(msg.id):
                            msg = chan.messages[msg.id]
                            exists = true
                else:
                    if cl.cache.preferences.cache_dm_channels:
                        let chan = cl.cache.dmChannels[msg.channel_id]

                        if chan.messages.hasKey(msg.id):
                            msg = chan.messages[msg.id]
                            exists = true

            if data.hasKey("guild_id"):
                msg.guild_id = data["guild_id"].str

            if msg.reactions.len > 0:
                msg.reactions.clear()

            cl.events.message_reaction_remove_all(s, msg, exists)
        of "MESSAGE_DELETE":
            var msg = Message(id: data["id"].str, channel_id: data["channel_id"].str)
            var exists = false

            if data.hasKey("guild_id"):
                msg.guild_id = data["guild_id"].str

            if cl.cache.preferences.cache_guild_channels or cl.cache.preferences.cache_dm_channels:
                if not cl.cache.dmChannels.hasKey(msg.channel_id):
                    return
                if cl.cache.kind(msg.channel_id) != ctDirect:
                    if cl.cache.preferences.cache_guild_channels:
                        let chan = cl.cache.guildChannels[msg.channel_id]

                        if chan.messages.hasKey(msg.id):
                            msg = chan.messages[msg.id]
                            chan.messages.del(msg.id)
                            exists = true
                else:
                    if cl.cache.preferences.cache_dm_channels:
                        let chan = cl.cache.dmChannels[msg.channel_id]

                        if chan.messages.hasKey(msg.id):
                            msg = chan.messages[msg.id]
                            chan.messages.del(msg.id)
                            exists = true

            cl.events.message_delete(s, msg, exists)
        of "MESSAGE_UPDATE":
            var msg = Message(id: data["id"].str, channel_id: data["channel_id"].str)
            var oldMessage: Option[Message] = none(Message)
            var exists = false

            if cl.cache.preferences.cache_guild_channels or cl.cache.preferences.cache_dm_channels:
                if not cl.cache.dmChannels.hasKey(msg.channel_id):
                    return
                if cl.cache.kind(msg.channel_id) != ctDirect:
                    if cl.cache.preferences.cache_guild_channels:
                        let chan = cl.cache.guildChannels[msg.channel_id]

                        if chan.messages.hasKey(msg.id):
                            oldMessage = some(chan.messages[msg.id])
                            chan.messages[msg.id] = chan.messages[msg.id].update(data)
                            msg = chan.messages[msg.id]
                else:
                    if cl.cache.preferences.cache_dm_channels:
                        let chan = cl.cache.dmChannels[msg.channel_id]

                        if chan.messages.hasKey(msg.id):
                            oldMessage = some(chan.messages[msg.id])
                            chan.messages[msg.id] = chan.messages[msg.id].update(data)
                            msg = chan.messages[msg.id]
            else:
                msg = msg.update(data)

            cl.events.message_update(s, msg, oldMessage, exists)
        of "MESSAGE_DELETE_BULK":
            var ids: seq[tuple[msg: Message, exists: bool]] = @[]

            for msg in data["ids"].elems:
                var exists = false
                var m = Message(id: msg.str, channel_id: data["channel_id"].str)

                if cl.cache.preferences.cache_guild_channels or cl.cache.preferences.cache_dm_channels:
                    if cl.cache.kind(m.channel_id) != ctDirect:
                        if cl.cache.preferences.cache_guild_channels:
                            let chan = cl.cache.guildChannels[m.channel_id]

                            if chan.messages.hasKey(m.id):
                                m = chan.messages[m.id]
                                chan.messages.del(m.id)
                                exists = true
                    else:
                        if cl.cache.preferences.cache_dm_channels:
                            let chan = cl.cache.dmChannels[m.channel_id]
                            if chan.messages.hasKey(m.id):
                                m = chan.messages[m.id]
                                chan.messages.del(m.id)
                                exists = true

                if data.hasKey("guild_id"):
                    m.guild_id = data["guild_id"].str
                ids.add((msg: m, exists: exists))

            cl.events.message_delete_bulk(s, ids)
        of "CHANNEL_CREATE":
            var guild: Option[Guild] = none(Guild)
            var chan: Option[GuildChannel] = none(GuildChannel)
            var dmChan: Option[DMChannel] = none(DMChannel)

            if data["type"].getInt() != ctDirect:
                guild = some(Guild(id: data["guild_id"].str))

                if cl.cache.preferences.cache_guilds:
                    guild = some(cl.cache.guilds[get(guild).id])

                chan = some(newGuildChannel(data))

                if cl.cache.preferences.cache_guild_channels:
                    cl.cache.guildChannels.add(get(chan).id, get(chan))
            elif data["type"].getInt() == ctDirect and not cl.cache.dmChannels.hasKey(data["id"].str):
                dmChan = some(newDMChannel(data))
                cl.cache.dmChannels.add(data["id"].str, get(dmChan))

            cl.events.channel_create(s, guild, chan, dmChan)
        of "CHANNEL_UPDATE":
            var gchan = newGuildChannel(data)
            var oldChan: Option[GuildChannel] = none(GuildChannel) 

            var guild = Guild(id: data["guild_id"].str)

            if cl.cache.preferences.cache_guilds:
                guild = cl.cache.guilds[guild.id]
                oldChan = some(guild.channels[gchan.id])

                if cl.cache.preferences.cache_guild_channels:
                    cl.cache.guildChannels[gchan.id] = gchan
            cl.events.channel_update(s, guild, gchan, oldChan)
        of "CHANNEL_DELETE":
            var guild: Option[Guild] = none(Guild)
            var gc: Option[GuildChannel] = none(GuildChannel)
            var dm: Option[DMChannel] = none(DMChannel)

            if data.hasKey("guild_id"):
                guild = some(Guild(id: data["guild_id"].str))
                if cl.cache.preferences.cache_guilds:
                    guild = some(cl.cache.guilds[get(guild).id])

            if cl.cache.preferences.cache_guild_channels or cl.cache.preferences.cache_dm_channels:
                if cl.cache.kind(data["id"].str) != ctDirect:
                    if cl.cache.preferences.cache_guild_channels:
                        gc = some(newGuildChannel(data))
                        cl.cache.guildChannels.del(get(gc).id)
                else:
                    if cl.cache.preferences.cache_dm_channels:
                        dm = some(newDMChannel(data))
                        cl.cache.dmChannels.del(get(dm).id)

            cl.events.channel_delete(s, guild, gc, dm)
        of "GUILD_MEMBER_ADD":
            var guild = Guild(id: data["guild_id"].str)
            let member = newMember(data)

            if cl.cache.preferences.cache_guilds:
                guild = cl.cache.guilds[guild.id]
                guild.members.add(member.user.id, member)
                guild.member_count = some(get(guild.member_count) + 1)
                if cl.cache.preferences.cache_users:
                    cl.cache.users.add(member.user.id, member.user)

            cl.events.guild_member_add(s, guild, member)
        of "GUILD_MEMBER_UPDATE":
            var guild = Guild(id: data["guild_id"].str)
            var member = Member()
            var oldMember: Option[Member] = none(Member)

            if cl.cache.preferences.cache_guilds:
                guild = cl.cache.guilds[guild.id]
                member = guild.members[data["user"]["id"].str]
                oldMember = some(member)

            member.user = newUser(data["user"])
            cl.cache.users[member.user.id] = member.user

            if data.hasKey("nick") and data["nick"].kind != JNull:
                member.nick = data["nick"].str

            if data.hasKey("premium_since") and data["premium_since"].kind != JNull:
                member.premium_since = data["premium_since"].str

            for role in data["roles"].elems:
                member.roles.add(role.str)

            cl.events.guild_member_update(s, guild, member, oldMember)
        of "GUILD_MEMBER_REMOVE":
            var guild = Guild(id: data["guild_id"].str)
            var member = Member(user: newUser(data))

            if cl.cache.preferences.cache_guilds:
                guild = cl.cache.guilds[guild.id]
                member = guild.members[member.user.id]

                guild.members.del(member.user.id)
                guild.member_count = some(get(guild.member_count) - 1)
    
                if cl.cache.preferences.cache_users:
                    cl.cache.users.del(member.user.id)

            cl.events.guild_member_remove(s, guild, member)
        of "GUILD_BAN_ADD":
            var guild = Guild(id: data["guild_id"].str)
            let user = newUser(data["user"])
            if cl.cache.preferences.cache_guilds:
                guild = cl.cache.guilds[guild.id]
            
            cl.events.guild_ban_add(s, guild, user)
        of "GUILD_BAN_REMOVE":
            var guild = Guild(id: data["guild_id"].str)
            let user = newUser(data["user"])
            if cl.cache.preferences.cache_guilds:
                guild = cl.cache.guilds[guild.id]
            
            cl.events.guild_ban_add(s, guild, user)
        of "GUILD_UPDATE":
            let guild = newGuild(data)
            var oldGuild: Option[Guild] = none(Guild)
            if cl.cache.preferences.cache_guilds:
                oldGuild = some(cl.cache.guilds[guild.id])
                cl.cache.guilds[guild.id] = guild
            
            cl.events.guild_update(s, guild, oldGuild)
        of "GUILD_DELETE":
            var guild = Guild(id: data["id"].str)
            var oldGuild: Option[Guild] = none(Guild)

            if cl.cache.preferences.cache_guilds:
                cl.cache.guilds[guild.id].unavailable = some((if data.hasKey("unavailable"): data["unavailable"].bval else: false))
                guild = cl.cache.guilds[guild.id]
                cl.cache.guilds.del(guild.id)

            cl.events.guild_delete(s, guild)
        of "GUILD_ROLE_CREATE":
            var guild = Guild(id: data["guild_id"].str)
            let role = newRole(data)

            if cl.cache.preferences.cache_guilds:
                guild = cl.cache.guilds[guild.id]
                guild.roles.add(role.id, role)

            cl.events.guild_role_create(s, guild, role)
        of "GUILD_ROLE_UPDATE":
            var guild = Guild(id: data["guild_id"].str)
            let role = newRole(data["role"])
            var oldRole: Option[Role] = none(Role)

            if cl.cache.preferences.cache_guilds:
                guild = cl.cache.guilds[guild.id]
                oldRole = some(guild.roles[role.id])

                guild.roles[role.id] = role

            cl.events.guild_role_update(s, guild, role, oldRole)
        of "GUILD_ROLE_DELETE":
            var guild = Guild(id: data["guild_id"].str)
            var role = Role(id: data["role_id"].str)

            if cl.cache.preferences.cache_guilds:
                guild = cl.cache.guilds[guild.id]
                role = guild.roles[role.id]

            cl.events.guild_role_delete(s, guild, role)
        of "RESUMED":
            s.resuming = false
            s.authenticating = false
            s.debugMsg("Successfuly resumed.", true)
        of "GUILD_CREATE": # TODO: finish
            s.debugMsg("Recieved GUILD_CREATE event", true, some(@["id", data["id"].str]))

            if data["channels"].elems.len > 0:
                for chan in data["channels"].elems:
                    if cl.cache.preferences.cache_guild_channels:
                        cl.cache.guildChannels.add(chan["id"].str, newGuildChannel(chan))

            if cl.cache.preferences.cache_users:
                if data["members"].elems.len > 0:
                    for m in data["members"].elems:
                        cl.cache.users.add(m["user"]["id"].str, newUser(m["user"]))
            if cl.cache.preferences.cache_guilds:
                let guild = newGuild(data)
                cl.cache.guilds.add(guild.id, guild)
        else:
            discard
            # asyncCheck cl.emitHandler(unknown_event, (data: data))

proc resume(s: Shard) {.async.} =
    if s.authenticating: return
    if s.connection.sock.isClosed: return

    s.authenticating = true
    s.resuming = true

    s.debugMsg("Attempting to resume", true, some(@["session_id", s.session_id, "events", $s.sequence]))
    await s.connection.sendText($(%*{
        "op": opResume,
        "d": %*{
            "token": s.client.token,
            "session_id": s.session_id,
            "seq": s.sequence
        }
    }))

proc handleConnection(cl: DiscordClient): Future[tuple[shards: int, url: string]] {.async.} =
    cl.debugMsg("Connecting to the discord gateway.")
    var info: GatewayInfo

    try:
        info = await cl.getGatewayBot()
    except OSError:
        if getCurrentExceptionMsg().startsWith("No such host is known."):
            cl.debugMsg("A network error has been detected.")

    cl.debugMsg("Successfully retrived gateway information from Discord", some(@[
        "url", info.url,
        "shards", $info.shards,
        "session_start_limit", $info.session_start_limit
    ]))

    if info.session_start_limit.remaining == 0:
        let time = getTime().utc.toTime.toUnix - info.session_start_limit.reset_after

        cl.debugMsg("Your session start limit has reached its limit", some(@[
            "sleep_time", $time
        ]))
        await sleepAsync time.int
    
    result = (info.shards, info.url)

proc reconnect*(s: Shard; resumable: bool = false) {.async.} =
    if s.reconnecting: return
    s.reconnecting = true
    s.retryInfo.attempts += 1

    var url: string = ""

    try: 
        url = await getGateway()
    except:
        s.debugMsg("Error occurred:: \n" & getCurrentExceptionMsg())
        s.reconnecting = false

        s.retryInfo.ms = min(s.retryInfo.ms + max(rand(6000), 3000), 30000)

        s.debugMsg(&"Reconnecting in {s.retryInfo.ms}ms", true, some(@["attempt", $s.retryInfo.attempts]))

        await sleepAsync s.retryInfo.ms
        await s.reconnect(resumable = resumable)

    s.debugMsg("Connecting to " & (if url.startsWith("wss://"): url[6..url.high] else: url) & "/?v=" & $gatewayVer & "&encoding=" & encode)

    try:
        s.connection = await newAsyncWebsocketClient(
            if url.startsWith("wss://"): url[6..url.high] else: url,
            Port 443,
            "/?v=" & $gatewayVer & "&encoding=" & encode,
            true
        )
        s.hbAck = true
        s.stop = false
        s.reconnecting = false

        if s.networkError:
            s.debugMsg("Successfully established a gateway connection after network error.")
            s.retryInfo = (ms: 1000, attempts: 0)
            s.networkError = false
    except:
        s.debugMsg("Error occurred: \n" & getCurrentExceptionMsg())
        s.reconnecting = false

        s.retryInfo.ms = min(s.retryInfo.ms + max(rand(6000), 3000), 30000)

        s.debugMsg(&"Reconnecting in {s.retryInfo.ms}ms", true, some(@["attempt", $s.retryInfo.attempts]))

        await sleepAsync s.retryInfo.ms
        await s.reconnect(resumable = resumable)

    if not resumable or s.session_id == "":
        s.sequence = 0
        s.session_id = ""

        await s.identify()
    else:
        await s.resume()

proc disconnect*(s: Shard, code: int = 4000, shouldReconnect: bool = true) {.async.} =
    if s.stop: return
    s.stop = true

    if s.connection != nil or not s.connection.sock.isClosed:
        s.debugMsg("Sending close code: " & $code & " to disconnect")
        await s.connection.close(code)

    if s.client.autoreconnect or shouldReconnect: await s.reconnect(resumable = true)

proc heartbeat(s: Shard) {.async.} =
    if not s.hbAck and s.session_id != "":
        s.debugMsg("Last heartbeat was not acknowledged by Discord, possibly zombied connection.", true)
        await s.disconnect()
        return

    s.debugMsg("Sending heartbeat.", true)
    s.hbAck = false

    await s.connection.sendText($(%*{
        "op": 1,
        "d": s.sequence
    }))
    s.lastHBTransmit = epochTime() * 1000
    s.hbSent = true

proc setupHeartbeatInterval(s: Shard) {.async.} =
    if not s.heartbeating: return

    while not s.stop and not s.connection.sock.isClosed:
        await s.heartbeat()
        await sleepAsync s.interval

proc handleSocketMessage*(s: Shard) {.async.} =
    waitFor s.identify()

    var packet: tuple[opcode: Opcode, data: string]
    var shouldReconnect = true

    while not s.connection.sock.isClosed and not s.stop:
        try:
            packet = await s.connection.readData()
        except:
            var exception = getCurrentExceptionMsg()
            echo "Error while reading websocket data ::\n", getCurrentExceptionMsg()
            if not s.stop: s.stop = true
            if s.heartbeating: s.heartbeating = false

            if exception.startsWith("The semaphore timeout period has expired."):
                s.debugMsg("A network error has been detected.", true)

                s.networkError = true
            elif exception.startsWith("socket closed"):
                s.debugMsg("Received 'socket closed'.\n\nGetting time since last heartbeat recieved from discord.")

                if (epochTime() * 1000 - s.lastHBReceived) > 60000 or exception.startsWith("The network connection was aborted by the local system."): # this is my clever way of detecting a sleep
                    echo "It appears that the library has detected that you put your computer to sleep.\n\n    - Unfortunately, this error is fatal resulting in some errors."
                    shouldReconnect = false
                break

        var data: JsonNode

        if s.compress and packet.opcode == Opcode.Binary:
            packet.data = zlib.uncompress(packet.data)

        try:
            data = parseJson(packet.data)
        except:
            echo "An error occurred while parsing data: " & packet.data
            shouldReconnect = s.handleDisconnect(packet.data)

            await s.disconnect(shouldReconnect = shouldReconnect)
            await s.handleSocketMessage()

        if data["s"].kind != JNull and not s.resuming:
            s.sequence = data["s"].getInt()

        case data["op"].num
            of opHello:
                s.debugMsg("Received 'HELLO' from the gateway.", true)
                s.interval = data["d"]["heartbeat_interval"].getInt()

                if not s.heartbeating:
                    s.heartbeating = true
                    asyncCheck s.setupHeartbeatInterval()
            of opHeartbeatAck:
                s.lastHBReceived = epochTime() * 1000
                s.hbSent = false
                s.debugMsg("Heartbeat Acknowledged by Discord.", true)

                s.hbAck = true
            of opHeartbeat:
                s.debugMsg("Discord has requested a heartbeat.")
                await s.heartbeat()
            of opDispatch:
                asyncCheck s.handleDispatch(data["t"].str, data["d"])
            of opReconnect:
                s.debugMsg("Discord is requesting for a client reconnect.")
                await s.disconnect(shouldReconnect = shouldReconnect)
            of opInvalidSession:
                s.resuming = false
                s.authenticating = false

                s.debugMsg("Received 'INVALID_SESSION'", true, some(@["resumable", $data["d"].getBool()]))

                if data["d"].getBool():
                    await s.resume()
                else:
                    s.debugMsg("Sending the IDENTIFY packet in 5000ms.", true)

                    await sleepAsync 5000
                    s.client.limiter = newGatewayLimiter(limit = 1, interval = 5500)
                    await s.identify()
            else:
                discard
    if packet.opcode == Close:
        if not shouldReconnect:
            shouldReconnect = s.handleDisconnect(packet.data)
        else:
            reconnectable = false

    s.stop = true
    s.resuming = false
    s.authenticating = false
    s.hbAck = false
    s.hbSent = false
    s.lastHBReceived = 0
    s.lastHBTransmit = 0

    if shouldReconnect:
        await s.reconnect(resumable = true)
        if not s.networkError: await handleSocketMessage(s)
    else:
        reconnectable = false

proc handleSocketMessageExceptions(s: Shard) {.async.} =
    try:
        await handleSocketMessage(s)
    except:
        if not reconnectable or getCurrentExceptionMsg()[0].isAlphaNumeric: return

        await s.connection.close()
        echo "An error occurred while handling socket messages :: " & getCurrentExceptionMsg()

        if s.resuming: s.resuming = false
        if s.authenticating: s.authenticating = false

        await s.reconnect(resumable = true)
        await handleSocketMessageExceptions(s)

proc startSession(s: Shard, url: string, query: string) {.async.} =
    try:
        s.connection = await newAsyncWebsocketClient(
                url[6..url.high],
                Port 443,
                query,
                true
            )
        s.hbAck = true
        s.debugMsg("Socket is open.")
    except:
        echo getCurrentExceptionMsg()
        s.stop = true
        return

    await s.handleSocketMessageExceptions() # hope dis works *sweats*

proc startSession*(cl: DiscordClient,
            autoreconnect: bool = false;
            gateway_intents: seq[int] = @[];
            shards: int = 1;
            compress: bool = false;
            encoding: string = "json") {.async.} =
    ## Connects the client to Discord via gateway.
    ## 
    ## - gateway_intents | Allows you to subscribe to pre-defined events (info: https://discordapp.com/developers/docs/topics/gateway#gateway-intents)
    ## - shards | An amount of shards.
    ## - encoding | Sets gateway encoding.
    ## - compress | Whether or not to compress. zlib1.dll needs to be in your directory.

    if cl.restMode:
        raise newException(Exception, "(╯°□°)╯︵ ┻━┻ ! You cannot connect to the gateway while rest mode is enabled ! (╯°□°)╯︵ ┻━┻")

    cl.autoreconnect = autoreconnect
    encode = encoding
    cl.intents = gateway_intents
    cl.shard = shards

    cl.limiter = newGatewayLimiter(limit = 1, interval = 5500)

    var query = "/?v=" & $gatewayVer & "&encoding=" & encoding
    # if compress:
    #     query = query & "&compress=zlib-stream"

    if gateway.url == "":
        gateway = await cl.handleConnection()

    if shards == 1 and gateway.shards > 1:
        cl.shard = gateway.shards

    if shards > 1:
        for i in 0..cl.shard - 2:
            let ss = newShard(i, cl)
            cl.shards.add(i, ss)
            ss.compress = compress
            asyncCheck ss.startSession(gateway.url, query)

    let ss = newShard(cl.shard - 1, cl)
    cl.shards.add(cl.shard - 1, ss)
    ss.compress = compress
    waitFor ss.startSession(gateway.url, query)

proc getPing*(s: Shard): int =
    ## Gets the shard's ping ms.
    result = (s.lastHBReceived - s.lastHBTransmit).int