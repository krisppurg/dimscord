import objects, constants
import options, json, asyncdispatch
import sequtils, tables, jsony, macros
import helpers {.all.}
import std/[sugar, strutils]

when (NimMajor, NimMinor, NimPatch) >= (1, 6, 0):
    {.warning[HoleEnumConv]: off.}
    {.warning[CaseTransition]: off.}

when defined(dimscordVoice):
    from voice import pause, disconnect

proc checkIfAwaiting(discord: DiscordClient;
        event: static[DispatchEvent]; data: tuple) =
  ## Runs `data` against a series of handlers waiting on `id`.
  # TODO: Using pointer so works same as when I add the inner table
  var handlers = addr discord.waits[event]
  # We countdown so we can delete while iterating
  for i in countdown(handlers[].len - 1, 0):
    let dataPtr = when (NimMajor, NimMinor) >= (1, 9): addr data
                  else: unsafeAddr data
    if handlers[i](dataPtr):
      # Remove the handler if it gets completed
      handlers[].del(i)

macro checkAndCall(s: Shard, event: static[DispatchEvent], args: varargs[untyped]) =
    ## Checks if any handlers are waiting for an event and then calls the users handler
    # Convert the passed in values into a list
    let params = collect:
        for arg in args: arg

    let
        tupleData = nnkTupleConstr.newTree(params)
        eventName = ident toLowerAscii($event)
        client = s.newDotExpr(ident"client")
        # Generate version of call without shard (Not every event takes the shard)
        call = client.newDotExpr(ident"events")
                                 .newDotExpr(eventName)
                                 .newCall(params)
        # Generate version with shard
        callWithShard = call.dup(insert(1, s))
    result = quote do:
        `client`.checkIfAwaiting(DispatchEvent(`event`), `tupleData`)
        when compiles(`callWithShard`):
            asyncCheck `callWithShard`
        else:
            asyncCheck `call`

macro enumElementsAsSet(enm: typed): untyped =
    result = newNimNode(nnkCurly).add(enm.getType[1][1..^1])

func fullSet*[T](U: typedesc[T]): set[T] {.inline.} =
    when T is Ordinal:
        {T.low..T.high}
    else: # Hole filled enum
        enumElementsAsSet(T)

proc addMsg(c: GuildChannel, m: Message, data: string;
        prefs: CacheTablePrefs) {.async.} =
    if data.len < prefs.max_message_size:
        if c.messages.len == prefs.large_message_threshold:
            c.messages.clear()
        c.messages[m.id] = m
    await sleepAsync 120_000
    c.messages.del(m.id)

proc addMsg(c: DMChannel, m: Message, data: string;
        prefs: CacheTablePrefs) {.async.} =
    if data.len < prefs.max_message_size:
        if c.messages.len == prefs.large_message_threshold:
            c.messages.clear()
        c.messages[m.id] = m
    await sleepAsync 120_000
    c.messages.del(m.id)

proc voiceStateUpdate(s: Shard, data: JsonNode) {.async.} =
    let guild = s.cache.guilds.getOrDefault(data["guild_id"].str,
        Guild(id: data["guild_id"].str)
    )
    let voiceState = newVoiceState(data)
    var oldVoiceState: Option[VoiceState]
    if guild.id in s.cache.guilds and voiceState.user_id in guild.members:
        guild.members[voiceState.user_id].voice_state = some voiceState

    if guild.voice_states.hasKeyOrPut(voiceState.user_id, voiceState):
        if voiceState.channel_id.isSome:
            oldVoiceState = some(
                move guild.voice_states[voiceState.user_id]
            )
            guild.voice_states[voiceState.user_id] = voiceState
        else:
            guild.voice_states.del voiceState.user_id

    if voiceState.user_id == s.user.id:
        if voiceState.channel_id.isNone:
            s.voiceConnections.del(guild.id)
        else:
            if guild.id notin s.voiceConnections:
                s.voiceConnections[guild.id] = VoiceClient(
                    shard: s,
                    voice_events: VoiceEvents(
                        on_dispatch: proc (v: VoiceClient,
                                d: JsonNode, event: string){.async.} = discard,
                        on_speaking: proc (v: VoiceClient,
                                speaking: bool){.async.} = discard,
                        on_ready: proc (v: VoiceClient){.async.} = discard,
                        on_disconnect: proc (v: VoiceClient){.async.} = discard
                    ),
                    reconnectable: true,
                )
            let v = s.voiceConnections[guild.id]
            v.guild_id = guild.id
            v.channel_id = get voiceState.channel_id
            v.session_id = voiceState.session_id

    s.checkAndCall(deVoiceStateUpdate, voiceState, oldVoiceState)

