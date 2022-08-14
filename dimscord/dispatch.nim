import objects, constants
import options, json, asyncdispatch
import sequtils, tables, jsony, macros

when (NimMajor, NimMinor, NimPatch) >= (1, 6, 0):
    {.warning[HoleEnumConv]: off.}
    {.warning[CaseTransition]: off.}

when defined(dimscordVoice):
    from voice import pause, disconnect

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

    asyncCheck s.client.events.voice_state_update(s, voiceState,
        oldVoiceState)

proc channelPinsUpdate(s: Shard, data: JsonNode) {.async.} =
    var
        guild: Option[Guild]
        last_pin: Option[string]

    if "last_pin_timestamp" in data:
        last_pin = some data["last_pin_timestamp"].str

    if "guild_id" in data:
        guild = some Guild(id: data["guild_id"].str)
        if guild.get.id in s.cache.guilds:
            guild = some s.cache.guilds[data["guild_id"].str]

    asyncCheck s.client.events.channel_pins_update(s,
        data["channel_id"].str, guild, last_pin)

proc guildEmojisUpdate(s: Shard, data: JsonNode) {.async.} =
    let guild = s.cache.guilds.getOrDefault(data["guild_id"].str,
        Guild(id: data["guild_id"].str)
    )

    var emojis: seq[Emoji] = @[]
    for emoji in data["emojis"]:
        let emji = newEmoji(emoji)
        emojis.add(emji)
        guild.emojis[get emji.id] = emji

    asyncCheck s.client.events.guild_emojis_update(s, guild, emojis)

proc guildStickersUpdate(s: Shard, data: JsonNode) {.async.} =
    let guild = s.cache.guilds.getOrDefault(data["guild_id"].str,
        Guild(id: data["guild_id"].str)
    )

    var stickers: seq[Sticker] = @[]
    for sticker in data["stickers"]:
        let st = newSticker(sticker)
        stickers.add(st)
        guild.stickers[st.id] = st

    asyncCheck s.client.events.guild_stickers_update(s, guild, stickers)

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

        asyncCheck s.client.events.presence_update(s, presence, oldPresence)

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

    asyncCheck s.client.events.message_create(s, msg)

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

    asyncCheck s.client.events.message_reaction_add(s, msg, user, emoji, exists)

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

    asyncCheck s.client.events.message_reaction_remove(s, msg, user,
        reaction, exists)

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

    asyncCheck s.client.events.message_reaction_remove_emoji(s, msg, emoji, exists)

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

    asyncCheck s.client.events.message_reaction_remove_all(s, msg, exists)

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

    asyncCheck s.client.events.message_delete(s, msg, exists)

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

    asyncCheck s.client.events.message_update(s, msg, oldMessage, exists)

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

    asyncCheck s.client.events.message_delete_bulk(s, mids)

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

    asyncCheck s.client.events.channel_create(s, guild, chan, dmChan)

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

    asyncCheck s.client.events.channel_update(s, guild, gchan, oldChan)

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

    asyncCheck s.client.events.channel_delete(s, guild, gc, dm)

proc guildMembersChunk(s: Shard, data: JsonNode) {.async.} =
    let guild = s.cache.guilds.getOrDefault(data["guild_id"].str,
        Guild(id: data["guild_id"].str)
    )

    for member in data["members"].elems:
        if member["user"]["id"].str notin guild.members:
            guild.members[member["user"]["id"].str] = newMember(member)

            s.cache.users[member["user"]["id"].str] = newUser(member["user"])

    asyncCheck s.client.events.guild_members_chunk(s, guild,
        newGuildMembersChunk(data))

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

    asyncCheck s.client.events.guild_member_add(s, guild, member)

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

    asyncCheck s.client.events.guild_member_update(s, guild, member, oldMember)

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

    asyncCheck s.client.events.guild_member_remove(s, guild, member)

proc guildBanAdd(s: Shard, data: JsonNode) {.async.} =
    let
        guild = s.cache.guilds.getOrDefault(data["guild_id"].str,
            Guild(id: data["guild_id"].str)
        )
        user = newUser(data["user"])

    asyncCheck s.client.events.guild_ban_add(s, guild, user)

proc guildBanRemove(s: Shard, data: JsonNode) {.async.} =
    let
        guild = s.cache.guilds.getOrDefault(data["guild_id"].str,
            Guild(id: data["guild_id"].str)
        )
        user = newUser(data["user"])

    asyncCheck s.client.events.guild_ban_remove(s, guild, user)

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

    asyncCheck s.client.events.guild_update(s, guild, oldGuild)

