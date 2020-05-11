import zip/zlib, math, httpclient, websocket, asyncdispatch, json, locks, tables, strutils, times, constants, asyncnet, strformat, options, sequtils, random, objects, cacher

randomize()
{.hint[XDeclaredButNotUsed]: off.}
{.warning[UnusedImport]: off.} # It says that it's not used, but it actually is used in unexported procedures. 

type
    Events* = ref object
        ## An Events object.
        ## `exists` param checks message is cached or not. Other cachable objects dont have them.
        message_create*: proc (s: Shard, m: Message) {.async.}
        on_ready*: proc (s: Shard, r: Ready) {.async.}
        message_delete*: proc (s: Shard, m: Message, exists: bool) {.async.}
        channel_create*: proc (s: Shard, g: Option[Guild], c: Option[GuildChannel], d: Option[DMChannel]) {.async.}
        channel_update*: proc (s: Shard, g: Guild, c: GuildChannel, o: Option[GuildChannel]) {.async.}
        channel_delete*: proc (s: Shard, g: Option[Guild], c: Option[GuildChannel], d: Option[DMChannel]) {.async.}
        channel_pins_update*: proc (s: Shard, c: string, g: Option[Guild], last_pin: Option[string]) {.async.}
        presence_update*: proc (s: Shard, p: Presence, o: Option[Presence]) {.async.}
        message_update*: proc (s: Shard, m: Message, o: Option[Message], exists: bool) {.async.}
        message_reaction_add*, message_reaction_remove*: proc (s: Shard, m: Message, u: User, r: Reaction, exists: bool) {.async.}
        message_reaction_remove_all*: proc (s: Shard, m: Message, exists: bool) {.async.}
        message_reaction_remove_emoji*: proc (s: Shard, m: Message, e: Emoji, exists: bool) {.async.}
        message_delete_bulk*: proc (s: Shard, m: seq[tuple[msg: Message, exists: bool]]) {.async.}
        typing_start*: proc (s: Shard, t: TypingStart) {.async.}
        guild_ban_add*, guild_ban_remove*: proc (s: Shard, g: Guild, u: User) {.async.}
        guild_emojis_update*: proc (s: Shard, g: Guild, e: seq[Emoji]) {.async.}
        guild_integrations_update*: proc (s: Shard, g: Guild) {.async.}
        guild_member_add*, guild_member_remove*: proc (s: Shard, g: Guild, m: Member) {.async.}
        guild_member_update*: proc (s: Shard, g: Guild, m: Member, o: Option[Member]) {.async.}
        guild_update*: proc (s: Shard, g: Guild, o: Option[Guild]) {.async.}
        guild_create*, guild_delete*: proc (s: Shard, g: Guild) {.async.}
        guild_members_chunk*: proc (s: Shard, g: Guild, m: GuildMembersChunk) {.async.}
        guild_role_create*, guild_role_delete*: proc (s: Shard, g: Guild, r: Role) {.async.}
        guild_role_update*: proc (s: Shard, g: Guild, r: Role, o: Option[Role]) {.async.}
        invite_create*: proc (s: Shard, c: GuildChannel, i: InviteMetadata) {.async.}
        invite_delete*: proc (s: Shard, c: GuildChannel, code: string, g: Option[Guild]) {.async.}
        user_update*: proc (s: Shard, u: User, o: Option[User]) {.async.}
        voice_state_update*: proc (s: Shard, v: VoiceState, o: Option[VoiceState]) {.async.}
        webhooks_update*: proc (s: Shard, g: Guild, c: GuildChannel) {.async.}
    DiscordClient* = ref object
        ## The Discord Client, itself.
        api*: RestApi
        user*: User
        events*: Events
        token*: string
        shards*: Table[int, Shard]
        restMode*, autoreconnect*, guildSubscriptions*: bool
        largeThresold*, shard*: int
        cache*: CacheTable
        intents*: set[GatewayIntent]
    Shard* = ref object
        id*, sequence*: int
        client*: DiscordClient
        connection*: AsyncWebsocket
        hbAck*, hbSent*, stop*, compress*: bool
        lastHBTransmit*, lastHBReceived*: float
        retry_info*: tuple[ms, attempts: int]
        session_id*: string
        heartbeating, resuming, reconnecting: bool
        authenticating, networkError: bool
        interval: int
    GatewaySession = object
        total, remaining, reset_after: int
    GatewayBot = object
        url: string 
        shards: int
        session_start_limit: GatewaySession
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

var reconnectable = true
var gateway: tuple[shards: int, url: string]
var lastReady = 0.0