proc channelPinsUpdate(s: Shard, data: JsonNode) {.async.} =
    var
        guild: Option[Guild]
        last_pin: Option[string]

    if "last_pin_timestamp" in data and data["last_pin_timestamp"].kind != JNull:
        last_pin = some data["last_pin_timestamp"].str

    if "guild_id" in data:
        guild = some Guild(id: data["guild_id"].str)
        if guild.get.id in s.cache.guilds:
            guild = some s.cache.guilds[data["guild_id"].str]
    let channelID = data["channel_id"].str
    s.checkAndCall(deChannelPinsUpdate, channelID, guild, last_pin)

proc guildEmojisUpdate(s: Shard, data: JsonNode) {.async.} =
    let guild = s.cache.guilds.getOrDefault(data["guild_id"].str,
        Guild(id: data["guild_id"].str)
    )

    var emojis: seq[Emoji] = @[]
    for emoji in data["emojis"]:
        let emji = newEmoji(emoji)
        emojis.add(emji)
        guild.emojis[get emji.id] = emji
    s.checkAndCall(deGuildEmojisUpdate, guild, emojis)

proc guildStickersUpdate(s: Shard, data: JsonNode) {.async.} =
    let guild = s.cache.guilds.getOrDefault(data["guild_id"].str,
        Guild(id: data["guild_id"].str)
    )

    var stickers: seq[Sticker] = @[]
    for sticker in data["stickers"]:
        let st = newSticker(sticker)
        stickers.add(st)
        guild.stickers[st.id] = st
    s.checkAndCall(deGuildStickersUpdate, guild, stickers)

proc presenceUpdate(s: Shard, data: JsonNode) {.async.} =
    var oldPresence: Option[Presence]
    let presence = newPresence(data)

    if presence.guild_id in s.cache.guilds:
        let guild = s.cache.guilds[presence.guild_id]

        if presence.user.id in guild.presences:
            oldPresence = some move guild.presences[presence.user.id]

        let member = guild.members.getOrDefault(presence.user.id, Member(
            user: User(
                id: data["user"]["id"].str,
            ),
            presence: Presence(
                status: "offline",
                client_status: ("offline", "offline", "offline")
            )
        ))
        let offline = member.presence.status in ["offline", ""]

        if presence.status == "offline":
            guild.presences.del(presence.user.id)
        elif offline and presence.status != "offline":
            guild.presences[presence.user.id] = presence

        if presence.user.id in guild.presences:
            guild.presences[presence.user.id] = presence

        member.presence = presence
    s.checkAndCall(dePresenceUpdate, presence, oldPresence)

proc messageCreate(s: Shard, data: JsonNode) {.async.} =
    let msg = newMessage(data)

    if msg.channel_id in s.cache.guildChannels:
        let chan = s.cache.guildChannels[msg.channel_id]

        asyncCheck chan.addMsg(msg, $data, s.cache.preferences)
        chan.last_message_id = msg.id

    elif msg.channel_id in s.cache.dmChannels:
        let chan = s.cache.dmChannels[msg.channel_id]

        asyncCheck chan.addMsg(msg, $data, s.cache.preferences)
        chan.last_message_id = msg.id

    s.checkAndCall(deMessageCreate, msg)

proc messageReactionAdd(s: Shard, data: JsonNode) {.async.} =
    var
        msg = Message(
            id: data["message_id"].str,
            channel_id: data["channel_id"].str)

        user = s.cache.users.getOrDefault(data["user_id"].str,
            User(id: data["user_id"].str)
        )

        emoji = newEmoji(data["emoji"])
        reaction = Reaction(emoji: emoji)
        exists = false

    if msg.channel_id in s.cache.guildChannels:
        let chan = s.cache.guildChannels[msg.channel_id]

        if msg.id in chan.messages:
            msg = chan.messages[msg.id]
            exists = true
    elif msg.channel_id in s.cache.dmChannels:
        let chan = s.cache.dmChannels[msg.channel_id]

        if msg.id in chan.messages:
            msg = chan.messages[msg.id]
            exists = true

    if "guild_id" in data:
        msg.guild_id = some data["guild_id"].str
        msg.member = some newMember(data["member"])

    if $emoji in msg.reactions:
        reaction.count = msg.reactions[$emoji].count + 1

        if data["user_id"].str == s.user.id:
            reaction.reacted = true

        msg.reactions[$emoji] = reaction
    else:
        reaction.count += 1
        reaction.reacted = data["user_id"].str == s.user.id
        msg.reactions[$emoji] = reaction

    s.checkAndCall(deMessageReactionAdd, msg, user, emoji, exists)

proc messageReactionRemove(s: Shard, data: JsonNode) {.async.} =
    let emoji = newEmoji(data["emoji"])
    var
        msg = Message(
            id: data["message_id"].str,
            channel_id: data["channel_id"].str)

        user = s.cache.users.getOrDefault(data["user_id"].str,
            User(id: data["user_id"].str)
        )

        reaction = Reaction(emoji: emoji)
        exists = false


    if msg.channel_id in s.cache.guildChannels:
        let chan = s.cache.guildChannels[msg.channel_id]

        if msg.id in chan.messages:
            msg = chan.messages[msg.id]
            exists = true
    elif msg.channel_id in s.cache.dmChannels:
        let chan = s.cache.dmChannels[msg.channel_id]

        if msg.id in chan.messages:
            msg = chan.messages[msg.id]
            exists = true

    if "guild_id" in data:
        msg.guild_id = some data["guild_id"].str

    if $emoji in msg.reactions and msg.reactions[$emoji].count > 1:
        reaction.count = msg.reactions[$emoji].count - 1

        if data["user_id"].str == s.user.id:
            reaction.reacted = false

        msg.reactions[$emoji] = reaction
    else:
        msg.reactions.del($emoji)

    s.checkAndCall(deMessageReactionRemove, msg, user, reaction, exists)