proc guildDelete(s: Shard, data: JsonNode) {.async.} =
    let guild = s.cache.guilds.getOrDefault(data["id"].str, Guild(
        id: data["id"].str
    ))

    guild.unavailable = some data{"unavailable"}.getBool
    s.cache.guilds.del(guild.id)

    asyncCheck s.client.events.guild_delete(s, guild)

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

    asyncCheck s.client.events.guild_create(s, guild)

proc guildRoleCreate(s: Shard, data: JsonNode) {.async.} =
    let
        guild = s.cache.guilds.getOrDefault(data["guild_id"].str,
            Guild(id: data["guild_id"].str)
        )
        role = newRole(data["role"])

    if guild.id in s.cache.guilds:
        guild.roles[role.id] = role

    asyncCheck s.client.events.guild_role_create(s, guild, role)

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

    asyncCheck s.client.events.guild_role_update(s, guild, role, oldRole)

proc guildRoleDelete(s: Shard, data: JsonNode) {.async.} =
    let
        guild = s.cache.guilds.getOrDefault(data["guild_id"].str,
            Guild(id: data["guild_id"].str)
        )
        role = guild.roles.getOrDefault(data["role_id"].str, Role(
            id: data["role_id"].str
        ))

    asyncCheck s.client.events.guild_role_delete(s, guild, role)

proc renameHook(v: var ModerationAction, fieldName: var string) {.used.} =
    if fieldName == "type":
        fieldName = "kind"

proc autoModerationRuleCreate(s: Shard, data: JsonNode) {.async.} =
    let guild = s.cache.guilds.getOrDefault(data["guild_id"].str,
        Guild(id: data["guild_id"].str)
    )
    asyncCheck s.client.events.auto_moderation_rule_create(s,
        guild, data.`$`.fromJson AutoModerationRule)

proc autoModerationRuleUpdate(s: Shard, data: JsonNode) {.async.} =
    let guild = s.cache.guilds.getOrDefault(data["guild_id"].str,
        Guild(id: data["guild_id"].str)
    )
    asyncCheck s.client.events.auto_moderation_rule_update(s,
        guild, data.`$`.fromJson AutoModerationRule)

proc autoModerationRuleDelete(s: Shard, data: JsonNode) {.async.} =
    let guild = s.cache.guilds.getOrDefault(data["guild_id"].str,
        Guild(id: data["guild_id"].str)
    )
    asyncCheck s.client.events.auto_moderation_rule_delete(s,
        guild, data.`$`.fromJson AutoModerationRule)

proc autoModerationActionExecution(s: Shard, data: JsonNode) {.async.} =
    let guild = s.cache.guilds.getOrDefault(data["guild_id"].str,
        Guild(id: data["guild_id"].str)
    )
    asyncCheck s.client.events.auto_moderation_action_execution(s,
        guild, data.`$`.fromJson ModerationActionExecution)

proc webhooksUpdate(s: Shard, data: JsonNode) {.async.} =
    let
        guild = s.cache.guilds.getOrDefault(data["guild_id"].str,
            Guild(id: data["guild_id"].str)
        )
        chan = s.cache.guildChannels.getOrDefault(
            data["channel_id"].str,
            GuildChannel(id: data["channel_id"].str)
        )

    asyncCheck s.client.events.webhooks_update(s, guild, chan)

proc inviteDelete(s: Shard, data: JsonNode) {.async.} =
    var guild: Option[Guild]
    if "guild_id" in data and data["guild_id"].kind != JNull:
        guild = some s.cache.guilds.getOrDefault(
            data["guild_id"].str,
            Guild(id: data["guild_id"].str)
        )

    asyncCheck s.client.events.invite_delete(s, guild, data["channel_id"].str,
        data["code"].str)

proc stageInstanceCreate(s: Shard, data: JsonNode) {.async.} =
    let stage = newStageInstance(data)
    let guild = s.cache.guilds.getOrDefault(
        data["guild_id"].str,
        Guild(id: data["guild_id"].str)
    )
    if s.cache.preferences.cache_guild_channels:
        guild.stage_instances[stage.id] = stage
    asyncCheck s.client.events.stage_instance_create(s, guild, stage)

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

    asyncCheck s.client.events.stage_instance_update(s, guild, stage, oldStage)

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

    asyncCheck s.client.events.stage_instance_delete(s, guild, stage, exists)

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
    asyncCheck s.client.events.guild_scheduled_event_user_add(s, guild, event, user)

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
    asyncCheck s.client.events.guild_scheduled_event_user_remove(s, guild, event, user)