proc newDiscordClient*(token: string; rest_mode = false; rest_ver = 7;
            cache_users = true; cache_guilds = true;
            cache_guild_channels = true; cache_dm_channels = true): DiscordClient =
    ## Construct a client.
    result = DiscordClient(
        token: token,
        api: newRestApi(token = if token.startsWith("Bot "): token else: "Bot " & token, rest_ver = rest_ver),
        shard: 1,
        restMode: rest_mode,
        cache: newCacheTable(cache_users, cache_guilds, cache_guild_channels, cache_dm_channels),
        events: Events(
            message_create: proc (s: Shard, m: Message) {.async.} = discard,
            on_ready: proc (s: Shard, r: Ready) {.async.} = discard,
            message_delete: proc (s: Shard, m: Message, exists: bool) {.async.} = discard,
            channel_create: proc (s: Shard, g: Option[Guild], c: Option[GuildChannel], d: Option[DMChannel]) {.async.} = discard,
            channel_update: proc (s: Shard, g: Guild, c: GuildChannel, o: Option[GuildChannel]) {.async.} = discard,
            channel_delete: proc (s: Shard, g: Option[Guild], c: Option[GuildChannel], d: Option[DMChannel]) {.async.} = discard,
            channel_pins_update: proc (s: Shard, c: string, g: Option[Guild], last_pin: Option[string]) {.async.} = discard,
            presence_update: proc (s: Shard, p: Presence, o: Option[Presence]) {.async.} = discard,
            message_update: proc (s: Shard, m: Message, o: Option[Message], exists: bool) {.async.} = discard,
            message_reaction_add: proc (s: Shard, m: Message, u: User, r: Reaction, exists: bool) {.async.} = discard,
            message_reaction_remove: proc (s: Shard, m: Message, u: User, r: Reaction, exists: bool) {.async.} = discard,
            message_reaction_remove_all: proc (s: Shard, m: Message, exists: bool) {.async.} = discard,
            message_reaction_remove_emoji: proc (s: Shard, m: Message, e: Emoji, exists: bool) {.async.} = discard,
            message_delete_bulk: proc (s: Shard, m: seq[tuple[msg: Message, exists: bool]]) {.async.} = discard,
            typing_start: proc (s: Shard, t: TypingStart) {.async.} = discard,
            guild_ban_add: proc (s: Shard, g: Guild, u: User) {.async.} = discard,
            guild_ban_remove: proc (s: Shard, g: Guild, u: User) {.async.} = discard,
            guild_emojis_update: proc (s: Shard, g: Guild, e: seq[Emoji]) {.async.} = discard,
            guild_integrations_update: proc (s: Shard, g: Guild) {.async.} = discard,
            guild_member_add: proc (s: Shard, g: Guild, m: Member) {.async.} = discard,
            guild_member_update: proc (s: Shard, g: Guild, m: Member, o: Option[Member]) {.async.} = discard,
            guild_member_remove: proc (s: Shard, g: Guild, m: Member) {.async.} = discard,
            guild_update: proc (s: Shard, g: Guild, o: Option[Guild]) {.async.} = discard,
            guild_create: proc (s: Shard, g: Guild) {.async.} = discard,
            guild_delete: proc (s: Shard, g: Guild) {.async.} = discard,
            guild_members_chunk: proc (s: Shard, g: Guild, m: GuildMembersChunk) {.async.} = discard,
            guild_role_create: proc (s: Shard, g: Guild, r: Role) {.async.} = discard,
            guild_role_update: proc (s: Shard, g: Guild, r: Role, o: Option[Role]) {.async.} = discard,
            guild_role_delete: proc (s: Shard, g: Guild, r: Role) {.async.} = discard,
            invite_create: proc (s: Shard, c: GuildChannel, i: InviteMetadata) {.async.} = discard,
            invite_delete: proc (s: Shard, c: GuildChannel, code: string, g: Option[Guild]) {.async.} = discard,
            user_update: proc (s: Shard, u: User, o: Option[User]) {.async.} = discard,
            voice_state_update: proc (s: Shard, v: VoiceState, o: Option[VoiceState]) {.async.} = discard,
            webhooks_update: proc (s: Shard, g: Guild, c: GuildChannel) {.async.} = discard
        ))

proc shardId*(id: string, shard: int): SomeInteger =
    result = (parseBiggestInt(id) shl 22) mod shard

proc newShard*(id: int, client: DiscordClient): Shard =
    result = Shard(
        id: id,
        client: client,
        retry_info: (ms: 1000, attempts: 0)
    )

proc getGatewayBot(cl: DiscordClient): Future[GatewayBot] {.async.} =
    let client = newAsyncHttpClient("DiscordBot (https://github.com/krisppurg/dimscord, v" & libVer & ")")

    client.headers["Authorization"] = if cl.token.startsWith("Bot "): cl.token else: "Bot " & cl.token
    let resp = await client.get(restBase & "/gateway/bot")

    if int(resp.code) == 200:
        result = (await resp.body).parseJson.to(GatewayBot)