proc messageReactionRemoveEmoji(s: Shard, data: JsonNode) {.async.} =
    var
        msg = Message(
            id: data["message_id"].str,
            channel_id: data["channel_id"].str)
        emoji = newEmoji(data["emoji"])
        exists = false

    if msg.channel_id in s.cache.guildChannels:
        let chan = s.cache.guildChannels[msg.channel_id]

        if msg.id in chan.messages:
            msg = chan.messages[msg.id]
            exists = true
    elif msg.channel_id in s.cache.dmChannels:
        let chan = s.cache.dmChannels[msg.channel_id]

        if msg.id in chan.messages:
            msg = chan.messages[msg.id]
            exists = true

    if "guild_id" in data:
        msg.guild_id = some data["guild_id"].str

    msg.reactions.del($emoji)
    s.checkAndCall(deMessageReactionRemoveEmoji, msg, emoji, exists)

proc messageReactionRemoveAll(s: Shard, data: JsonNode) {.async.} =
    var
        msg = Message(
            id: data["message_id"].str,
            channel_id: data["channel_id"].str)
        exists = false

    if msg.channel_id in s.cache.guildChannels:
        let chan = s.cache.guildChannels[msg.channel_id]

        if msg.id in chan.messages:
            msg = chan.messages[msg.id]
            exists = true
    elif msg.channel_id in s.cache.dmChannels:
        let chan = s.cache.dmChannels[msg.channel_id]

        if msg.id in chan.messages:
            msg = chan.messages[msg.id]
            exists = true

    if "guild_id" in data:
        msg.guild_id = some data["guild_id"].str

    if msg.reactions.len > 0:
        msg.reactions.clear()

    s.checkAndCall(deMessageReactionRemoveAll, msg, exists)

proc messageDelete(s: Shard, data: JsonNode) {.async.} =
    var
        msg = Message(
            id: data["id"].str,
            channel_id: data["channel_id"].str)
        exists = false

    if "guild_id" in data:
        msg.guild_id = some data["guild_id"].str

    if msg.channel_id in s.cache.guildChannels:
        let chan = s.cache.guildChannels[msg.channel_id]

        if msg.id in chan.messages:
            msg = chan.messages[msg.id]

            if chan.last_message_id == msg.id:
                chan.last_message_id = ""
            exists = true

        chan.messages.del(msg.id)
    elif msg.channel_id in s.cache.dmChannels:
        let chan = s.cache.dmChannels[msg.channel_id]

        if msg.id in chan.messages:
            msg = chan.messages[msg.id]

            if chan.last_message_id == msg.id:
                chan.last_message_id = ""
            exists = true

        chan.messages.del(msg.id)
    s.checkAndCall(deMessageDelete, msg, exists)

proc messageUpdate(s: Shard, data: JsonNode) {.async.} =
    var
        msg = Message(
            id: data["id"].str,
            channel_id: data["channel_id"].str)
        oldMessage: Option[Message]
        exists = false

    if msg.channel_id in s.cache.guildChannels:
        let chan = s.cache.guildChannels[msg.channel_id]

        if msg.id in chan.messages:
            msg = chan.messages[msg.id]
            oldMessage = some move chan.messages[msg.id]
            exists = true

        msg = msg.updateMessage(data)
        if msg.id in chan.messages: chan.messages[msg.id] = msg
    elif msg.channel_id in s.cache.dmChannels:
        let chan = s.cache.dmChannels[msg.channel_id]

        if msg.id in chan.messages:
            msg = chan.messages[msg.id]
            oldMessage = some move chan.messages[msg.id]
            exists = true

        msg = msg.updateMessage(data)
        if msg.id in chan.messages: chan.messages[msg.id] = msg

    s.checkAndCall(deMessageUpdate, msg, oldMessage, exists)

proc messageDeleteBulk(s: Shard, data: JsonNode) {.async.} =
    var mids: seq[tuple[msg: Message, exists: bool]] = @[]

    for msg in data["ids"].elems:
        var
            m = Message(
                id: msg.str,
                channel_id: data["channel_id"].str)
            exists = false

        if m.channel_id in s.cache.guildChannels:
            let chan = s.cache.guildChannels[m.channel_id]

            if m.id in chan.messages:
                m = chan.messages[m.id]
                chan.messages.del(m.id)
                exists = true

        elif m.channel_id in s.cache.dmChannels:
            let chan = s.cache.dmChannels[m.channel_id]

            if m.id in chan.messages:
                m = chan.messages[m.id]
                chan.messages.del(m.id)
                exists = true

        mids.add (msg: m, exists: exists)

    s.checkAndCall(deMessageDeleteBulk, mids)

