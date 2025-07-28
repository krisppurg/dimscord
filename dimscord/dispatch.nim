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
        let member = guild.members[voiceState.user_id]
        member.voice_state = some voiceState
        member.mute = voiceState.mute
        member.deaf = voiceState.deaf

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

    s.checkAndCall(VoiceStateUpdate, voiceState, oldVoiceState)

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
    s.checkAndCall(ChannelPinsUpdate, channelID, guild, last_pin)

proc guildEmojisUpdate(s: Shard, data: JsonNode) {.async.} =
    let guild = s.cache.guilds.getOrDefault(data["guild_id"].str,
        Guild(id: data["guild_id"].str)
    )

    var emojis: seq[Emoji] = @[]
    for emoji in data["emojis"]:
        let emji = newEmoji(emoji)
        emojis.add(emji)
        guild.emojis[get emji.id] = emji
    s.checkAndCall(GuildEmojisUpdate, guild, emojis)

proc guildStickersUpdate(s: Shard, data: JsonNode) {.async.} =
    let guild = s.cache.guilds.getOrDefault(data["guild_id"].str,
        Guild(id: data["guild_id"].str)
    )

    var stickers: seq[Sticker] = @[]
    for sticker in data["stickers"]:
        let st = newSticker(sticker)
        stickers.add(st)
        guild.stickers[st.id] = st
    s.checkAndCall(GuildStickersUpdate, guild, stickers)