proc guildScheduledEventCreate(s: Shard, data: JsonNode) {.async.} =
    let guild = s.cache.guilds.getOrDefault(
        data["guild_id"].str,
        Guild(id: data["guild_id"].str)
    )

    guild.guild_scheduled_events[
        data["id"].str
    ] = data.`$`.fromJson(GuildScheduledEvent)

    asyncCheck s.client.events.guild_scheduled_event_create(s, guild,
        guild.guild_scheduled_events[data["id"].str]
    )

proc guildScheduledEventUpdate(s: Shard, data: JsonNode) {.async.} =
    let guild = s.cache.guilds.getOrDefault(
        data["guild_id"].str,
        Guild(id: data["guild_id"].str)
    )

    guild.guild_scheduled_events[
        data["id"].str
    ] = data.`$`.fromJson(GuildScheduledEvent)

    asyncCheck s.client.events.guild_scheduled_event_create(s, guild,
        guild.guild_scheduled_events[data["id"].str]
    )

proc guildScheduledEventDelete(s: Shard, data: JsonNode) {.async.} =
    let guild = s.cache.guilds.getOrDefault(
        data["guild_id"].str,
        Guild(id: data["guild_id"].str)
    )

    if data["id"].str in guild.guild_scheduled_events:
        guild.guild_scheduled_events.del(data["id"].str)

    asyncCheck s.client.events.guild_scheduled_event_delete(s, guild,
        guild.guild_scheduled_events[data["id"].str]
    )

proc threadCreate(s: Shard, data: JsonNode) {.async.} =
    let thread = newGuildChannel(data)
    let guild = s.cache.guilds.getOrDefault(
        data["guild_id"].str,
        Guild(id: data["guild_id"].str)
    )
    if s.cache.preferences.cache_guild_channels:
        s.cache.guildChannels[thread.id] = thread 
        guild.threads[thread.id] = thread
    asyncCheck s.client.events.thread_create(s, guild, thread)

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

    asyncCheck s.client.events.thread_update(s, guild, thread, oldThread)