proc channelCreate(s: Shard, data: JsonNode) {.async.} =
    var
        guild: Option[Guild]
        chan: Option[GuildChannel]
        dmChan: Option[DMChannel]

    if data["type"].getInt != int ctDirect:
        guild = some Guild(id: data["guild_id"].str)

        if guild.get.id in s.cache.guilds:
            guild = some s.cache.guilds[guild.get.id]

        chan = some newGuildChannel(data)

        if s.cache.preferences.cache_guild_channels:
            s.cache.guildChannels[chan.get.id] = chan.get
            guild.get.channels[chan.get.id] = chan.get
    elif data["id"].str notin s.cache.dmChannels:
        dmChan = some newDMChannel(data)
        if s.cache.preferences.cache_dm_channels:
            s.cache.dmChannels[data["id"].str] = dmChan.get
    s.checkAndCall(deChannelCreate, guild, chan, dmChan)

proc channelUpdate(s: Shard, data: JsonNode) {.async.} =
    let
        gchan = newGuildChannel(data)
        guild = s.cache.guilds.getOrDefault(data["guild_id"].str,
            Guild(id: data["guild_id"].str)
        )

    var oldChan: Option[GuildChannel]

    if gchan.id in s.cache.guildChannels:
        oldChan = some move guild.channels[gchan.id]
        guild.channels[gchan.id] = gchan
        s.cache.guildChannels[gchan.id] = gchan

    s.checkAndCall(deChannelUpdate, guild, gchan, oldChan)

proc channelDelete(s: Shard, data: JsonNode) {.async.} =
    var
        guild: Option[Guild]
        gc: Option[GuildChannel]
        dm: Option[DMChannel]

    if "guild_id" in data:
        guild = some s.cache.guilds.getOrDefault(data["guild_id"].str,
            Guild(id: data["guild_id"].str)
        )

    if data["id"].str in s.cache.guildChannels:
        gc = some newGuildChannel(data)

        if guild.get.id in s.cache.guilds:
            guild.get.channels.del(gc.get.id)

        s.cache.guildChannels.del(gc.get.id)
    elif data["id"].str in s.cache.dmChannels:
        dm = some newDMChannel(data)
        s.cache.dmChannels.del(dm.get.id)

    s.checkAndCall(deChannelDelete, guild, gc, dm)

proc guildMembersChunk(s: Shard, data: JsonNode) {.async.} =
    let guild = s.cache.guilds.getOrDefault(data["guild_id"].str,
        Guild(id: data["guild_id"].str)
    )
    let cacheuser = s.cache.preferences.cache_users

    for member in data["members"].elems:
        if member["user"]["id"].str notin guild.members and cacheuser:
            guild.members[member["user"]["id"].str] = newMember(member)

            s.cache.users[member["user"]["id"].str] = newUser(member["user"])

    let chunk = newGuildMembersChunk(data)
    s.checkAndCall(deGuildMembersChunk, guild, chunk)

proc guildMemberAdd(s: Shard, data: JsonNode) {.async.} =
    let
        guild = s.cache.guilds.getOrDefault(data["guild_id"].str,
            Guild(id: data["guild_id"].str)
        )
        member = newMember(data)

    guild.members[member.user.id] = member

    if guild.member_count.isSome:
        guild.member_count = some guild.member_count.get + 1

    if s.cache.preferences.cache_users:
        s.cache.users[member.user.id] = member.user

    s.checkAndCall(deGuildMemberAdd, guild, member)

proc guildMemberUpdate(s: Shard, data: JsonNode) {.async.} =
    let
        guild = s.cache.guilds.getOrDefault(data["guild_id"].str,
            Guild(id: data["guild_id"].str)
        )

        member = guild.members.getOrDefault(data["user"]["id"].str, Member(
            user: User(
                id: data["user"]["id"].str
            )
        ))

    var oldMember: Option[Member]

    if member.user.id in guild.members:
        oldMember = some move guild.members[member.user.id]

        guild.members[member.user.id] = member

    member.user = newUser(data["user"])

    if s.cache.preferences.cache_users and member.user.id notin s.cache.users:
        s.cache.users[member.user.id] = member.user

    if "nick" in data and data["nick"].kind != JNull:
        member.nick = some data["nick"].str
    if "premium_since" in data and data["premium_since"].kind != JNull:
        member.premium_since = some data["premium_since"].str

    member.roles = @[]
    for role in data["roles"].elems:
        member.roles.add(role.str)

    s.checkAndCall(deGuildMemberUpdate, guild, member, oldMember)