proc getGateway(): Future[string] {.async.} =
    let client = newAsyncHttpClient("DiscordBot (https://github.com/krisppurg/dimscord, v" & libVer & ")")
    let resp = await client.get(restBase & "/gateway")

    result = (await resp.body).parseJson()["url"].str

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

proc waitWhenReady(s: Shard) {.async.} =
    while s.authenticating:
        await sleepAsync 500
        await s.waitWhenReady()

proc handleDisconnect(s: Shard, msg: string): bool = # handle disconnect actually prints out sock suspended then returns a bool whether to reconnect.
    let closeData = extractCloseData(msg)

    s.debugMsg("Socket suspended", @["code", $closeData.code, "reason", $closeData.reason])

    if s.authenticating: s.authenticating = false
    if s.resuming: s.resuming = false

    s.hbAck = false
    s.hbSent = false
    s.retry_info = (ms: 1000, attempts: 0)
    s.lastHBTransmit = 0
    s.lastHBReceived = 0
    lastReady = 0.0

    result = true

    var unreconnectableCodes = @[4003, 4004, 4005, 4007, 4010, 4011, 4012, 4013, 4014]
    if unreconnectableCodes.contains(closeData.code):
        result = false
        reconnectable = false
        debugMsg("Unable to reconnect to gateway, because one your options sent to gateway are invalid.")

proc updateStatus*(s: Shard; game = none(GameStatus); status = "online"; afk = false) {.async.} =
    ## Updates the shard's status.
    if s.stop or (s.connection == nil or s.connection.sock.isClosed): return
    let payload = %*{
        "since": 0,
        "afk": afk,
        "status": status
    }

    if game.isSome:
        payload["game"] = newJObject()
        payload["game"]["type"] = %*get(game).kind
        payload["game"]["name"] = %*get(game).name

        if get(game).url.isSome:
            payload["game"]["url"] = %*get(get(game).url)

    await s.connection.sendText($(%*{
        "op": opStatusUpdate,
        "d": payload
    }))

proc updateStatus*(cl: DiscordClient; game = none(GameStatus); status = "online"; afk = false) {.async.} =
    ## Updates all the client's shard's status.
    for i in 0..cl.shards.len - 1:
        let s = cl.shards[i]
        await s.updateStatus(game, status, afk)

proc identify(s: Shard) {.async.} =
    if s.authenticating or (s.connection == nil or s.connection.sock.isClosed): return

    s.authenticating = true
    s.debugMsg("Identifying...")

    if (epochTime() * 1000 - lastReady) < 5500.0:
        await sleepAsync 5500

    let payload = %*{
        "token": s.client.token,
        "properties": %*{
            "$os": system.hostOS,
            "$browser": libName,
            "$device": libName
        },
        "compress": s.compress,
        "guild_subscriptions": s.client.guild_subscriptions,
        "large_threshold": s.client.largeThresold
    }
    echo "Hi"

    if s.client.shard > 1:
        payload["shard"] = %[s.id, s.client.shard]
    if s.client.intents.len > 0:
        var intents = 0

        for intent in s.client.intents:
            intents = intents or cast[int]({intent})
        payload["intents"] = %intents

    await s.connection.sendText($(%*{
        "op": opIdentify,
        "d": payload
    }))

proc requestGuildMembers*(s: Shard, guild_id: seq[string];
        query = ""; limit: int;
        presences = false; nonce = "";
        user_ids: seq[string] = @[]) {.async.} =
    ## Requests the offline members to a guild.
    ## (See: https://discord.com/developers/docs/topics/gateway#request-guild-members)
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
    
    await s.connection.sendText($(%*{
        "op": opRequestGuildMembers,
        "d": payload
    }))

