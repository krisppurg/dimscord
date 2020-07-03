import objects, options, json, asyncdispatch, tables, constants

proc addMsg(gc: GuildChannel, m: Message) {.async.} =
    gc.messages.add(m.id, m)
    await sleepAsync 120_000
    gc.messages.del(m.id)

proc addMsg(dc: DMChannel, m: Message) {.async.} =
    dc.messages.add(m.id, m)
    await sleepAsync 120_000
    dc.messages.del(m.id)

proc voiceStateUpdate(s: Shard, data: JsonNode) {.async.} =
    let guild = s.cache.guilds.getOrDefault(data["guild_id"].str,
        Guild(id: data["guild_id"].str)
    )
    let voiceState = newVoiceState(data)
    var oldVoiceState: Option[VoiceState]

    if guild.id in s.cache.guilds and voiceState.user_id in guild.members:
        guild.members[voiceState.user_id].voice_state = some voiceState

        if guild.voice_states.hasKeyOrPut(voiceState.user_id, voiceState):
            when declared(deepCopy):
                oldVoiceState = some deepCopy guild.voice_states[voiceState.user_id]
            guild.voice_states[voiceState.user_id] = voiceState

    await s.client.events.voice_state_update(s, voiceState,
        oldVoiceState)

proc channelPinsUpdate(s: Shard, data: JsonNode) {.async.} =
    var guild: Option[Guild]
    var last_pin: Option[string]

    if "last_pin_timestamp" in data:
        last_pin = some data["last_pin_timestamp"].str

    if "guild_id" in data:
        guild = some Guild(id: data["guild_id"].str)
        if guild.get.id in s.cache.guilds:
            guild = some s.cache.guilds[data["guild_id"].str]

    await s.client.events.channel_pins_update(s,
        data["channel_id"].str, guild, last_pin)

proc guildEmojisUpdate(s: Shard, data: JsonNode) {.async.} =
    let guild = s.cache.guilds.getOrDefault(data["guild_id"].str,
        Guild(id: data["guild_id"].str)
    )

    var emojis: seq[Emoji] = @[]
    for emoji in data["emojis"]:
        let emji = newEmoji(emoji)
        emojis.add(emji)
        guild.emojis.clear()
        guild.emojis.add(emji.id, emji)

    await s.client.events.guild_emojis_update(s, guild, emojis)

proc presenceUpdate(s: Shard, data: JsonNode) {.async.} =
    var oldPresence: Option[Presence]
    let presence = newPresence(data)

    if presence.guild_id in s.cache.guilds:
        let guild = s.cache.guilds[presence.guild_id]

        if presence.user.id in guild.presences:
            when declared(deepCopy):
                oldPresence = some deepCopy guild.presences[presence.user.id]

        let member = guild.members.getOrDefault(presence.user.id, Member(
            user: User(
                id: data["user"]["id"].str
            )
        ))
        let offline = member.presence.status in ["offline", ""]

        if presence.status == "offline":
            guild.presences.del(presence.user.id)
        elif offline and presence.status != "offline":
            guild.presences.add(presence.user.id, presence)

        if presence.user.id in guild.presences:
            guild.presences[presence.user.id] = presence

        member.presence = presence

        await s.client.events.presence_update(s, presence, oldPresence)