proc guildMemberRemove(s: Shard, data: JsonNode) {.async.} =
    let
        guild = s.cache.guilds.getOrDefault(data["guild_id"].str,
            Guild(id: data["guild_id"].str)
        )
        member = guild.members.getOrDefault(data["user"]["id"].str,
            Member(user: newUser(data["user"]))
        )

    guild.members.del(member.user.id)
    s.cache.users.del(member.user.id)

    if guild.member_count.isSome:
        guild.member_count = some guild.member_count.get - 1

    s.checkAndCall(deGuildMemberRemove, guild, member)

proc guildBanAdd(s: Shard, data: JsonNode) {.async.} =
    let
        guild = s.cache.guilds.getOrDefault(data["guild_id"].str,
            Guild(id: data["guild_id"].str)
        )
        user = newUser(data["user"])

    s.checkAndCall(deGuildBanAdd, guild, user)

proc guildBanRemove(s: Shard, data: JsonNode) {.async.} =
    let
        guild = s.cache.guilds.getOrDefault(data["guild_id"].str,
            Guild(id: data["guild_id"].str)
        )
        user = newUser(data["user"])

    s.checkAndCall(deGuildBanRemove, guild, user)

proc guildAuditLogEntryCreate(s: Shard, data: JsonNode) {.async.} =
    let
        guild = s.cache.guilds.getOrDefault(data["guild_id"].str,
            Guild(id: data["guild_id"].str)
        )
        entry = newAuditLogEntry(data)

    s.checkAndCall(deGuildAuditLogEntryCreate, guild, entry)

proc guildUpdate(s: Shard, data: JsonNode) {.async.} =
    let guild = newGuild(data)
    var oldGuild: Option[Guild]

    if guild.id in s.cache.guilds:
        oldGuild = some move s.cache.guilds[guild.id]

        guild.emojis = oldGuild.get.emojis
        guild.roles = oldGuild.get.roles
        guild.channels = oldGuild.get.channels
        guild.members = oldGuild.get.members
        guild.presences = oldGuild.get.presences
        guild.voice_states = oldGuild.get.voice_states
        guild.guild_scheduled_events = oldGuild.get.guild_scheduled_events
        guild.stickers = oldGuild.get.stickers
        guild.threads = oldGuild.get.threads
        guild.stage_instances = oldGuild.get.stage_instances
        guild.permissions = oldGuild.get.permissions

        guild.large = oldGuild.get.large
        guild.joined_at = oldGuild.get.joined_at
        guild.unavailable = oldGuild.get.unavailable
        guild.afk_timeout = oldGuild.get.afk_timeout
        guild.member_count = oldGuild.get.member_count
        if "owner_id" notin data or data{"owner_id"}.kind == JNull:
            guild.owner_id = oldGuild.get.owner_id

        s.cache.guilds[guild.id] = guild

    s.checkAndCall(deGuildUpdate, guild, oldGuild)

proc guildDelete(s: Shard, data: JsonNode) {.async.} =
    let guild = s.cache.guilds.getOrDefault(data["id"].str, Guild(
        id: data["id"].str
    ))

    guild.unavailable = some data{"unavailable"}.getBool
    s.cache.guilds.del(guild.id)

    s.checkAndCall(deGuildDelete, guild)

proc guildCreate(s: Shard, data: JsonNode) {.async.} =
    let guild = newGuild(data)

    if s.cache.preferences.cache_guilds:
        s.cache.guilds[guild.id] = guild

    if s.cache.preferences.cache_guild_channels:
        for chan in data{"channels"}.getElems:
            chan["guild_id"] = %guild.id

            s.cache.guildChannels[chan["id"].str] = newGuildChannel(chan)

    if s.cache.preferences.cache_users:
        for m in data["members"].elems:
            s.cache.users[m["user"]["id"].str] = newUser(m["user"])

    s.checkAndCall(deGuildCreate, guild)

proc guildRoleCreate(s: Shard, data: JsonNode) {.async.} =
    let
        guild = s.cache.guilds.getOrDefault(data["guild_id"].str,
            Guild(id: data["guild_id"].str)
        )
        role = newRole(data["role"])

    if guild.id in s.cache.guilds:
        guild.roles[role.id] = role

    s.checkAndCall(deGuildRoleCreate, guild, role)

proc guildRoleUpdate(s: Shard, data: JsonNode) {.async.} =
    let
        guild = s.cache.guilds.getOrDefault(data["guild_id"].str,
            Guild(id: data["guild_id"].str)
        )
        role = newRole(data["role"])
    var oldRole: Option[Role]

    if guild.id in s.cache.guilds:
        oldRole = some move guild.roles[role.id]

        guild.roles[role.id] = role

    s.checkAndCall(deGuildRoleUpdate, guild, role, oldRole)

proc guildRoleDelete(s: Shard, data: JsonNode) {.async.} =
    let
        guild = s.cache.guilds.getOrDefault(data["guild_id"].str,
            Guild(id: data["guild_id"].str)
        )
        role = guild.roles.getOrDefault(data["role_id"].str, Role(
            id: data["role_id"].str
        ))

    s.checkAndCall(deGuildRoleDelete, guild, role)