proc handleDispatch(s: Shard, event: string, data: JsonNode) {.async.} =
    let cl = s.client
    s.debugMsg("Recieved event: " & event)

    case event:
        of "READY":
            s.session_id = data["session_id"].str
            s.authenticating = false
            cl.user = newUser(data["user"])
            lastReady = epochTime() * 1000

            if s.id + 1 == cl.shard:
                debugMsg("All shards have successfully connected to the gateway.")

            s.debugMsg("Successfully identified.")

            await cl.events.on_ready(s, newReady(data))
        of "VOICE_STATE_UPDATE":
            let guild = cl.cache.guilds.getOrDefault(data["guild_id"].str, Guild(id: data["guild_id"].str))
            let voiceState = newVoiceState(data)
            var oldVoiceState = none(VoiceState)

            if cl.cache.guilds.hasKey(guild.id):
                guild.members[voiceState.user_id].voice_state = some(voiceState)

                if guild.voice_states.hasKeyOrPut(voiceState.user_id, voiceState):
                    oldVoiceState = some(guild.voice_states[voiceState.user_id])
                    guild.voice_states[voiceState.user_id] = voiceState

            await cl.events.voice_state_update(s, voiceState, oldVoiceState)
        of "CHANNEL_PINS_UPDATE":
            var guild = none(Guild)
            var last_pin = none(string)

            if data.hasKey("last_pin_timestamp"):
                last_pin = some(data["last_pin_timestamp"].str)

            if data.hasKey("guild_id"):
                guild = some(Guild(id: data["guild_id"].str))
                if cl.cache.guilds.hasKey(get(guild).id):
                    guild = some(cl.cache.guilds[data["guild_id"].str])

            await cl.events.channel_pins_update(s, data["channel_id"].str, guild, last_pin)
        of "GUILD_EMOJIS_UPDATE":
            var g = Guild(id: data["guild_id"].str)

            if cl.cache.guilds.hasKey(g.id):
                g = cl.cache.guilds[g.id]

            var emojis: seq[Emoji] = @[]
            for emji in data["emojis"]:
                emojis.add(newEmoji(emji))
                g.emojis.add(emji["id"].str, newEmoji(emji))

            await cl.events.guild_emojis_update(s, g, emojis)
        of "USER_UPDATE":
            let user = newUser(data)
            var oldUser = none(User)
            cl.user = user

            await cl.events.user_update(s, user, oldUser)
        of "PRESENCE_UPDATE":
            var oldPresence = none(Presence)
            let presence = newPresence(data)

            if cl.cache.guilds.hasKey(presence.guild_id):
                let guild = cl.cache.guilds[presence.guild_id]

                if guild.presences.hasKey(presence.user.id):
                    oldPresence = some(guild.presences[presence.user.id])

                var member = guild.members.getOrDefault(presence.user.id)

                if presence.status == "offline":
                    guild.presences.del(presence.user.id)
                elif @["offline", ""].contains(member.presence.status) and presence.status != "offline":
                    guild.presences.add(presence.user.id, presence)

                if guild.presences.hasKey(presence.user.id):
                    guild.presences[presence.user.id] = presence

                member.presence = presence

            await cl.events.presence_update(s, presence, oldPresence)
        of "MESSAGE_CREATE":
            let msg = newMessage(data)

            if cl.cache.guildChannels.hasKey(msg.channel_id) or cl.cache.dmChannels.hasKey(msg.channel_id):
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

            await cl.events.message_create(s, msg)
        of "MESSAGE_REACTION_ADD":
            var msg = Message(id: data["message_id"].str, channel_id: data["channel_id"].str)
            var emoji = newEmoji(data["emoji"])
            var user = User(id: data["user_id"].str)
            var reaction = Reaction(emoji: emoji)
            var exists = false

            if cl.cache.preferences.cache_users:
                user = cl.cache.users[user.id]

            if cl.cache.guildChannels.hasKey(msg.channel_id) or cl.cache.dmChannels.hasKey(msg.channel_id):
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
                msg.guild_id = some(data["guild_id"].str)
                msg.member = some(newMember(data["member"]))

            if msg.reactions.hasKey($emoji):
                reaction.count = msg.reactions[$emoji].count + 1

                if data["user_id"].str == cl.user.id:
                    reaction.reacted = true

                msg.reactions[$emoji] = reaction
            else:
                reaction.count += 1
                reaction.reacted = data["user_id"].str == cl.user.id
                msg.reactions.add($emoji, reaction)

            await cl.events.message_reaction_add(s, msg, user, reaction, exists)
        of "MESSAGE_REACTION_REMOVE":
            var msg = Message(id: data["message_id"].str, channel_id: data["channel_id"].str)
            var emoji = newEmoji(data["emoji"])
            var user = User(id: data["user_id"].str)
            var reaction = Reaction(emoji: emoji)
            var exists = false

            if cl.cache.users.hasKey(user.id):
                user = cl.cache.users[user.id]

            if cl.cache.guildChannels.hasKey(msg.channel_id) or cl.cache.dmChannels.hasKey(msg.channel_id):
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
                msg.guild_id = some(data["guild_id"].str)

            if msg.reactions.hasKey($emoji) and msg.reactions[$emoji].count != 1:
                reaction.count = msg.reactions[$emoji].count - 1

                if data["user_id"].str == cl.user.id:
                    reaction.reacted = false

                msg.reactions[$emoji] = reaction
            else:
                msg.reactions.del($emoji)

            await cl.events.message_reaction_remove(s, msg, user, reaction, exists)
        of "MESSAGE_REACTION_REMOVE_EMOJI":
            var msg = Message(id: data["message_id"].str, channel_id: data["channel_id"].str)
            var emoji = newEmoji(data["emoji"])
            var exists = false

            if cl.cache.guildChannels.hasKey(msg.channel_id) or cl.cache.dmChannels.hasKey(msg.channel_id):
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
                msg.guild_id = some(data["guild_id"].str)

            if msg.reactions.hasKey($emoji):
                msg.reactions.del($emoji)

            await cl.events.message_reaction_remove_emoji(s, msg, emoji, exists)
        of "MESSAGE_REACTION_REMOVE_ALL":
            var msg = Message(id: data["message_id"].str, channel_id: data["channel_id"].str)
            var exists = false

            if cl.cache.guildChannels.hasKey(msg.channel_id) or cl.cache.dmChannels.hasKey(msg.channel_id):
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
                msg.guild_id = some(data["guild_id"].str)

            if msg.reactions.len > 0:
                msg.reactions.clear()

            await cl.events.message_reaction_remove_all(s, msg, exists)
        of "MESSAGE_DELETE":
            var msg = Message(id: data["id"].str, channel_id: data["channel_id"].str)
            var exists = false

            if data.hasKey("guild_id"):
                msg.guild_id = some(data["guild_id"].str)

            if cl.cache.guildChannels.hasKey(msg.channel_id) or cl.cache.dmChannels.hasKey(msg.channel_id):
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

            await cl.events.message_delete(s, msg, exists)
        of "MESSAGE_UPDATE":
            var msg = Message(id: data["id"].str, channel_id: data["channel_id"].str)
            var oldMessage = none(Message)
            var exists = false

            if cl.cache.guildChannels.hasKey(msg.channel_id) or cl.cache.dmChannels.hasKey(msg.channel_id):
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

            await cl.events.message_update(s, msg, oldMessage, exists)
        of "MESSAGE_DELETE_BULK":
            var ids: seq[tuple[msg: Message, exists: bool]] = @[]

            for msg in data["ids"].elems:
                var exists = false
                var m = Message(id: msg.str, channel_id: data["channel_id"].str)

                if cl.cache.guildChannels.hasKey(m.channel_id) or cl.cache.dmChannels.hasKey(m.channel_id):
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
                    m.guild_id = some(data["guild_id"].str)
                ids.add((msg: m, exists: exists))

            await cl.events.message_delete_bulk(s, ids)
        of "CHANNEL_CREATE":
            var guild = none(Guild)
            var chan = none(GuildChannel)
            var dmChan = none(DMChannel)

            if data["type"].getInt() != ctDirect:
                guild = some(Guild(id: data["guild_id"].str))

                if cl.cache.guilds.hasKey(get(guild).id):
                    guild = some(cl.cache.guilds[get(guild).id])

                chan = some(newGuildChannel(data))

                if cl.cache.preferences.cache_guild_channels:
                    cl.cache.guildChannels.add(get(chan).id, get(chan))
                    get(guild).channels.add(get(chan).id, get(chan))
            elif data["type"].getInt() == ctDirect and not cl.cache.dmChannels.hasKey(data["id"].str):
                dmChan = some(newDMChannel(data))
                if cl.cache.preferences.cache_dm_channels:
                    cl.cache.dmChannels.add(data["id"].str, get(dmChan))

            await cl.events.channel_create(s, guild, chan, dmChan)
        of "CHANNEL_UPDATE":
            var gchan = newGuildChannel(data)
            var oldChan = none(GuildChannel) 

            var guild = Guild(id: data["guild_id"].str)

            if cl.cache.guilds.hasKey(guild.id):
                guild = cl.cache.guilds[guild.id]

                if cl.cache.guildChannels.hasKey(gchan.id):
                    oldChan = some(guild.channels[gchan.id])
                    guild.channels[gchan.id] = gchan
                    cl.cache.guildChannels[gchan.id] = gchan
            await cl.events.channel_update(s, guild, gchan, oldChan)
        of "CHANNEL_DELETE":
            var guild = none(Guild)
            var gc = none(GuildChannel)
            var dm = none(DMChannel)

            if data.hasKey("guild_id"):
                guild = some(Guild(id: data["guild_id"].str))
                if cl.cache.guilds.hasKey(get(guild).id):
                    guild = some(cl.cache.guilds[get(guild).id])

            if cl.cache.guildChannels.hasKey(data["id"].str) or cl.cache.dmChannels.hasKey(data["id"].str):
                if cl.cache.kind(data["id"].str) != ctDirect:
                    gc = some(newGuildChannel(data))

                    if cl.cache.guilds.hasKey(get(guild).id):
                        get(guild).channels.del(get(gc).id)

                    if cl.cache.guildChannels.hasKey(get(gc).id):
                        cl.cache.guildChannels.del(get(gc).id)
                else:
                    if cl.cache.preferences.cache_dm_channels:
                        dm = some(newDMChannel(data))
                        cl.cache.dmChannels.del(get(dm).id)

            await cl.events.channel_delete(s, guild, gc, dm)
        of "GUILD_MEMBERS_CHUNK":
            let guild = cl.cache.guilds.getOrDefault(data["guild_id"].str, Guild(id: data["guild_id"].str))

            for member in data["members"].elems:
                guild.members.add(member["user"]["id"].str, newMember(member))
                cl.cache.users.add(member["user"]["id"].str, newUser(member["user"]))

            await cl.events.guild_members_chunk(s, guild, newGuildMembersChunk(data))
        of "GUILD_MEMBER_ADD":
            var guild = Guild(id: data["guild_id"].str)
            let member = newMember(data)

            if cl.cache.guilds.hasKey(guild.id):
                guild = cl.cache.guilds[guild.id]
                guild.members.add(member.user.id, member)
                guild.member_count = some(get(guild.member_count) + 1)
                if cl.cache.preferences.cache_users:
                    cl.cache.users.add(member.user.id, member.user)

            await cl.events.guild_member_add(s, guild, member)
        of "GUILD_MEMBER_UPDATE":
            var guild = Guild(id: data["guild_id"].str)
            var member = Member()
            var oldMember = none(Member)

            if cl.cache.guilds.hasKey(guild.id):
                guild = cl.cache.guilds[guild.id]
                member = guild.members[data["user"]["id"].str]
                oldMember = some(member)

            member.user = newUser(data["user"])

            if not cl.cache.users.hasKey(member.user.id):
                if cl.cache.preferences.cache_users:
                    cl.cache.users.add(member.user.id, member.user)
            else:
                cl.cache.users[member.user.id] = member.user

            if data.hasKey("nick") and data["nick"].kind != JNull:
                member.nick = data["nick"].str

            if data.hasKey("premium_since") and data["premium_since"].kind != JNull:
                member.premium_since = data["premium_since"].str

            for role in data["roles"].elems:
                member.roles.add(role.str)

            await cl.events.guild_member_update(s, guild, member, oldMember)
        of "GUILD_MEMBER_REMOVE":
            var guild = Guild(id: data["guild_id"].str)
            var member = Member(user: newUser(data))

            if cl.cache.guilds.hasKey(guild.id):
                guild = cl.cache.guilds[guild.id]
                member = guild.members[member.user.id]

                guild.members.del(member.user.id)
                guild.member_count = some(get(guild.member_count) - 1)
    
                if cl.cache.users.hasKey(member.user.id):
                    cl.cache.users.del(member.user.id)

            await cl.events.guild_member_remove(s, guild, member)
        of "GUILD_BAN_ADD":
            var guild = Guild(id: data["guild_id"].str)
            let user = newUser(data["user"])
            if cl.cache.guilds.hasKey(guild.id):
                guild = cl.cache.guilds[guild.id]

            await cl.events.guild_ban_add(s, guild, user)
        of "GUILD_BAN_REMOVE":
            var guild = Guild(id: data["guild_id"].str)
            let user = newUser(data["user"])
            if cl.cache.guilds.hasKey(guild.id):
                guild = cl.cache.guilds[guild.id]

            await cl.events.guild_ban_add(s, guild, user)
        of "GUILD_UPDATE":
            let guild = newGuild(data)
            var oldGuild = none(Guild)
            if cl.cache.guilds.hasKey(guild.id):
                oldGuild = some(cl.cache.guilds[guild.id])
                cl.cache.guilds[guild.id] = guild

            await cl.events.guild_update(s, guild, oldGuild)
        of "GUILD_DELETE":
            var guild = Guild(id: data["id"].str)
            var oldGuild = none(Guild)

            if cl.cache.guilds.hasKey(guild.id):
                cl.cache.guilds[guild.id].unavailable = some((if data.hasKey("unavailable"): data["unavailable"].bval else: false))
                guild = cl.cache.guilds[guild.id]
                cl.cache.guilds.del(guild.id)

            await cl.events.guild_delete(s, guild)
        of "GUILD_ROLE_CREATE":
            var guild = Guild(id: data["guild_id"].str)
            let role = newRole(data["role"])

            if cl.cache.guilds.hasKey(guild.id):
                guild = cl.cache.guilds[guild.id]
                guild.roles.add(role.id, role)

            await cl.events.guild_role_create(s, guild, role)
        of "GUILD_ROLE_UPDATE":
            var guild = Guild(id: data["guild_id"].str)
            let role = newRole(data["role"])
            var oldRole = none(Role)

            if cl.cache.guilds.hasKey(guild.id):
                guild = cl.cache.guilds[guild.id]
                oldRole = some(guild.roles[role.id])

                guild.roles[role.id] = role

            await cl.events.guild_role_update(s, guild, role, oldRole)
        of "GUILD_ROLE_DELETE":
            var guild = Guild(id: data["guild_id"].str)
            var role = Role(id: data["role_id"].str)

            if cl.cache.guilds.hasKey(guild.id):
                guild = cl.cache.guilds[guild.id]
                role = guild.roles[role.id]

            await cl.events.guild_role_delete(s, guild, role)
        of "WEBHOOKS_UPDATE":
            var guild = Guild(id: data["guild_id"].str)
            var chan = GuildChannel(id: data["channel_id"].str)

            if cl.cache.guilds.hasKey(guild.id):
                guild = cl.cache.guilds[guild.id]
            if cl.cache.guildChannels.hasKey(chan.id):
                chan = cl.cache.guildChannels[chan.id]

            await cl.events.webhooks_update(s, guild, chan)
        of "RESUMED":
            s.resuming = false
            s.authenticating = false

            s.debugMsg("Successfuly resumed.")
        of "GUILD_CREATE": # TODO: finish
            let guild = newGuild(data)
            s.debugMsg("Recieved GUILD_CREATE event", @["id", guild.id])

            if cl.cache.preferences.cache_guilds:
                cl.cache.guilds.add(guild.id, guild)

            if data["channels"].elems.len > 0:
                for chan in data["channels"].elems:
                    if cl.cache.preferences.cache_guild_channels:
                        let gc = newGuildChannel(chan)
                        guild.channels.add(gc.id, gc)
                        cl.cache.guildChannels.add(gc.id, gc)

            if cl.cache.preferences.cache_users:
                if data["members"].elems.len > 0:
                    for m in data["members"].elems:
                        cl.cache.users.add(m["user"]["id"].str, newUser(m["user"]))
            
            await cl.events.guild_create(s, guild)
        else:
            discard