proc presenceUpdate(s: Shard, data: JsonNode) {.async.} =
    var oldPresence: Option[Presence]
    let presence = newPresence(data)

    if presence.guild_id in s.cache.guilds:
        let guild = s.cache.guilds[presence.guild_id]

        if presence.user.id in guild.presences:
            oldPresence = some move guild.presences[presence.user.id]

        let member = guild.members.getOrDefault(presence.user.id, Member(
            guild_id: presence.guild_id,
            user: User(
                id: data["user"]["id"].str,
            ),
            presence: Presence(
                guild_id: presence.guild_id,
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
    s.checkAndCall(PresenceUpdate, presence, oldPresence)

proc messageCreate(s: Shard, data: JsonNode) {.async.} =
    var msg = newMessage(data)

    if msg.guild_id.isSome and msg.member.isSome:
        msg.member.get.guild_id = get msg.guild_id

    if msg.channel_id in s.cache.guildChannels:
        let chan = s.cache.guildChannels[msg.channel_id]

        asyncCheck chan.addMsg(msg, $data, s.cache.preferences)
        chan.last_message_id = msg.id
        s.cache.guild(chan).channels[chan.id] = chan # because it's updated.

    elif msg.channel_id in s.cache.dmChannels:
        let chan = s.cache.dmChannels[msg.channel_id]

        asyncCheck chan.addMsg(msg, $data, s.cache.preferences)
        chan.last_message_id = msg.id

    s.checkAndCall(MessageCreate, msg)

proc messageReactionAdd(s: Shard, data: JsonNode) {.async.} =
    var
        msg = Message(
            id: data["message_id"].str,
            channel_id: data["channel_id"].str)
        user = s.cache.users.getOrDefault(data["user_id"].str,
            User(id: data["user_id"].str)
        )

        emoji = newEmoji(data["emoji"])
        reaction = Reaction(
            emoji: emoji,
            kind: some ReactionType data["type"].getInt,
            reacted: data["user_id"].str == s.user.id,
            burst: data["burst"].getBool,
        )
        exists = false

    if "message_author_id" in data:
        msg.author = s.cache.users.getOrDefault(
            data["message_author_id"].str,
            User(id: data["message_author_id"].str)
        )

    if msg.channel_id in s.cache.guildChannels:
        let chan = s.cache.gchannel(msg)

        if msg.id in chan.messages:
            msg = chan.messages[msg.id]
            exists = true
    elif msg.channel_id in s.cache.dmChannels:
        let chan = s.cache.dm(msg)

        if msg.id in chan.messages:
            msg = chan.messages[msg.id]
            exists = true

    if "guild_id" in data and data["guild_id"].kind != JNull:
        msg.guild_id = some data["guild_id"].str

        if msg.member.isSome: msg.member.get.guild_id = get msg.guild_id

    if $emoji in msg.reactions:
        reaction.count = msg.reactions[$emoji].count + 1
    else:
        reaction.count += 1

    reaction.me_burst = reaction.reacted and reaction.burst

    if "burst_colors" in data:
        reaction.burst_colors=data["burst_colors"].getElems.mapIt(it.getStr)

    msg.reactions[$emoji] = reaction

    s.checkAndCall(MessageReactionAdd, msg, user, emoji, exists)

proc messageReactionRemove(s: Shard, data: JsonNode) {.async.} =
    let emoji = newEmoji(data["emoji"])
    var
        msg = Message(
            id: data["message_id"].str,
            channel_id: data["channel_id"].str)

        user = s.cache.users.getOrDefault(data["user_id"].str,
            User(id: data["user_id"].str)
        )

        reaction = Reaction(
            emoji: emoji,
            kind: some data["type"].getInt.ReactionType,
            burst: data["burst"].getBool
        )
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

    if "guild_id" in data and data["guild_id"].kind != JNull:
        msg.guild_id = some data["guild_id"].str
        if msg.member.isSome: msg.member.get.guild_id = get msg.guild_id

    if $emoji in msg.reactions and msg.reactions[$emoji].count > 1:
        reaction.count = msg.reactions[$emoji].count - 1

        if data["user_id"].str == s.user.id:
            reaction.reacted = false
            if reaction.burst: reaction.me_burst = false

        msg.reactions[$emoji] = reaction
    else:
        msg.reactions.del($emoji)

    s.checkAndCall(MessageReactionRemove, msg, user, reaction, exists)

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

    if "guild_id" in data and data["guild_id"].kind != JNull:
        msg.guild_id = some data["guild_id"].str
        if msg.member.isSome: msg.member.get.guild_id = get msg.guild_id

    msg.reactions.del($emoji)
    s.checkAndCall(MessageReactionRemoveEmoji, msg, emoji, exists)

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

    if "guild_id" in data and data["guild_id"].kind != JNull:
        msg.guild_id = some data["guild_id"].str
        if msg.member.isSome: msg.member.get.guild_id = get msg.guild_id

    if msg.reactions.len > 0:
        msg.reactions.clear()

    s.checkAndCall(MessageReactionRemoveAll, msg, exists)

proc messageDelete(s: Shard, data: JsonNode) {.async.} =
    var
        msg = Message(
            id: data["id"].str,
            channel_id: data["channel_id"].str)
        exists = false

    if "guild_id" in data and data["guild_id"].kind != JNull:
        msg.guild_id = some data["guild_id"].str
        if msg.member.isSome: msg.member.get.guild_id = get msg.guild_id

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
    s.checkAndCall(MessageDelete, msg, exists)

proc messageUpdate(s: Shard, data: JsonNode) {.async.} =
    var
        msg = data.newMessage
        oldMessage: Option[Message]
        exists = false

    if msg.channel_id in s.cache.guildChannels:
        let chan = s.cache.guildChannels[msg.channel_id]

        if msg.id in chan.messages:
            oldMessage = some move chan.messages[msg.id]
            chan.messages[msg.id] = msg
            exists = true
    elif msg.channel_id in s.cache.dmChannels:
        let chan = s.cache.dmChannels[msg.channel_id]

        if msg.id in chan.messages:
            oldMessage = some move chan.messages[msg.id]
            chan.messages[msg.id] = msg
            exists = true

    s.checkAndCall(MessageUpdate, msg, oldMessage, exists)

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

    s.checkAndCall(MessageDeleteBulk, mids)

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
    s.checkAndCall(ChannelCreate, guild, chan, dmChan)

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

    s.checkAndCall(ChannelUpdate, guild, gchan, oldChan)

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

    s.checkAndCall(ChannelDelete, guild, gc, dm)

proc guildMembersChunk(s: Shard, data: JsonNode) {.async.} =
    let guild = s.cache.guilds.getOrDefault(data["guild_id"].str,
        Guild(id: data["guild_id"].str)
    )
    let cacheuser = s.cache.preferences.cache_users

    for member in data["members"].elems:
        member["guild_id"] = data["guild_id"]
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

    s.checkAndCall(GuildMemberAdd, guild, member)

proc guildMemberUpdate(s: Shard, data: JsonNode) {.async.} =
    let
        guild = s.cache.guilds.getOrDefault(data["guild_id"].str,
            Guild(id: data["guild_id"].str)
        )

    var member = data.newMember
    var oldMember: Option[Member]

    if s.cache.preferences.cache_users and member.user.id notin s.cache.users:
        s.cache.users[member.user.id] = member.user

    if member.user.id in guild.members:
        oldMember = some move guild.members[member.user.id]

        if "mute" notin data:
            member.mute = oldMember.get.mute
        if "deaf" notin data:
            member.deaf = oldMember.get.deaf
        if "flags" notin data:
            member.flags = oldMember.get.flags
        if "permissions" notin data:
            member.permissions = oldMember.get.permissions
        member.presence = oldMember.get.presence
        member.voice_state = oldMember.get.voice_state
        # these are the ones that should be kept unchanged and not defaulted
        # I noticed that the raw json data includes the stuff that we need to know
        # but doesnt include the stuff that we may already know e.g. mute/deaf

        guild.members[member.user.id] = member

    s.checkAndCall(GuildMemberUpdate, guild, member, oldMember)

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

    s.checkAndCall(GuildMemberRemove, guild, member)

proc guildBanAdd(s: Shard, data: JsonNode) {.async.} =
    let
        guild = s.cache.guilds.getOrDefault(data["guild_id"].str,
            Guild(id: data["guild_id"].str)
        )
        user = newUser(data["user"])

    s.checkAndCall(GuildBanAdd, guild, user)

proc guildBanRemove(s: Shard, data: JsonNode) {.async.} =
    let
        guild = s.cache.guilds.getOrDefault(data["guild_id"].str,
            Guild(id: data["guild_id"].str)
        )
        user = newUser(data["user"])

    s.checkAndCall(GuildBanRemove, guild, user)

proc guildAuditLogEntryCreate(s: Shard, data: JsonNode) {.async.} =
    let
        guild = s.cache.guilds.getOrDefault(data["guild_id"].str,
            Guild(id: data["guild_id"].str)
        )
        entry = newAuditLogEntry(data)

    s.checkAndCall(GuildAuditLogEntryCreate, guild, entry)

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

    s.checkAndCall(GuildUpdate, guild, oldGuild)

proc guildDelete(s: Shard, data: JsonNode) {.async.} =
    let guild = s.cache.guilds.getOrDefault(data["id"].str, Guild(
        id: data["id"].str
    ))

    guild.unavailable = some data{"unavailable"}.getBool
    s.cache.guilds.del(guild.id)

    s.checkAndCall(GuildDelete, guild)

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
            data["guild_id"] = %*guild.id
            s.cache.users[m["user"]["id"].str] = newUser(m["user"])

    s.checkAndCall(GuildCreate, guild)

proc guildRoleCreate(s: Shard, data: JsonNode) {.async.} =
    let
        guild = s.cache.guilds.getOrDefault(data["guild_id"].str,
            Guild(id: data["guild_id"].str)
        )
        role = newRole(data["role"])

    if guild.id in s.cache.guilds:
        guild.roles[role.id] = role

    s.checkAndCall(GuildRoleCreate, guild, role)

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

    s.checkAndCall(GuildRoleUpdate, guild, role, oldRole)

proc guildRoleDelete(s: Shard, data: JsonNode) {.async.} =
    let
        guild = s.cache.guilds.getOrDefault(data["guild_id"].str,
            Guild(id: data["guild_id"].str)
        )
        role = guild.roles.getOrDefault(data["role_id"].str, Role(
            id: data["role_id"].str
        ))

    s.checkAndCall(GuildRoleDelete, guild, role)

proc renameHook(v: var ModerationAction, fieldName: var string) {.used.} =
    if fieldName == "type":
        fieldName = "kind"

proc autoModerationRuleCreate(s: Shard, data: JsonNode) {.async.} =
    let guild = s.cache.guilds.getOrDefault(data["guild_id"].str,
        Guild(id: data["guild_id"].str)
    )

    let rule = data.`$`.fromJson AutoModerationRule
    s.checkAndCall(AutoModerationRuleCreate, guild, rule)

proc autoModerationRuleUpdate(s: Shard, data: JsonNode) {.async.} =
    let guild = s.cache.guilds.getOrDefault(data["guild_id"].str,
        Guild(id: data["guild_id"].str)
    )

    let rule = data.`$`.fromJson AutoModerationRule
    s.checkAndCall(AutoModerationRuleUpdate, guild, rule)

proc autoModerationRuleDelete(s: Shard, data: JsonNode) {.async.} =
    let guild = s.cache.guilds.getOrDefault(data["guild_id"].str,
        Guild(id: data["guild_id"].str)
    )

    let rule = data.`$`.fromJson AutoModerationRule
    s.checkAndCall(AutoModerationRuleDelete, guild, rule)

proc autoModerationActionExecution(s: Shard, data: JsonNode) {.async.} =
    let guild = s.cache.guilds.getOrDefault(data["guild_id"].str,
        Guild(id: data["guild_id"].str)
    )

    let rule = data.`$`.fromJson ModerationActionExecution
    s.checkAndCall(AutoModerationActionExecution, guild, rule)

proc webhooksUpdate(s: Shard, data: JsonNode) {.async.} =
    let
        guild = s.cache.guilds.getOrDefault(data["guild_id"].str,
            Guild(id: data["guild_id"].str)
        )
        chan = s.cache.guildChannels.getOrDefault(
            data["channel_id"].str,
            GuildChannel(id: data["channel_id"].str, guild_id: guild.id)
        )

    s.checkAndCall(WebhooksUpdate, guild, chan)

proc inviteDelete(s: Shard, data: JsonNode) {.async.} =
    var guild: Option[Guild]
    if "guild_id" in data and data["guild_id"].kind != JNull:
        guild = some s.cache.guilds.getOrDefault(
            data["guild_id"].str,
            Guild(id: data["guild_id"].str)
        )

    s.checkAndCall(InviteDelete, guild, data["channel_id"].str, data["code"].str)

proc stageInstanceCreate(s: Shard, data: JsonNode) {.async.} =
    let stage = newStageInstance(data)
    let guild = s.cache.guilds.getOrDefault(
        data["guild_id"].str,
        Guild(id: data["guild_id"].str)
    )
    if s.cache.preferences.cache_guild_channels:
        guild.stage_instances[stage.id] = stage

    s.checkAndCall(StageInstanceCreate, guild, stage)

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

    s.checkAndCall(StageInstanceUpdate, guild, stage, oldStage)

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

    s.checkAndCall(StageInstanceDelete, guild, stage, exists)

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

    s.checkAndCall(GuildScheduledEventUserAdd, guild, event, user)

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
    s.checkAndCall(GuildScheduledEventUserRemove, guild, event, user)

proc guildScheduledEventCreate(s: Shard, data: JsonNode) {.async.} =
    let guild = s.cache.guilds.getOrDefault(
        data["guild_id"].str,
        Guild(id: data["guild_id"].str)
    )

    guild.guild_scheduled_events[
        data["id"].str
    ] = data.`$`.fromJson(GuildScheduledEvent)


    s.checkAndCall(GuildScheduledEventCreate,
                   guild,
                   guild.guild_scheduled_events[data["id"].str])

proc guildScheduledEventUpdate(s: Shard, data: JsonNode) {.async.} =
    let guild = s.cache.guilds.getOrDefault(
        data["guild_id"].str,
        Guild(id: data["guild_id"].str)
    )

    let
      event = data.`$`.fromJson(GuildScheduledEvent)

    var oldEvent: Option[GuildScheduledEvent]

    if event.id in guild.guild_scheduled_events:
        oldEvent = some move guild.guild_scheduled_events[event.id]

    guild.guild_scheduled_events[event.id] = event

    s.checkAndCall(GuildScheduledEventUpdate,
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

    s.checkAndCall(GuildScheduledEventDelete,
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

    s.checkAndCall(ThreadCreate, guild, thread)

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

    s.checkAndCall(ThreadUpdate, guild, thread, oldThread)

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

    s.checkAndCall(ThreadDelete, guild, thread, exists)

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
                        await vc.pause()
                        await vc.disconnect(true)

                let v = s.voiceConnections[guild.id]
                v.endpoint = "wss://" & endpoint.get & "/?v=4"
                v.token = data["token"].str

    s.checkAndCall(VoiceServerUpdate,
                   guild, data["token"].str,
                   endpoint, initial)

proc messagePollVoteAdd(s: Shard, data: JsonNode) {.async.} =
    var
        gc: GuildChannel = nil
        dm: DMChannel = nil
        user = s.cache.users.getOrDefault(data["user_id"].str,
            User(id: data["user_id"].str))
        msg = Message(id: data["message_id"].str,
                      channel_id: data["channel_id"].str)
        counts: seq[PollAnswerCount] = @[]

    if "guild_id" in data:
        let guild = s.cache.guilds.getOrDefault(data["guild_id"].str,
            Guild(id: data["guild_id"].str)
        )
        msg.guild_id = some guild.id

        if msg.channel_id in guild.channels:
            gc = guild.channels[msg.channel_id]
            if msg.id in gc.messages:
                msg = gc.messages[msg.id]
                counts = msg.poll.get.results.get(PollResults()).answer_counts

    elif msg.channel_id in s.cache.dmChannels:
        dm = s.cache.dmchannels[msg.channel_id]
        msg = dm.messages.getOrDefault(msg.id, msg)

        counts = msg.poll.get.results.get(PollResults()).answer_counts

    for ac in counts:
        if ac.id != data["answer_id"].getInt: continue
        ac.count += 1
        ac.me_voted = user.id == s.user.id

    if msg.poll.isSome: # just fyi, it will always be true for cached messages only both dm and guild.
        if gc != nil:
            gc.messages[msg.id] = msg
            s.cache.gchannel(msg).messages[msg.id] = msg
        else:
            dm.messages[msg.id] = msg

    s.checkAndCall(MessagePollVoteAdd, msg, user, data["answer_id"].getInt)

proc messagePollVoteRemove(s: Shard, data: JsonNode) {.async.} =
    var
        gc: GuildChannel = nil
        dm: DMChannel = nil
        user = s.cache.users.getOrDefault(data["user_id"].str,
            User(id: data["user_id"].str))
        msg = Message(id: data["message_id"].str,
                      channel_id: data["channel_id"].str)
        counts: seq[PollAnswerCount] = @[]

    if "guild_id" in data:
        let guild = s.cache.guilds.getOrDefault(data["guild_id"].str,
            Guild(id: data["guild_id"].str)
        )
        msg.guild_id = some guild.id

        if msg.channel_id in guild.channels:
            gc = guild.channels[msg.channel_id]
            msg = gc.messages.getOrDefault(msg.id, msg)
            counts = msg.poll.get.results.get(PollResults()).answer_counts

    elif msg.channel_id in s.cache.dmChannels:
        dm = s.cache.dmchannels[msg.channel_id]
        msg = dm.messages.getOrDefault(msg.id, msg)

        counts = msg.poll.get.results.get(PollResults()).answer_counts

    for ac in counts:
        if ac.id != data["answer_id"].getInt: continue
        if ac.count != 0: ac.count -= 1
        ac.me_voted = user.id == s.user.id

    if msg.poll.isSome:
        if gc != nil:
            gc.messages[msg.id] = msg
            s.cache.gchannel(msg).messages[msg.id] = msg
        else:
            dm.messages[msg.id] = msg

    s.checkAndCall(MessagePollVoteRemove, msg, user, data["answer_id"].getInt)

proc integrationCreate(s: Shard, data: JsonNode) {.async.} =
    let user = newUser(data["user"])
    if user.id in s.cache.users: s.cache.users[user.id] = user
    let guild = s.cache.guilds.getOrDefault(data["guild_id"].str,
        Guild(id: data["guild_id"].str)
    )
    s.checkAndCall(IntegrationCreate, user, guild)

proc integrationUpdate(s: Shard, data: JsonNode) {.async.} =
    let user = newUser(data["user"])
    if user.id in s.cache.users: s.cache.users[user.id] = user
    let guild = s.cache.guilds.getOrDefault(data["guild_id"].str,
        Guild(id: data["guild_id"].str)
    )
    s.checkAndCall(IntegrationUpdate, user, guild)

proc integrationDelete(s: Shard, data: JsonNode) {.async.} =
    var app_id = none(string)
    if "application_id" in data and data["application_id"].kind != JNull:
        app_id = some data["application_id"].str
    let guild = s.cache.guilds.getOrDefault(data["guild_id"].str,
        Guild(id: data["guild_id"].str)
    )
    s.checkAndCall(IntegrationDelete, data["id"].str, guild, app_id)

proc handleEventDispatch*(s:Shard, event:DispatchEvent, data:JsonNode){.async.} =
    case event:
    of VoiceStateUpdate: await s.voiceStateUpdate(data)
    of ChannelPinsUpdate: await s.channelPinsUpdate(data)
    of GuildEmojisUpdate: await s.guildEmojisUpdate(data)
    of GuildStickersUpdate: await s.guildStickersUpdate(data)
    of PresenceUpdate: await s.presenceUpdate(data)
    of MessageCreate: await s.messageCreate(data)
    of MessageReactionAdd: await s.messageReactionAdd data
    of MessageReactionRemove: await s.messageReactionRemove data
    of MessageReactionRemoveEmoji: await s.messageReactionRemoveEmoji data
    of MessageReactionRemoveAll: await s.messageReactionRemoveAll data
    of MessageDelete: await s.messageDelete(data)
    of MessageUpdate: await s.messageUpdate(data)
    of MessageDeleteBulk: await s.messageDeleteBulk(data)
    of ChannelCreate: await s.channelCreate(data)
    of ChannelUpdate: await s.channelUpdate(data)
    of ChannelDelete: await s.channelDelete(data)
    of deGuildMembersChunk: await s.guildMembersChunk(data)
    of GuildMemberAdd: await s.guildMemberAdd(data)
    of GuildMemberUpdate: await s.guildMemberUpdate(data)
    of GuildMemberRemove: await s.guildMemberRemove(data)
    of GuildBanAdd: await s.guildBanAdd(data)
    of GuildBanRemove: await s.guildBanRemove(data)
    of GuildAuditLogEntryCreate: await s.guildAuditLogEntryCreate(data)
    of GuildUpdate: await s.guildUpdate(data)
    of GuildDelete: await s.guildDelete(data)
    of GuildCreate: await s.guildCreate(data)
    of GuildRoleCreate: await s.guildRoleCreate(data)
    of GuildRoleUpdate: await s.guildRoleUpdate(data)
    of GuildRoleDelete: await s.guildRoleDelete(data)
    of WebhooksUpdate: await s.webhooksUpdate(data)
    of deTypingStart:
        if "member" in data and data["member"].kind != JNull:
            data["member"]["guild_id"] = data["guild_id"]
        s.checkAndCall(deTypingStart, newTypingStart(data))
    of deInviteCreate: s.checkAndCall(deInviteCreate, data.newInviteCreate)
    of InviteDelete: await s.inviteDelete(data)
    of GuildIntegrationsUpdate:
        let guild = s.cache.guilds.getOrDefault(data["guild_id"].str,
            Guild(id: data["guild_id"].str)
        )
        s.checkAndCall(GuildIntegrationsUpdate, guild)
    of VoiceServerUpdate: await s.voiceServerUpdate(data)
    of UserUpdate:
        let user = newUser(data)
        s.user = user
        s.checkAndCall(UserUpdate, user)
    of InteractionCreate:
        s.checkAndCall(InteractionCreate, data.newInteraction)
    of ThreadCreate: await s.threadCreate(data)
    of ThreadUpdate: await s.threadUpdate(data)
    of ThreadDelete: await s.threadDelete(data)
    of deThreadListSync:
        s.checkAndCall(
          deThreadListSync,
          data.`$`.fromJson(objects.ThreadListSync))
    of deThreadMembersUpdate: await s.threadMembersUpdate(data)
    of ThreadMemberUpdate:
        let guild = s.cache.guilds.getOrDefault(data["guild_id"].str,
            Guild(id: data["guild_id"].str)
        )
        let member = data.`$`.fromJson(ThreadMember)

        s.checkAndCall(ThreadMemberUpdate, guild, member)
    of StageInstanceCreate: await s.stageInstanceCreate(data)
    of StageInstanceUpdate: await s.stageInstanceUpdate(data)
    of StageInstanceDelete: await s.stageInstanceDelete(data)
    of GuildScheduledEventUserAdd: await s.guildScheduledEventUserAdd data
    of GuildScheduledEventUserRemove:
        await s.guildScheduledEventUserRemove(data)
    of GuildScheduledEventCreate: await s.guildScheduledEventCreate data
    of GuildScheduledEventUpdate: await s.guildScheduledEventUpdate data
    of GuildScheduledEventDelete: await s.guildScheduledEventDelete data
    of AutoModerationRuleCreate: await s.autoModerationRuleCreate data
    of AutoModerationRuleUpdate: await s.autoModerationRuleUpdate data
    of AutoModerationRuleDelete: await s.autoModerationRuleDelete data
    of AutoModerationActionExecution:
        await s.autoModerationActionExecution(data)
    of MessagePollVoteAdd: await s.messagePollVoteAdd(data)
    of MessagePollVoteRemove: await s.messagePollVoteRemove(data)
    of IntegrationCreate: await s.integrationCreate(data)
    of IntegrationUpdate: await s.integrationUpdate(data)
    of IntegrationDelete: await s.integrationDelete(data)
    of EntitlementCreate:
        s.checkAndCall(EntitlementCreate, newEntitlement(data))
    of EntitlementUpdate:
        s.checkAndCall(EntitlementUpdate, newEntitlement(data))
    of EntitlementDelete:
        s.checkAndCall(EntitlementDelete, newEntitlement(data))
    of Unknown: discard