proc threadDelete(s: Shard, data: JsonNode) {.async.} =
    let
        thread = s.cache.guildChannels.getOrDefault(
            data["id"].str,
            GuildChannel(
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
    if ChannelType(data["type"].getInt) in ChannelType.fullSet():
        thread.kind = ChannelType data["type"].getInt
    else:
        thread.kind = ctGuildText

    if thread.id in s.cache.guildChannels:
        s.cache.guildChannels.del(thread.id)
        guild.threads.del(thread.id)
        exists = true

    asyncCheck s.client.events.thread_delete(s, guild, thread, exists)

proc threadMembersUpdate(s: Shard, data: JsonNode) {.async.} =
    let e = ThreadMembersUpdate(
        id: data["id"].str,
        guild_id: data["guild_id"].str,
        member_count: data["member_count"].getInt,
        added_members: data{"added_members"}.getElems.map(
            proc (x: JsonNode): ThreadMember =
            x.to(ThreadMember)
        ),
        removed_member_ids: data{"removed_member_ids"}.getElems.mapIt(
            it.getStr
        )
    )
    asyncCheck s.client.events.thread_members_update(s, e)

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

    asyncCheck s.client.events.voice_server_update(s, guild,
        data["token"].str, endpoint, initial)

proc handleEventDispatch*(s: Shard, event: string, data: JsonNode) {.async.} =
    case event:
    of "VOICE_STATE_UPDATE": await s.voiceStateUpdate(data)
    of "CHANNEL_PINS_UPDATE": await s.channelPinsUpdate(data)
    of "GUILD_EMOJIS_UPDATE": await s.guildEmojisUpdate(data)
    of "GUILD_STICKERS_UPDATE": await s.guildStickersUpdate(data)
    of "PRESENCE_UPDATE": await s.presenceUpdate(data)
    of "MESSAGE_CREATE": await s.messageCreate(data)
    of "MESSAGE_REACTION_ADD": await s.messageReactionAdd data
    of "MESSAGE_REACTION_REMOVE": await s.messageReactionRemove data
    of "MESSAGE_REACTION_REMOVE_EMOJI": await s.messageReactionRemoveEmoji data
    of "MESSAGE_REACTION_REMOVE_ALL": await s.messageReactionRemoveAll data
    of "MESSAGE_DELETE": await s.messageDelete(data)
    of "MESSAGE_UPDATE": await s.messageUpdate(data)
    of "MESSAGE_DELETE_BULK": await s.messageDeleteBulk(data)
    of "CHANNEL_CREATE": await s.channelCreate(data)
    of "CHANNEL_UPDATE": await s.channelUpdate(data)
    of "CHANNEL_DELETE": await s.channelDelete(data)
    of "GUILD_MEMBERS_CHUNK": await s.guildMembersChunk(data)
    of "GUILD_MEMBER_ADD": await s.guildMemberAdd(data)
    of "GUILD_MEMBER_UPDATE": await s.guildMemberUpdate(data)
    of "GUILD_MEMBER_REMOVE": await s.guildMemberRemove(data)
    of "GUILD_BAN_ADD": await s.guildBanAdd(data)
    of "GUILD_BAN_REMOVE": await s.guildBanRemove(data)
    of "GUILD_UPDATE": await s.guildUpdate(data)
    of "GUILD_DELETE": await s.guildDelete(data)
    of "GUILD_CREATE": await s.guildCreate(data)
    of "GUILD_ROLE_CREATE": await s.guildRoleCreate(data)
    of "GUILD_ROLE_UPDATE": await s.guildRoleUpdate(data)
    of "GUILD_ROLE_DELETE": await s.guildRoleDelete(data)
    of "WEBHOOKS_UPDATE": await s.webhooksUpdate(data)
    of "TYPING_START":
        asyncCheck s.client.events.typing_start(s, newTypingStart(data))
    of "INVITE_CREATE":
        asyncCheck s.client.events.invite_create(s, newInviteCreate(data))
    of "INVITE_DELETE": await s.inviteDelete(data)
    of "GUILD_INTEGRATIONS_UPDATE":
        let guild = s.cache.guilds.getOrDefault(data["guild_id"].str,
            Guild(id: data["guild_id"].str)
        )
        asyncCheck s.client.events.guild_integrations_update(s, guild)
    of "VOICE_SERVER_UPDATE":
        await s.voiceServerUpdate(data)
    of "USER_UPDATE":
        let user = newUser(data)
        s.user = user
        asyncCheck s.client.events.user_update(s, user)
    of "INTERACTION_CREATE":
        asyncCheck s.client.events.interaction_create(s, newInteraction(data))
    of "THREAD_CREATE": await s.threadCreate(data)
    of "THREAD_UPDATE": await s.threadUpdate(data)
    of "THREAD_DELETE": await s.threadDelete(data)
    of "THREAD_LIST_SYNC":
        asyncCheck s.client.events.thread_list_sync(s, ThreadListSync(
            channel_ids: data{"channel_ids"}.getElems.mapIt(it.getStr),
            threads: data{"threads"}.getElems.map(newGuildChannel),
            members: data["members"].elems.mapIt(it.`$`.fromJson(ThreadMember))
        ))
    of "THREAD_MEMBERS_UPDATE": await s.threadMembersUpdate(data)
    of "THREAD_MEMBER_UPDATE":
        let guild = s.cache.guilds.getOrDefault(data["guild_id"].str,
            Guild(id: data["guild_id"].str)
        )
        asyncCheck s.client.events.thread_member_update(
            s, guild, data.`$`.fromJson(ThreadMember)
        )
    of "STAGE_INSTANCE_CREATE": await s.stageInstanceCreate(data)
    of "STAGE_INSTANCE_UPDATE": await s.stageInstanceUpdate(data)
    of "STAGE_INSTANCE_DELETE": await s.stageInstanceDelete(data)
    of "GUILD_SCHEDULED_EVENT_USER_ADD": await s.guildScheduledEventUserAdd data
    of "GUILD_SCHEDULED_EVENT_USER_REMOVE": await s.guildScheduledEventUserRemove data
    of "GUILD_SCHEDULED_EVENT_CREATE": await s.guildScheduledEventCreate data
    of "GUILD_SCHEDULED_EVENT_UPDATE": await s.guildScheduledEventUpdate data
    of "GUILD_SCHEDULED_EVENT_DELETE": await s.guildScheduledEventDelete data
    of "AUTO_MODERATION_RULE_CREATE": await s.autoModerationRuleCreate data
    of "AUTO_MODERATION_RULE_UPDATE": await s.autoModerationRuleUpdate data
    of "AUTO_MODERATION_RULE_DELETE": await s.autoModerationRuleDelete data
    of "AUTO_MODERATION_ACTION_EXECUTION":
        await s.autoModerationActionExecution data
    else:
        discard