proc resume(s: Shard) {.async.} =
    if s.authenticating: return
    if s.connection.sock.isClosed: return

    s.authenticating = true
    s.resuming = true

    s.debugMsg("Attempting to resume", @["session_id", s.session_id, "events", $s.sequence])
    await s.connection.sendText($(%*{
        "op": opResume,
        "d": %*{
            "token": s.client.token,
            "session_id": s.session_id,
            "seq": s.sequence
        }
    }))

proc reconnect(s: Shard) {.async.} =
    if s.reconnecting: return
    s.reconnecting = true
    s.retry_info.attempts += 1

    var url = "gateway.discord.gg"

    try: 
        url = await getGateway()
    except:
        s.debugMsg("Error occurred:: \n" & getCurrentExceptionMsg())
        s.reconnecting = false

        s.retry_info.ms = min(s.retry_info.ms + max(rand(6000), 3000), 30000)

        s.debugMsg(&"Reconnecting in {s.retry_info.ms}ms", @[
            "attempt", $s.retry_info.attempts
        ])

        await sleepAsync s.retry_info.ms
        await s.reconnect()

    s.debugMsg("Connecting to " & (if url.startsWith("wss://"): url[6..url.high] else: url) & "/?v=" & $gatewayVer)

    try:
        s.connection = await newAsyncWebsocketClient(
            if url.startsWith("wss://"): url[6..url.high] else: url,
            Port 443,
            "/?v=" & $gatewayVer,
            true
        )
        s.hbAck = true
        s.stop = false
        s.reconnecting = false

        if s.networkError:
            s.debugMsg("Successfully established a gateway connection after network error.")
            s.retry_info = (ms: 1000, attempts: 0)
            s.networkError = false
    except:
        s.debugMsg("Error occurred: \n" & getCurrentExceptionMsg())
        s.reconnecting = false
        s.retry_info.ms = min(s.retry_info.ms + max(rand(6000), 3000), 30000)

        s.debugMsg(&"Got gateway, but failed to connect, reconnecting in {s.retry_info.ms}ms", @[
            "attempt", $s.retry_info.attempts
        ])

        await sleepAsync s.retry_info.ms
        await s.reconnect()

    if s.session_id == "" and s.sequence == 0:
        await s.identify()
    else:
        await s.resume()