proc renameHook(v: var ModerationAction, fieldName: var string) {.used.} =
    if fieldName == "type":
        fieldName = "kind"

proc autoModerationRuleCreate(s: Shard, data: JsonNode) {.async.} =
    let guild = s.cache.guilds.getOrDefault(data["guild_id"].str,
        Guild(id: data["guild_id"].str)
    )

    let rule = data.`$`.fromJson AutoModerationRule
    s.checkAndCall(deAutoModerationRuleCreate, guild, rule)

proc autoModerationRuleUpdate(s: Shard, data: JsonNode) {.async.} =
    let guild = s.cache.guilds.getOrDefault(data["guild_id"].str,
        Guild(id: data["guild_id"].str)
    )

    let rule = data.`$`.fromJson AutoModerationRule
    s.checkAndCall(deAutoModerationRuleUpdate, guild, rule)

proc autoModerationRuleDelete(s: Shard, data: JsonNode) {.async.} =
    let guild = s.cache.guilds.getOrDefault(data["guild_id"].str,
        Guild(id: data["guild_id"].str)
    )

    let rule = data.`$`.fromJson AutoModerationRule
    s.checkAndCall(deAutoModerationRuleDelete, guild, rule)

proc autoModerationActionExecution(s: Shard, data: JsonNode) {.async.} =
    let guild = s.cache.guilds.getOrDefault(data["guild_id"].str,
        Guild(id: data["guild_id"].str)
    )

    let rule = data.`$`.fromJson ModerationActionExecution
    s.checkAndCall(deAutoModerationActionExecution, guild, rule)

proc webhooksUpdate(s: Shard, data: JsonNode) {.async.} =
    let
        guild = s.cache.guilds.getOrDefault(data["guild_id"].str,
            Guild(id: data["guild_id"].str)
        )
        chan = s.cache.guildChannels.getOrDefault(
            data["channel_id"].str,
            GuildChannel(id: data["channel_id"].str)
        )

    s.checkAndCall(deWebhooksUpdate, guild, chan)

proc inviteDelete(s: Shard, data: JsonNode) {.async.} =
    var guild: Option[Guild]
    if "guild_id" in data and data["guild_id"].kind != JNull:
        guild = some s.cache.guilds.getOrDefault(
            data["guild_id"].str,
            Guild(id: data["guild_id"].str)
        )

    s.checkAndCall(deInviteDelete,guild,data["channel_id"].str,data["code"].str)

proc stageInstanceCreate(s: Shard, data: JsonNode) {.async.} =
    let stage = newStageInstance(data)
    let guild = s.cache.guilds.getOrDefault(
        data["guild_id"].str,
        Guild(id: data["guild_id"].str)
    )
    if s.cache.preferences.cache_guild_channels:
        guild.stage_instances[stage.id] = stage

    s.checkAndCall(deStageInstanceCreate, guild, stage)

proc stageInstanceUpdate(s: Shard, data: JsonNode) {.async.} =
    let
        stage = newStageInstance(data)
        guild = s.cache.guilds.getOrDefault(
            data["guild_id"].str,
            Guild(id: data["guild_id"].str)
        )
    var oldStage: Option[StageInstance]

    if stage.id in guild.stage_instances:
        oldStage = some move guild.stage_instances[stage.id]
        guild.stage_instances[stage.id] = stage

    s.checkAndCall(deStageInstanceUpdate, guild, stage, oldStage)

proc stageInstanceDelete(s: Shard, data: JsonNode) {.async.} =
    let
        stage = newStageInstance(data)
        guild = s.cache.guilds.getOrDefault(
            data["guild_id"].str,
            Guild(id: data["guild_id"].str)
        )
    var exists = false

    if stage.id in guild.stage_instances:
        guild.stage_instances.del(stage.id)
        exists = true

    s.checkAndCall(deStageInstanceDelete, guild, stage, exists)

proc guildScheduledEventUserAdd(s: Shard, data: JsonNode) {.async.} =
    let
        guild = s.cache.guilds.getOrDefault(
            data["guild_id"].str,
            Guild(id: data["guild_id"].str)
        )
        user = s.cache.users.getOrDefault(
            data["user_id"].str,
            User(id: data["user_id"].str)
        )
        event = guild.guild_scheduled_events.getOrDefault(
            data["guild_scheduled_event_id"].str,
            GuildScheduledEvent(id: data["guild_scheduled_event_id"].str),
        )

    s.checkAndCall(deGuildScheduledEventUserAdd, guild, event, user)

proc guildScheduledEventUserRemove(s: Shard, data: JsonNode) {.async.} =
    let
        guild = s.cache.guilds.getOrDefault(
            data["guild_id"].str,
            Guild(id: data["guild_id"].str)
        )
        user = s.cache.users.getOrDefault(
            data["user_id"].str,
            User(id: data["user_id"].str)
        )
        event = guild.guild_scheduled_events.getOrDefault(
            data["guild_scheduled_event_id"].str,
            GuildScheduledEvent(id: data["guild_scheduled_event_id"].str),
        )
    s.checkAndCall(deGuildScheduledEventUserRemove, guild, event, user)