proc messageCreate(s: Shard, data: JsonNode) {.async.} =
    let msg = newMessage(data)

    if msg.channel_id in s.cache.guildChannels:
        let chan = s.cache.guildChannels[msg.channel_id]

        asyncCheck chan.addMsg(msg)
        chan.last_message_id = msg.id

    elif msg.channel_id in s.cache.dmChannels:
        let chan = s.cache.dmChannels[msg.channel_id]

        asyncCheck chan.addMsg(msg)
        chan.last_message_id = msg.id

    await s.client.events.message_create(s, msg)

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
        msg.reactions.add($emoji, reaction)

    await s.client.events.message_reaction_add(s, msg, user, reaction, exists)

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

    await s.client.events.message_reaction_remove(s, msg, user,
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

    await s.client.events.message_reaction_remove_emoji(s, msg, emoji, exists)

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

    await s.client.events.message_reaction_remove_all(s, msg, exists)

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

        chan.messages.del(msg.id)

        if msg.id in chan.messages:
            msg = chan.messages[msg.id]

            if chan.last_message_id == msg.id:
                chan.last_message_id = ""

            exists = true
    elif msg.channel_id in s.cache.dmChannels:
        let chan = s.cache.dmChannels[msg.channel_id]

        chan.messages.del(msg.id)

        if msg.id in chan.messages:
            msg = chan.messages[msg.id]

            if chan.last_message_id == msg.id:
                chan.last_message_id = ""

            exists = true

    await s.client.events.message_delete(s, msg, exists)

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
            when declared(deepCopy):
                oldMessage = some deepCopy chan.messages[msg.id]
            msg = chan.messages[msg.id].updateMessage(data)
    elif msg.channel_id in s.cache.dmChannels:
        let chan = s.cache.dmChannels[msg.channel_id]

        if msg.id in chan.messages:
            when declared(deepCopy):
                oldMessage = some deepCopy chan.messages[msg.id]
            msg = chan.messages[msg.id].updateMessage(data)
    else:
        msg = msg.updateMessage(data)

    await s.client.events.message_update(s, msg, oldMessage, exists)

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

        mids.add((msg: m,
            exists: exists))

    await s.client.events.message_delete_bulk(s, mids)

proc channelCreate(s: Shard, data: JsonNode) {.async.} =
    var
        guild: Option[Guild]
        chan: Option[GuildChannel]
        dmChan: Option[DMChannel]

    if data["type"].getInt != ctDirect:
        guild = some Guild(id: data["guild_id"].str)

        if guild.get.id in s.cache.guilds:
            guild = some s.cache.guilds[guild.get.id]

        chan = some newGuildChannel(data)

        if s.cache.preferences.cache_guild_channels:
            s.cache.guildChannels.add(chan.get.id, chan.get)
            guild.get.channels.add(chan.get.id, chan.get)
    elif data["id"].str notin s.cache.dmChannels:
        dmChan = some newDMChannel(data)
        if s.cache.preferences.cache_dm_channels:
            s.cache.dmChannels.add(data["id"].str, dmChan.get)

    await s.client.events.channel_create(s, guild, chan, dmChan)

proc channelUpdate(s: Shard, data: JsonNode) {.async.} =
    let gchan = newGuildChannel(data)
    var oldChan: Option[GuildChannel]

    let guild = s.cache.guilds.getOrDefault(data["guild_id"].str,
        Guild(id: data["guild_id"].str)
    )

    if gchan.id in s.cache.guildChannels:
        when declared(deepCopy):
            oldChan = some deepCopy guild.channels[gchan.id]
        guild.channels[gchan.id] = gchan
        s.cache.guildChannels[gchan.id] = gchan

    await s.client.events.channel_update(s, guild, gchan, oldChan)

proc channelDelete(s: Shard, data: JsonNode) {.async.} =
    var
        guild: Option[Guild]
        gc: Option[GuildChannel]
        dm: Option[DMChannel]

    if "guild_id" in data:
        guild = some Guild(id: data["guild_id"].str)
        if guild.get.id in s.cache.guilds:
            guild = some s.cache.guilds[guild.get.id]

    if data["id"].str in s.cache.guildChannels:
        gc = some newGuildChannel(data)

        if guild.get.id in s.cache.guilds:
            guild.get.channels.del(gc.get.id)

        s.cache.guildChannels.del(gc.get.id)
    elif data["id"].str in s.cache.dmChannels:
        dm = some newDMChannel(data)
        s.cache.dmChannels.del(dm.get.id)

    await s.client.events.channel_delete(s, guild, gc, dm)

proc guildMembersChunk(s: Shard, data: JsonNode) {.async.} =
    let guild = s.cache.guilds.getOrDefault(data["guild_id"].str,
        Guild(id: data["guild_id"].str)
    )

    for member in data["members"].elems:

        if member["user"]["id"].str notin guild.members:
            guild.members.add(member["user"]["id"].str,
                newMember(member))

        if member["user"]["id"].str notin s.cache.users:
            s.cache.users.add(member["user"]["id"].str,
                newUser(member["user"]))

    await s.client.events.guild_members_chunk(s, guild,
        newGuildMembersChunk(data))

proc guildMemberAdd(s: Shard, data: JsonNode) {.async.} =
    let guild = s.cache.guilds.getOrDefault(data["guild_id"].str,
        Guild(id: data["guild_id"].str)
    )

    let member = newMember(data)

    guild.members.add(member.user.id, member)

    if guild.member_count.isSome:
        guild.member_count = some guild.member_count.get + 1

    if s.cache.preferences.cache_users:
        s.cache.users.add(member.user.id, member.user)

    await s.client.events.guild_member_add(s, guild, member)

proc guildMemberUpdate(s: Shard, data: JsonNode) {.async.} =
    let guild = s.cache.guilds.getOrDefault(data["guild_id"].str,
        Guild(id: data["guild_id"].str)
    )

    let member = guild.members.getOrDefault(data["user"]["id"].str, Member(
        user: User(
            id: data["user"]["id"].str
        )
    ))

    var oldMember: Option[Member]

    if member.user.id in guild.members:
        when declared(deepCopy):
            oldMember = some deepCopy guild.members[member.user.id]

        guild.members[member.user.id] = member

    member.user = newUser(data["user"])

    if s.cache.preferences.cache_users and member.user.id notin s.cache.users:
        s.cache.users.add(member.user.id, member.user)

    if "nick" in data and data["nick"].kind != JNull:
        member.nick = some data["nick"].str
    if "premium_since" in data and data["premium_since"].kind != JNull:
        member.premium_since = some data["premium_since"].str

    for role in data["roles"].elems:
        member.roles = @[]
        member.roles.add(role.str)

    await s.client.events.guild_member_update(s, guild, member, oldMember)

proc guildMemberRemove(s: Shard, data: JsonNode) {.async.} =
    let guild = s.cache.guilds.getOrDefault(data["guild_id"].str,
        Guild(id: data["guild_id"].str)
    )

    let member = guild.members.getOrDefault(data["user"]["id"].str,
        Member(user: newUser(data["user"]))
    )

    guild.members.del(member.user.id)
    s.cache.users.del(member.user.id)

    if guild.member_count.isSome:
        guild.member_count = some guild.member_count.get - 1

    await s.client.events.guild_member_remove(s, guild, member)

proc guildBanAdd(s: Shard, data: JsonNode) {.async.} =
    let guild = s.cache.guilds.getOrDefault(data["guild_id"].str,
        Guild(id: data["guild_id"].str)
    )
    let user = newUser(data["user"])

    await s.client.events.guild_ban_add(s, guild, user)

proc guildBanRemove(s: Shard, data: JsonNode) {.async.} =
    let guild = s.cache.guilds.getOrDefault(data["guild_id"].str,
        Guild(id: data["guild_id"].str)
    )

    let user = newUser(data["user"])

    await s.client.events.guild_ban_remove(s, guild, user)

proc guildUpdate(s: Shard, data: JsonNode) {.async.} =
    let guild = newGuild(data)
    var oldGuild: Option[Guild]

    if guild.id in s.cache.guilds:
        when declared(deepCopy):
            oldGuild = some deepCopy s.cache.guilds[guild.id]

            guild.emojis = oldGuild.get.emojis
            guild.roles = oldGuild.get.roles
            guild.channels = oldGuild.get.channels
            guild.members = oldGuild.get.members
            guild.presences = oldGuild.get.presences
            guild.voice_states = oldGuild.get.voice_states

            guild.large = oldGuild.get.large
            guild.joined_at = oldGuild.get.joined_at
            guild.unavailable = oldGuild.get.unavailable
            guild.afk_timeout = oldGuild.get.afk_timeout
            guild.member_count = oldGuild.get.member_count

        s.cache.guilds[guild.id] = guild

    await s.client.events.guild_update(s, guild, oldGuild)

proc guildDelete(s: Shard, data: JsonNode) {.async.} =
    let guild = s.cache.guilds.getOrDefault(data["id"].str, Guild(
        id: data["id"].str
    ))

    guild.unavailable = some data{"unavailable"}.getBool
    s.cache.guilds.del(guild.id)

    await s.client.events.guild_delete(s, guild)

proc guildCreate(s: Shard, data: JsonNode) {.async.} =
    let guild = newGuild(data)

    if s.cache.preferences.cache_guilds:
        s.cache.guilds.add(guild.id, guild)

    if s.cache.preferences.cache_guild_channels:
        for chan in data{"channels"}.getElems:
            chan["guild_id"] = %guild.id

            s.cache.guildChannels.add(chan["id"].str, newGuildChannel(chan))

    if s.cache.preferences.cache_users:
        if data["members"].elems.len > 0:
            for m in data["members"].elems:
                s.cache.users.add(m["user"]["id"].str, newUser(m["user"]))

    await s.client.events.guild_create(s, guild)

proc guildRoleCreate(s: Shard, data: JsonNode) {.async.} =
    let guild = s.cache.guilds.getOrDefault(data["guild_id"].str,
        Guild(id: data["guild_id"].str)
    )

    let role = newRole(data["role"])

    if guild.id in s.cache.guilds:
        guild.roles.add(role.id, role)

    await s.client.events.guild_role_create(s, guild, role)

proc guildRoleUpdate(s: Shard, data: JsonNode) {.async.} =
    let guild = s.cache.guilds.getOrDefault(data["guild_id"].str,
        Guild(id: data["guild_id"].str)
    )

    let role = newRole(data["role"])
    var oldRole: Option[Role]

    if guild.id in s.cache.guilds:
        when declared(deepCopy):
            oldRole = some deepCopy guild.roles[role.id]

        guild.roles[role.id] = role

    await s.client.events.guild_role_update(s, guild, role, oldRole)

proc guildRoleDelete(s: Shard, data: JsonNode) {.async.} =
    let guild = s.cache.guilds.getOrDefault(data["guild_id"].str,
        Guild(id: data["guild_id"].str)
    )

    let role = guild.roles.getOrDefault(data["role_id"].str, Role(
        id: data["role_id"].str
    ))

    await s.client.events.guild_role_delete(s, guild, role)

proc webhooksUpdate(s: Shard, data: JsonNode) {.async.} =
    let guild = s.cache.guilds.getOrDefault(data["guild_id"].str,
        Guild(id: data["guild_id"].str)
    )

    let chan = s.cache.guildChannels.getOrDefault(
        data["channel_id"].str,
        GuildChannel(id: data["channel_id"].str)
    )

    await s.client.events.webhooks_update(s, guild, chan)

proc inviteDelete(s: Shard, data: JsonNode) {.async.} =
    var guild: Option[Guild]
    if "guild_id" in data and data["guild_id"].kind != JNull:
        guild = some s.cache.guilds.getOrDefault(
            data["guild_id"].str,
            Guild(id: data["guild_id"].str)
        )

    await s.client.events.invite_delete(s, guild, data["channel_id"].str,
        data["code"].str)

proc voiceServerUpdate(s: Shard, data: JsonNode) {.async.} =
    let guild = s.cache.guilds.getOrDefault(data["guild_id"].str,
        Guild(id: data["guild_id"].str)
    )
    var endpoint: Option[string]

    if "endpoint" in data and data["endpoint"].kind != JNull:
        # apparently this field could be nullable, so we'll need to check it.
        # incase if it crashes.
        endpoint = some data["endpoint"].str

    await s.client.events.voice_server_update(s, guild,
        data["token"].str, endpoint)

proc handleEventDispatch*(s: Shard, event: string, data: JsonNode) {.async.} =
    case event:
        of "VOICE_STATE_UPDATE":
            await s.voiceStateUpdate(data)
        of "CHANNEL_PINS_UPDATE":
            await s.channelPinsUpdate(data)
        of "GUILD_EMOJIS_UPDATE":
            await s.guildEmojisUpdate(data)
        of "PRESENCE_UPDATE":
            await s.presenceUpdate(data)
        of "MESSAGE_CREATE":
            await s.messageCreate(data)
        of "MESSAGE_REACTION_ADD":
            await s.messageReactionAdd(data)
        of "MESSAGE_REACTION_REMOVE":
            await s.messageReactionRemove(data)
        of "MESSAGE_REACTION_REMOVE_EMOJI":
            await s.messageReactionRemoveEmoji(data)
        of "MESSAGE_REACTION_REMOVE_ALL":
            await s.messageReactionRemoveAll(data)
        of "MESSAGE_DELETE":
            await s.messageDelete(data)
        of "MESSAGE_UPDATE":
            await s.messageUpdate(data)
        of "MESSAGE_DELETE_BULK":
            await s.messageDeleteBulk(data)
        of "CHANNEL_CREATE":
            await s.channelCreate(data)
        of "CHANNEL_UPDATE":
            await s.channelUpdate(data)
        of "CHANNEL_DELETE":
            await s.channelDelete(data)
        of "GUILD_MEMBERS_CHUNK":
            await s.guildMembersChunk(data)
        of "GUILD_MEMBER_ADD":
            await s.guildMemberAdd(data)
        of "GUILD_MEMBER_UPDATE":
            await s.guildMemberUpdate(data)
        of "GUILD_MEMBER_REMOVE":
            await s.guildMemberRemove(data)
        of "GUILD_BAN_ADD":
            await s.guildBanAdd(data)
        of "GUILD_BAN_REMOVE":
            await s.guildBanRemove(data)
        of "GUILD_UPDATE":
            await s.guildUpdate(data)
        of "GUILD_DELETE":
            await s.guildDelete(data)
        of "GUILD_CREATE":
            await s.guildCreate(data)
        of "GUILD_ROLE_CREATE":
            await s.guildRoleCreate(data)
        of "GUILD_ROLE_UPDATE":
            await s.guildRoleUpdate(data)
        of "GUILD_ROLE_DELETE":
            await s.guildRoleDelete(data)
        of "WEBHOOKS_UPDATE":
            await s.webhooksUpdate(data)
        of "TYPING_START":
            await s.client.events.typing_start(s, newTypingStart(data))
        of "INVITE_CREATE":
            await s.client.events.invite_create(s, newInviteCreate(data))
        of "INVITE_DELETE":
            await s.inviteDelete(data)
        of "GUILD_INTEGRATIONS_UPDATE":
            let guild = s.cache.guilds.getOrDefault(data["guild_id"].str,
                Guild(id: data["guild_id"].str)
            )
            await s.client.events.guild_integrations_update(s, guild)
        of "VOICE_SERVER_UPDATE":
            await s.voiceServerUpdate(data)
        of "USER_UPDATE":
            let user = newUser(data)
            s.user = user

            await s.client.events.user_update(s, user)
        else:
            discard