proc disconnect*(s: Shard, code: int = 4000, should_reconnect: bool = true) {.async.} =
    if s.stop: return
    s.stop = true

    if s.connection != nil or not s.connection.sock.isClosed:
        s.debugMsg("Sending close code: " & $code & " to disconnect")
        await s.connection.close(code)

    if s.client.autoreconnect or should_reconnect: await s.reconnect()

proc heartbeat(s: Shard, requested = false) {.async.} =
    if not s.hbAck and not requested:
        s.debugMsg("Last heartbeat was not acknowledged by Discord, possibly zombied connection.")
        await s.disconnect(should_reconnect = true)
        return

    s.debugMsg("Sending heartbeat.")
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

proc handleSocketMessage(s: Shard) {.async.} =
    await s.identify()

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
                s.debugMsg("A network error has been detected.")

                s.networkError = true
            elif exception.startsWith("socket closed"):
                s.debugMsg("Received 'socket closed'.\n\nGetting time since last heartbeat recieved: " & $int(epochTime() * 1000 - s.lastHBReceived))

                if (epochTime() * 1000 - s.lastHBReceived) > 90000 or exception.startsWith("The network connection was aborted by the local system."): # this is my clever way of detecting a sleep
                    raise newException(Exception, "Last heartbeat was recieved over 90 seconds.")
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
            if not s.networkError: await s.handleSocketMessage()

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
                s.lastHBReceived = epochTime() * 1000
                s.hbSent = false
                s.debugMsg("Heartbeat Acknowledged by Discord.")

                s.hbAck = true
            of opHeartbeat:
                s.debugMsg("Discord has requested a heartbeat.")
                await s.heartbeat(true)
            of opDispatch:
                asyncCheck s.handleDispatch(data["t"].str, data["d"])
            of opReconnect:
                s.debugMsg("Discord is requesting for a client reconnect.")
                await s.disconnect(should_reconnect = shouldReconnect)
            of opInvalidSession:
                s.resuming = false
                s.authenticating = false

                s.debugMsg("Session invalidated", @["resumable", $data["d"].bval])

                if data["d"].bval:
                    await s.resume()
                else:
                    s.debugMsg("Identifying in 5000ms...")

                    await sleepAsync 5000
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
    lastReady = 0.0

    if shouldReconnect:
        await s.reconnect()
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

        await s.reconnect()
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
        s.stop = true
        raise newException(Exception, getCurrentExceptionMsg())

    await s.handleSocketMessageExceptions() # hope dis works *sweats*