proc guildScheduledEventCreate(s: Shard, data: JsonNode) {.async.} =
    let guild = s.cache.guilds.getOrDefault(
        data["guild_id"].str,
        Guild(id: data["guild_id"].str)
    )

    guild.guild_scheduled_events[
        data["id"].str
    ] = data.`$`.fromJson(GuildScheduledEvent)


    s.checkAndCall(deGuildScheduledEventCreate,
                   guild,
                   guild.guild_scheduled_events[data["id"].str])

proc guildScheduledEventUpdate(s: Shard, data: JsonNode) {.async.} =
    let guild = s.cache.guilds.getOrDefault(
        data["guild_id"].str,
        Guild(id: data["guild_id"].str)
    )

    let
      event = data.`$`.fromJson(GuildScheduledEvent)
      eventID = event.id

    var oldEvent: Option[GuildScheduledEvent]

    if event.id in guild.guild_scheduled_events:
        oldEvent = some move guild.guild_scheduled_events[event.id]

    guild.guild_scheduled_events[event.id] = event

    s.checkAndCall(deGuildScheduledEventUpdate,
                   guild,
                   event,
                   oldEvent)

proc guildScheduledEventDelete(s: Shard, data: JsonNode) {.async.} =
    let guild = s.cache.guilds.getOrDefault(
        data["guild_id"].str,
        Guild(id: data["guild_id"].str)
    )

    if data["id"].str in guild.guild_scheduled_events:
        guild.guild_scheduled_events.del(data["id"].str)

    s.checkAndCall(deGuildScheduledEventDelete,
                   guild,
                   guild.guild_scheduled_events[data["id"].str])

proc threadCreate(s: Shard, data: JsonNode) {.async.} =
    let thread = newGuildChannel(data)
    let guild = s.cache.guilds.getOrDefault(
        data["guild_id"].str,
        Guild(id: data["guild_id"].str)
    )
    if s.cache.preferences.cache_guild_channels:
        s.cache.guildChannels[thread.id] = thread
        guild.threads[thread.id] = thread

    s.checkAndCall(deThreadCreate, guild, thread)

proc threadUpdate(s: Shard, data: JsonNode) {.async.} =
    let
        thread = newGuildChannel(data)
        guild = s.cache.guilds.getOrDefault(
            data["guild_id"].str,
            Guild(id: data["guild_id"].str)
        )
    var oldThread: Option[GuildChannel]

    if thread.id in s.cache.guildChannels:
        oldThread = some move s.cache.guildChannels[thread.id]
        s.cache.guildChannels[thread.id] = thread
        guild.threads[thread.id] = thread

    s.checkAndCall(deThreadUpdate, guild, thread, oldThread)

proc threadDelete(s: Shard, data: JsonNode) {.async.} =
    let
        thread = s.cache.guildChannels.getOrDefault(
            data["id"].str,
            GuildChannel(
                kind: ChannelType(data["type"].getInt(ctGuildText.ord)),
                id: data["id"].str,
                guild_id: data["guild_id"].str,
                parent_id: some data["parent_id"].str,
            )
        )
        guild = s.cache.guilds.getOrDefault(
            data["guild_id"].str,
            Guild(id: data["guild_id"].str)
        )
    var exists = false

    if thread.id in s.cache.guildChannels:
        s.cache.guildChannels.del(thread.id)
        guild.threads.del(thread.id)
        exists = true

    s.checkAndCall(deThreadDelete, guild, thread, exists)

proc threadMembersUpdate(s: Shard, data: JsonNode) {.async.} =
    let e = ThreadMembersUpdate(
        id: data["id"].str,
        guild_id: data["guild_id"].str,
        member_count: data["member_count"].getInt,
        added_members: data{"added_members"}.getElems.mapIt(
            it.`$`.fromJson ThreadMember
        ),
        removed_member_ids: data{"removed_member_ids"}.getElems.mapIt(it.getStr)
    )

    s.checkAndCall(deThreadMembersUpdate, e)

proc voiceServerUpdate(s: Shard, data: JsonNode) {.async.} =
    let guild = s.cache.guilds.getOrDefault(data["guild_id"].str,
        Guild(id: data["guild_id"].str)
    )

    var endpoint: Option[string]
    var initial = true

    if "endpoint" in data and data["endpoint"].kind != JNull:
        endpoint = some data["endpoint"].str
        let exists = guild.id in s.voiceConnections

        if exists:
            let vc = s.voiceConnections[guild.id]
            when defined(dimscordVoice):
                if vc.speaking: initial = false

            if endpoint.get != vc.endpoint:
                if vc.endpoint != "": initial = false
                when defined(dimscordVoice):
                    if vc.speaking:
                        vc.pause()
                        await vc.disconnect(true)

                let v = s.voiceConnections[guild.id]
                v.endpoint = "wss://" & endpoint.get & "/?v=4"
                v.token = data["token"].str

    s.checkAndCall(deVoiceServerUpdate,
                   guild, data["token"].str,
                   endpoint, initial)