proc startSession*(cl: DiscordClient,
            autoreconnect = false;
            gateway_intents: set[GatewayIntent] = {};
            large_threshold = 50;
            guild_subscriptions = true;
            shards = 1;
            compress = false) {.async.} =
    ## Connects the client to Discord via gateway.
    ## 
    ## - gateway_intents | Allows you to subscribe to pre-defined events (See: https://discord.com/developers/docs/topics/gateway#gateway-intents)
    ## - shards | An amount of shards.
    ## - compress | Whether or not to compress. zlib1(.dll|.so.1|.dylib) needs to be in your directory.
    ## - large_threshold | An integer that would be considered a large guild. You should use requestGuildMembers if necessary.
    ## - guild_subscriptions | This allows you to subscribe to receive presence_update and typing_start events.

    if cl.restMode:
        raise newException(Exception, "(╯°□°)╯︵ ┻━┻ ! You cannot connect to the gateway while rest mode is enabled ! (╯°□°)╯︵ ┻━┻")

    cl.autoreconnect = autoreconnect
    cl.intents = gateway_intents
    cl.shard = shards

    var query = "/?v=" & $gatewayVer

    if gateway.url == "":
        debugMsg("Connecting to the discord gateway.")
        var info: GatewayBot

        try:
            info = await cl.getGatewayBot()
        except OSError:
            if getCurrentExceptionMsg().startsWith("No such host is known."):
                debugMsg("A network error has been detected.")
                return

        debugMsg("Successfully retrived gateway information from Discord", @[
            "url", info.url,
            "shards", $info.shards,
            "session_start_limit", $info.session_start_limit
        ])

        if info.session_start_limit.remaining == 0:
            let time = getTime().utc.toTime.toUnix - info.session_start_limit.reset_after

            debugMsg("Your session start limit has reached its limit", @[
                "sleep_time", $time
            ])
            await sleepAsync time.int
        
        gateway = (info.shards, info.url)

    if shards == 1 and gateway.shards > 1:
        cl.shard = gateway.shards

    if shards > 1:
        for i in 0..cl.shard - 2:
            if i != 0:
                if cl.shards[1 - 1].authenticating:
                    await cl.shards[i - 1].waitWhenReady()
                await sleepAsync 5000

            let ss = newShard(i, cl)
            cl.shards.add(i, ss)
            ss.compress = compress
            asyncCheck ss.startSession(gateway.url, query)

            await ss.waitWhenReady()
            await sleepAsync 5000

    let ss = newShard(cl.shard - 1, cl)
    cl.shards.add(cl.shard - 1, ss)
    ss.compress = compress
    await ss.startSession(gateway.url, query)

proc getPing*(s: Shard): int =
    ## Gets the shard's ping ms.
    result = (s.lastHBReceived - s.lastHBTransmit).int