proc handleEventDispatch*(s:Shard, event:DispatchEvent, data:JsonNode){.async.} =
    case event:
    of deVoiceStateUpdate: await s.voiceStateUpdate(data)
    of deChannelPinsUpdate: await s.channelPinsUpdate(data)
    of deGuildEmojisUpdate: await s.guildEmojisUpdate(data)
    of deGuildStickersUpdate: await s.guildStickersUpdate(data)
    of dePresenceUpdate: await s.presenceUpdate(data)
    of deMessageCreate: await s.messageCreate(data)
    of deMessageReactionAdd: await s.messageReactionAdd data
    of deMessageReactionRemove: await s.messageReactionRemove data
    of deMessageReactionRemoveEmoji: await s.messageReactionRemoveEmoji data
    of deMessageReactionRemoveAll: await s.messageReactionRemoveAll data
    of deMessageDelete: await s.messageDelete(data)
    of deMessageUpdate: await s.messageUpdate(data)
    of deMessageDeleteBulk: await s.messageDeleteBulk(data)
    of deChannelCreate: await s.channelCreate(data)
    of deChannelUpdate: await s.channelUpdate(data)
    of deChannelDelete: await s.channelDelete(data)
    of deGuildMembersChunk: await s.guildMembersChunk(data)
    of deGuildMemberAdd: await s.guildMemberAdd(data)
    of deGuildMemberUpdate: await s.guildMemberUpdate(data)
    of deGuildMemberRemove: await s.guildMemberRemove(data)
    of deGuildBanAdd: await s.guildBanAdd(data)
    of deGuildBanRemove: await s.guildBanRemove(data)
    of deGuildAuditLogEntryCreate: await s.guildAuditLogEntryCreate(data)
    of deGuildUpdate: await s.guildUpdate(data)
    of deGuildDelete: await s.guildDelete(data)
    of deGuildCreate: await s.guildCreate(data)
    of deGuildRoleCreate: await s.guildRoleCreate(data)
    of deGuildRoleUpdate: await s.guildRoleUpdate(data)
    of deGuildRoleDelete: await s.guildRoleDelete(data)
    of deWebhooksUpdate: await s.webhooksUpdate(data)
    of deTypingStart: s.checkAndCall(deTypingStart, newTypingStart(data))
    of deInviteCreate: s.checkAndCall(deInviteCreate, data.newInviteCreate)
    of deInviteDelete: await s.inviteDelete(data)
    of deGuildIntegrationsUpdate:
        let guild = s.cache.guilds.getOrDefault(data["guild_id"].str,
            Guild(id: data["guild_id"].str)
        )
        s.checkAndCall(deGuildIntegrationsUpdate, guild)
    of deVoiceServerUpdate: await s.voiceServerUpdate(data)
    of deUserUpdate:
        let user = newUser(data)
        s.user = user
        s.checkAndCall(deUserUpdate, user)
    of deInteractionCreate:
        s.checkAndCall(deInteractionCreate, data.newInteraction)
    of deThreadCreate: await s.threadCreate(data)
    of deThreadUpdate: await s.threadUpdate(data)
    of deThreadDelete: await s.threadDelete(data)
    of deThreadListSync:
        s.checkAndCall(deThreadListSync, data.`$`.fromJson(ThreadListSync))
    of deThreadMembersUpdate: await s.threadMembersUpdate(data)
    of deThreadMemberUpdate:
        let guild = s.cache.guilds.getOrDefault(data["guild_id"].str,
            Guild(id: data["guild_id"].str)
        )
        let member = data.`$`.fromJson(ThreadMember)

        s.checkAndCall(deThreadMemberUpdate, guild, member)
    of deStageInstanceCreate: await s.stageInstanceCreate(data)
    of deStageInstanceUpdate: await s.stageInstanceUpdate(data)
    of deStageInstanceDelete: await s.stageInstanceDelete(data)
    of deGuildScheduledEventUserAdd: await s.guildScheduledEventUserAdd data
    of deGuildScheduledEventUserRemove:
        await s.guildScheduledEventUserRemove(data)
    of deGuildScheduledEventCreate: await s.guildScheduledEventCreate data
    of deGuildScheduledEventUpdate: await s.guildScheduledEventUpdate data
    of deGuildScheduledEventDelete: await s.guildScheduledEventDelete data
    of deAutoModerationRuleCreate: await s.autoModerationRuleCreate data
    of deAutoModerationRuleUpdate: await s.autoModerationRuleUpdate data
    of deAutoModerationRuleDelete: await s.autoModerationRuleDelete data
    of deAutoModerationActionExecution:
        await s.autoModerationActionExecution(data)
    of deUnknown: discard
