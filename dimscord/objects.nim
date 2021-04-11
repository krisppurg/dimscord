## This contains every single discord objects
## All Optional fields in these object are:
##
## * Fields that cannot be assumed. such as bools
## * Optional fields for example embeds, which they may not be
##   present.
##   
## Some may not be optional, but they can be assumable or always present.

import options, json, tables, constants
import sequtils, strutils, asyncdispatch
include objects/typedefs, objects/macros

proc newShard*(id: int, client: DiscordClient): Shard =
    result = Shard(
        id: id,
        client: client,
        cache: CacheTable(
            users: initTable[string, User](),
            guilds: initTable[string, Guild](),
            guildChannels: initTable[string, GuildChannel](),
            dmChannels: initTable[string, DMChannel]()
        ),
        retry_info: (ms: 1000, attempts: 0)
    )

proc newDiscordClient*(token: string;
        rest_mode = false;
        restVersion = 6): DiscordClient =
    ## Creates a Discord Client.
    var auth_token = token
    if not token.startsWith("Bot "):
        auth_token = "Bot " & token

    result = DiscordClient(
        token: auth_token,
        api: RestApi(
            token: auth_token,
            restVersion: when defined(discordv8):
                8
            else:
                restVersion),
        max_shards: 1,
        restMode: rest_mode,
        events: Events(
            on_dispatch: proc (s: Shard, evt: string,
                    data: JsonNode) {.async.} = discard,
            on_ready: proc (s: Shard, r: Ready) {.async.} = discard,
            on_invalid_session: proc (s: Shard, resumable: bool) {.async.} = discard,
            message_create: proc (s: Shard, m: Message) {.async.} = discard,
            message_delete: proc (s: Shard, m: Message,
                    exists: bool) {.async.} = discard,
            message_update: proc (s: Shard, m: Message,
                    o: Option[Message], exists: bool) {.async.} = discard,
            message_reaction_add: proc (s: Shard,
                    m: Message, u: User,
                    e: Emoji, exists: bool) {.async.} = discard,
            message_reaction_remove: proc (s: Shard, m: Message,
                    u: User, r: Reaction, exists: bool) {.async.} = discard,
            message_reaction_remove_all: proc (s: Shard, m: Message,
                    exists: bool) {.async.} = discard,
            message_reaction_remove_emoji: proc (s: Shard, m: Message,
                    e: Emoji, exists: bool) {.async.} = discard,
            message_delete_bulk: proc (s: Shard, m: seq[tuple[
                    msg: Message, exists: bool]]) {.async.} = discard,
            channel_create: proc (s: Shard, g: Option[Guild],
                    c: Option[GuildChannel],
                    d: Option[DMChannel]) {.async.} = discard,
            channel_update: proc (s: Shard, g: Guild,
                    c: GuildChannel,
                    o: Option[GuildChannel]) {.async.} = discard,
            channel_delete: proc (s: Shard, g: Option[Guild],
                    c: Option[GuildChannel],
                    d: Option[DMChannel]) {.async.} = discard,
            channel_pins_update: proc (s: Shard, cid: string,
                    g: Option[Guild],
                    last_pin: Option[string]) {.async.} = discard,
            presence_update: proc (s: Shard, p: Presence,
                    o: Option[Presence]) {.async.} = discard,
            typing_start: proc (s: Shard, t: TypingStart) {.async.} = discard,
            guild_emojis_update: proc (s: Shard, g: Guild,
                    e: seq[Emoji]) {.async.} = discard,
            guild_ban_add: proc (s: Shard, g: Guild,
                    u: User) {.async.} = discard,
            guild_ban_remove: proc (s: Shard, g: Guild,
                    u: User) {.async.} = discard,
            guild_integrations_update: proc (s: Shard,
                    g: Guild) {.async.} = discard,
            guild_member_add: proc (s: Shard, g: Guild,
                    m: Member) {.async.} = discard,
            guild_member_remove: proc (s: Shard, g: Guild,
                    m: Member) {.async.} = discard,
            guild_member_update: proc (s: Shard, g: Guild,
                    m: Member, o: Option[Member]) {.async.} = discard,
            guild_update: proc (s: Shard, g: Guild,
                    o: Option[Guild]) {.async.} = discard,
            guild_create: proc (s: Shard, g: Guild) {.async.} = discard,
            guild_delete: proc (s: Shard, g: Guild) {.async.} = discard,
            guild_members_chunk: proc (s: Shard, g: Guild,
                    m: GuildMembersChunk) {.async.} = discard,
            guild_role_create: proc (s: Shard, g: Guild,
                    r: Role) {.async.} = discard,
            guild_role_delete: proc (s: Shard, g: Guild,
                    r: Role) {.async.} = discard,
            guild_role_update: proc (s: Shard, g: Guild,
                    r: Role, o: Option[Role]) {.async.} = discard,
            invite_create: proc(s: Shard, i: InviteCreate) {.async.} = discard,
            invite_delete: proc (s: Shard, g: Option[Guild],
                    c, code: string) {.async.} = discard,
            user_update: proc (s: Shard, u: User) {.async.} = discard,
            voice_state_update: proc (s: Shard, v: VoiceState,
                    o: Option[VoiceState]) {.async.} = discard,
            voice_server_update: proc (s: Shard, g: Guild,
                    token: string,
                    e: Option[string]) {.async.} = discard,
            webhooks_update: proc (s: Shard, g: Guild,
                    c: GuildChannel) {.async.} = discard,
            on_disconnect: proc (s: Shard) {.async.} = discard,
            interaction_create: proc(s:Shard, i:Interaction){.async.} = discard
        ))

proc newInviteMetadata*(data: JsonNode): InviteMetadata =
    result = InviteMetadata(
        code: data["code"].str,
        uses: data["uses"].getInt,
        max_uses: data["max_uses"].getInt,
        max_age: data["max_age"].getInt,
        temporary: data["temporary"].bval,
        created_at: data["created_at"].str
    )

proc newOverwrite*(data: JsonNode): Overwrite =
    result.id = data["id"].str
    when defined(discordv8):
        result.kind = data["type"].getInt
        result.allow = cast[set[PermissionFlags]](data["allow"].str.parseInt)
        result.deny = cast[set[PermissionFlags]](data["deny"].str.parseInt)
    else:
        result.kind = data["type"].str
        result.allow = cast[set[PermissionFlags]](data["allow"].getInt)
        result.deny = cast[set[PermissionFlags]](data["deny"].getInt)
        result.allow_new = data["allow_new"].str
        result.deny_new = data["deny_new"].str

proc newRole*(data: JsonNode): Role =
    result = Role(
        id: data["id"].str,
        name: data["name"].str,
        color: data["color"].getInt,
        hoist: data["hoist"].bval,
        position: data["position"].getInt,
        managed: data["managed"].bval,
        mentionable: data["mentionable"].bval
    )
    when defined(discordv8):
        result.permissions = cast[set[PermissionFlags]](
            data["permissions"].str.parseBiggestInt
        )
    else:
        result.permissions = cast[set[PermissionFlags]](
            data["permissions"].getInt
        )
        result.permissions_new = data["permissions_new"].str

proc newGuildChannel*(data: JsonNode): GuildChannel =
    result = GuildChannel(
        id: data["id"].str,
        name: data["name"].str,
        kind: ChannelType data["type"].getInt,
        guild_id: data["guild_id"].str,
        position: data["position"].getInt,
        last_message_id: data{"last_message_id"}.getStr
    )

    for ow in data["permission_overwrites"].getElems:
        result.permission_overwrites[ow["id"].str] = newOverwrite(ow)

    case result.kind:
    of ctGuildText:
        result.rate_limit_per_user = data["rate_limit_per_user"].getInt

        data.keyCheckOptStr(result, topic)
        data.keyCheckBool(result, nsfw)

        result.messages = initTable[string, Message]()
    of ctGuildNews:
        data.keyCheckOptStr(result, topic)

        data.keyCheckBool(result, nsfw)
    of ctGuildVoice:
        result.bitrate = data["bitrate"].getInt
        result.user_limit = data["user_limit"].getInt
    else:
        discard

    data.keyCheckOptStr(result, parent_id)

proc newUser*(data: JsonNode): User =
    result = User(
        id: data["id"].str,
        username: data{"username"}.getStr,
        discriminator: data{"discriminator"}.getStr,
        bot: data{"bot"}.getBool,
        system: data{"system"}.getBool
    )

    data.keyCheckOptStr(result, avatar)
    data.keyCheckOptInt(result, public_flags)

proc newWebhook*(data: JsonNode): Webhook =
    result = Webhook(
        id: data["id"].str,
        kind: WebhookType data["type"].getInt,
        channel_id: data["channel_id"].str)

    if "user" in data:
        result.user = some newUser(data["user"])

    data.keyCheckOptStr(result, guild_id, token, name, avatar)

proc newGuildBan*(data: JsonNode): GuildBan =
    result = GuildBan(user: newUser(data["user"]))

    data.keyCheckOptStr(result, reason)

proc newDMChannel*(data: JsonNode): DMChannel = # rip dmchannels
    result = DMChannel(
        id: data["id"].str,
        kind: ChannelType data["type"].getInt,
        messages: initTable[string, Message]()
    )

    for r in data["recipients"].elems:
        result.recipients.add(newUser(r))

proc newInvite*(data: JsonNode): Invite =
    result = Invite(
        code: data["code"].str,
        channel: PartialChannel(
            id: data["channel"]["id"].str,
            kind: ChannelType data["channel"]["type"].getInt,
            name: data["channel"]["name"].str
        )
    )

    if "guild" in data:
        result.guild = some data["guild"].to(PartialGuild)
    if "inviter" in data:
        result.inviter = some newUser(data["inviter"])
    if "target_user" in data:
        result.target_user = some newUser(data["target_user"])

    data.keyCheckOptInt(result, target_user_type,
        approximate_presence_count, approximate_member_count)

proc newInviteCreate*(data: JsonNode): InviteCreate =
    result = InviteCreate(
        code: data["code"].str,
        created_at: data["created_at"].str,
        uses: data["uses"].getInt,
        max_uses: data["max_uses"].getInt,
        max_age: data["max_age"].getInt,
        channel_id: data["channel_id"].str,
        temporary: data["temporary"].bval
    )

    if "target_user" in data:
        result.target_user = some newUser(data["target_user"])
    if "inviter" in data:
        result.inviter = some newUser(data["inviter"])

    data.keyCheckOptStr(result, guild_id)
    data.keyCheckOptInt(result, target_user_type)

proc newReady*(data: JsonNode): Ready =
    result = Ready(
        v: data["v"].getInt,
        user: newUser(data["user"]),
        session_id: data["session_id"].str
    )

    for guild in data{"guilds"}.getElems:
        result.guilds.add(UnavailableGuild(
            id: guild["id"].str,
            unavailable: guild["unavailable"].bval
        ))

    if "shard" in data:
        result.shard = some newSeq[int]()

        for s in data["shard"].elems:
            get(result.shard).add(s.getInt)

proc newAttachment(data: JsonNode): Attachment =
    result = Attachment(
        id: data["id"].str,
        filename: data["filename"].str,
        size: data["size"].getInt,
        url: data["url"].str,
        proxy_url: data["proxy_url"].str,
    )
    data.keyCheckOptInt(result, height, width)

proc newVoiceState*(data: JsonNode): VoiceState =
    result = VoiceState(
        user_id: data["user_id"].str,
        session_id: data["session_id"].str,
        deaf: data["deaf"].bval,
        mute: data["mute"].bval,
        self_deaf: data["self_deaf"].bval,
        self_mute: data["self_mute"].bval,
        suppress: data["suppress"].bval
    )

    data.keyCheckBool(result, self_stream)
    data.keyCheckOptStr(result, guild_id, channel_id)

proc newEmoji*(data: JsonNode): Emoji =
    result = Emoji(
        roles: data{"roles"}.getElems.mapIt(it.str)
    )

    if "user" in data:
        result.user = some newUser(data["user"])

    data.keyCheckOptStr(result, id, name)
    data.keyCheckOptBool(result, require_colons, managed, animated)

proc newActivity*(data: JsonNode): Activity =
    result = Activity(
        name: data["name"].str,
        kind: ActivityType data["type"].getInt,
        created_at: data["created_at"].num,
        flags: cast[set[ActivityFlags]](data{"flags"}.getInt)
    )

    data.keyCheckOptStr(result, url, application_id, details, state)
    data.keyCheckBool(result, instance)

    if "timestamps" in data:
        result.timestamps = some (
            start: data["timestamps"]{"start"}.getBiggestInt,
            final: data["timestamps"]{"end"}.getBiggestInt
        )

    if "emoji" in data:
        result.emoji = some newEmoji(data["emoji"])

    if "party" in data:
        result.party = some (
            id: data["party"]{"id"}.getStr,
            size: data["party"]{"size"}.getElems.mapIt(it.getInt)
        )

    if "assets" in data:
        result.assets = some GameAssets(
            small_text: data["assets"]{"small_text"}.getStr,
            small_image: data["assets"]{"small_image"}.getStr,
            large_text: data["assets"]{"large_text"}.getStr,
            large_image: data["assets"]{"large_image"}.getStr
        )

    if "secrets" in data:
        result.secrets = some (
            join: data["secrets"]{"join"}.getStr,
            spectate: data["secrets"]{"spectate"}.getStr,
            match: data["secrets"]{"match"}.getStr
        )

proc newPresence*(data: JsonNode): Presence =
    result = Presence(
        user: newUser(data["user"]),
        guild_id: data{"guild_id"}.getStr,
        status: data["status"].str,
        client_status: (
            web: "offline",
            desktop: "offline",
            mobile: "offline"
        )
    )

    for activity in data["activities"].elems:
        result.activities.add(newActivity(activity))
    when not defined(discordv8):
        if data["game"].kind != JNull:
            result.activity = some newActivity(data["game"])

    data["client_status"].keyCheckStr(result.client_status,
        desktop, web, mobile)

proc newMember*(data: JsonNode): Member =
    result = Member(
        joined_at: data["joined_at"].str,
        roles: data["roles"].elems.mapIt(it.str),
        deaf: data["deaf"].bval,
        mute: data["mute"].bval,
        presence: Presence(
            status: "offline",
            client_status: ("offline", "offline", "offline")
        )
    )
    if "permissions" in data and data["permissions"].kind != JNull:
        result.permissions = some cast[set[PermissionFlags]](
            data["permissions"].str.parseBiggestInt
        )
    if "user" in data and data["user"].kind != JNull:
        result.user = newUser(data["user"])

    data.keyCheckOptStr(result, nick, premium_since)
    data.keyCheckOptBool(result, pending)

proc newTypingStart*(data: JsonNode): TypingStart =
    result = TypingStart(
        channel_id: data["channel_id"].str,
        user_id: data["user_id"].str,
        timestamp: data["timestamp"].getInt
    )

    if "member" in data and data["member"].kind != JNull:
        result.member = some newMember(data["member"])

    data.keyCheckOptStr(result, guild_id)

proc newGuildMembersChunk*(data: JsonNode): GuildMembersChunk =
    result = GuildMembersChunk(
        guild_id: data["guild_id"].str,
        chunk_index: data["chunk_index"].getInt,
        chunk_count: data["chunk_count"].getInt,
        members: data["members"].elems.map(newMember),
        not_found: data{"not_found"}.getElems.mapIt(it.getStr()),
        presences: data{"presences"}.getElems.map(newPresence)
    )
    data.keyCheckOptStr(result, nonce)

proc newReaction*(data: JsonNode): Reaction =
    result = Reaction(
        count: data["count"].getInt,
        emoji: newEmoji(data["emoji"]),
        reacted: data["me"].bval
    )

proc updateMessage*(m: Message, data: JsonNode): Message =
    result = m

    result.mention_users = data{"mentions"}.getElems.map(newUser)
    result.attachments = data{"attachments"}.getElems.map(newAttachment)
    result.embeds = data{"embeds"}.getElems.map(
        proc (x: JsonNode): Embed =
            x.to(Embed)
    )
    if "type" in data and data["type"].kind != JNull:
        result.kind = MessageType data["type"].getInt
    if "flags" in data and data["flags"].kind != JNull:
        result.flags = cast[set[MessageFlags]](data["flags"].getInt)

    data.keyCheckStr(result, content, timestamp)
    data.keyCheckOptStr(result, edited_timestamp, guild_id)
    data.keyCheckBool(result, mention_everyone, pinned, tts)

    if "author" in data:
        result.author = newUser(data["author"])
    if "activity" in data:
        let activity = data["activity"]

        result.activity = some (
            kind: activity["type"].getInt,
            party_id: activity{"party_id"}.getStr
        )

    if "application" in data:
        let app = data["application"]

        result.application = some Application(
            id: app["id"].str,
            description: app["description"].str,
            cover_image: app{"cover_image"}.getStr,
            icon: app{"icon"}.getStr,
            name: app["name"].str
        )

proc newMessage*(data: JsonNode): Message =
    result = Message(
        id: data["id"].str,
        channel_id: data["channel_id"].str,
        content: data["content"].str,
        timestamp: data["timestamp"].str,
        tts: data["tts"].bval,
        mention_everyone: data["mention_everyone"].bval,
        pinned: data["pinned"].bval,
        kind: MessageType data["type"].getInt,
        flags: cast[set[MessageFlags]](data["flags"].getInt),
        stickers: data{"stickers"}.getElems.map(
            proc (x: JsonNode): Sticker =
                x.to(Sticker)
        ),
        reactions: initTable[string, Reaction]()
    )
    data.keyCheckOptStr(result, edited_timestamp,
        guild_id, nonce, webhook_id)

    if "author" in data:
        result.author = newUser(data["author"])
    if "member" in data and data["member"].kind != JNull:
        result.member = some newMember(data["member"])
    if "referenced_message" in data and data["referenced_message"].kind!=JNull:
        result.referenced_message = some data["referenced_message"].newMessage

    for r in data{"mention_roles"}.getElems:
        result.mention_roles.add(r.str)

    for usr in data{"mentions"}.getElems:
        result.mention_users.add(newUser(usr))

    for chan in data{"mention_channels"}.getElems:
        result.mention_channels.add(MentionChannel(
            id: chan["id"].str,
            guild_id: chan["guild_id"].str,
            kind: ChannelType chan["type"].getInt,
            name: chan["name"].str
        ))

    for attach in data{"attachments"}.getElems:
        result.attachments.add(newAttachment(attach))

    for embed in data{"embeds"}.getElems:
        result.embeds.add(embed.to(Embed))
    for reaction in data{"reactions"}.getElems:
        let rtn = newReaction(reaction)
        result.reactions[$rtn.emoji] = rtn

    if "activity" in data:
        let activity = data["activity"]

        result.activity = some (
            kind: activity["type"].getInt,
            party_id: activity{"party_id"}.getStr
        )

    if "application" in data:
        let app = data["application"]

        result.application = some Application(
            id: app["id"].str,
            description: app["description"].str,
            cover_image: app{"cover_image"}.getStr,
            icon: app{"icon"}.getStr,
            name: app["name"].str
        )

    if "message_reference" in data:
        let reference = data["message_reference"]

        var message_reference = MessageReference(
            channel_id: reference["channel_id"].str
        )
        reference.keyCheckOptStr(message_reference, message_id, guild_id)
        result.message_reference = some message_reference

proc newAuditLogChangeValue(data: JsonNode, key: string): AuditLogChangeValue =
    case data.kind:
    of JString:
        result = AuditLogChangeValue(kind: alcString)
        result.str = data.str
    of JInt:
        result = AuditLogChangeValue(kind: alcInt)
        result.ival = data.getInt
    of JBool:
        result = AuditLogChangeValue(kind: alcBool)
        result.bval = data.bval
    of JArray:
        if key in ["$add", "$remove"]:
            result = AuditLogChangeValue(kind: alcRoles)
            result.roles = data.elems.map(
                proc (x: JsonNode): tuple[id, name: string] =
                    x.to(tuple[id, name: string])
            )
        elif "permission_overwrites" in key:
            result = AuditLogChangeValue(kind: alcOverwrites)
            result.overwrites = data.elems.map(newOverwrite)
    else:
        discard

proc newAuditLogEntry(data: JsonNode): AuditLogEntry =
    result = AuditLogEntry(
        before: initTable[string, AuditLogChangeValue](),
        after: initTable[string, AuditLogChangeValue](),
        user_id: data["user_id"].str,
        id: data["id"].str,
        action_type: AuditLogEntryType data["action_type"].getInt
    )
    data.keyCheckOptStr(result, target_id, reason)

    if "options" in data:
        result.opts = some data.to(AuditLogOptions)

    for change in data{"changes"}.getElems:
        if "new_value" in change:
            result.after[change["key"].str] = newAuditLogChangeValue(
                change["new_value"],
                change["key"].str
            )
        if "old_value" in change:
            result.before[change["key"].str] = newAuditLogChangeValue(
                change["old_value"],
                change["key"].str
            )

proc newAuditLog*(data: JsonNode): AuditLog =
    result = AuditLog(
        webhooks: data["webhooks"].elems.map(newWebhook),
        users: data["users"].elems.map(newUser),
        audit_log_entries: data["audit_log_entries"].elems.map(
            newAuditLogEntry),
        integrations: data["integrations"].elems.map(
            proc (x: JsonNode): Integration =
                result = x.to(Integration)
        )
    )

proc newTeam(data: JsonNode): Team =
    result = Team(
        id: data["id"].str,
        owner_user_id: data["owner_user_id"].str,
        members: data["members"].elems.map(
            proc (x: JsonNode): TeamMember =
                result = TeamMember(
                    membership_state: TeamMembershipState(
                        x["membership_state"].getInt
                    ),
                    permissions: x["permissions"].elems.mapIt(it.str),
                    team_id: x["team_id"].str,
                    user: newUser(x["user"])
                )
        )
    )
    data.keyCheckOptStr(result, icon)

proc newOAuth2Application*(data: JsonNode): OAuth2Application =
    result = OAuth2Application(
        id: data["id"].str,
        name: data["name"].str,
        description: data["description"].str,
        rpc_origins: data{"rpc_orgins"}.getElems.mapIt(it.str),
        bot_public: data["bot_public"].bval,
        bot_require_code_grant: data["bot_require_code_grant"].bval,
        owner: newUser(data["owner"]),
        summary: data["summary"].str,
        verify_key: data["verify_key"].str,
    )
    data.keyCheckOptStr(result, icon, guild_id,
        primary_sku_id, slug, cover_image)

    if "team" in data and data["team"].kind != JNull:
        result.team = some newTeam(data["team"])

proc newGuild*(data: JsonNode): Guild =
    result = Guild(
        id: data["id"].str,
        name: data["name"].str,
        owner: data{"owner"}.getBool,
        owner_id: data["owner_id"].str,
        region: data["region"].str,
        widget_enabled: data{"widget_enabled"}.getBool,
        verification_level: VerificationLevel(
            data["verification_level"].getInt
        ),
        explicit_content_filter: ExplicitContentFilter(
            data["explicit_content_filter"].getInt
        ),
        default_message_notifications: MessageNotificationLevel(
            data["default_message_notifications"].getInt
        ),
        system_channel_flags: cast[set[SystemChannelFlags]](
            data{"system_channel_flags"}.getStr("0").parseBiggestInt
        ),
        roles: initTable[string, Role](),
        emojis: initTable[string, Emoji](),
        voice_states: initTable[string, VoiceState](),
        members: initTable[string, Member](),
        channels: initTable[string, GuildChannel](),
        presences: initTable[string, Presence](),
        mfa_level: MFALevel data["mfa_level"].getInt,
        premium_tier: PremiumTier data["premium_tier"].getInt,
        preferred_locale: data["preferred_locale"].str)

    for r in data["roles"].elems:
        result.roles[r["id"].str] = newRole(r)
    for e in data["emojis"].elems:
        result.emojis[e["id"].str] = newEmoji(e)
    if "welcome_screen" in data and data["welcome_screen"].kind != JNull:
        result.welcome_screen = some data.to(tuple[
            description: Option[string],
            welcome_channels: seq[WelcomeChannel]
        ])

    data.keyCheckOptInt(result, afk_timeout, permissions, member_count,
        premium_subscription_count, max_presences, approximate_member_count,
        approximate_presence_count, max_video_channel_uses)
    data.keyCheckOptStr(result, joined_at, icon, splash, afk_channel_id,
        permissions_new, application_id, system_channel_id, vanity_url_code,
        discovery_splash, description, banner, widget_channel_id,
        public_updates_channel_id)
    data.keyCheckOptBool(result, large, unavailable)

    for m in data{"members"}.getElems:
        result.members[m["user"]["id"].str] = newMember(m)

    for v in data{"voice_states"}.getElems:
        let state = newVoiceState(v)

        result.members[v["user_id"].str].voice_state = some state
        result.voice_states[v["user_id"].str] = state

    for chan in data{"channels"}.getElems:
        chan["guild_id"] = %result.id
        result.channels[chan["id"].str] = newGuildChannel(chan)

    for p in data{"presences"}.getElems:
        let presence = newPresence(p)
        let uid = presence.user.id

        presence.guild_id = result.id

        result.members[uid].presence = presence
        result.presences[uid] = presence

proc newGuildTemplate*(data: JsonNode): GuildTemplate =
    result = GuildTemplate(
        code: data["code"].str,
        name: data["name"].str,
        usage_count: data["usage_count"].getInt,
        creator_id: data["creator_id"].str,
        creator: newUser(data["creator"]),
        created_at: data["created_at"].str,
        updated_at: data["updated_at"].str,
        source_guild_id: data["source_guild_id"].str,
        serialized_source_guild:data["serialized_source_guild"].to PartialGuild
    )
    data.keyCheckOptBool(result, is_dirty)
    data.keyCheckOptStr(result, description)

proc newApplicationCommandInteractionDataOption(
    data: JsonNode
): ApplicationCommandInteractionDataOption =
    result = ApplicationCommandInteractionDataOption(
        options: data{"options"}.getElems.map(
            proc(x: JsonNode):(string,ApplicationCommandInteractionDataOption)=
                (x["name"].str, newApplicationCommandInteractionDataOption(x))
        ).toTable
    )
    if "value" in data and data["value"].kind != JNull:
        case data["value"].kind:
        of JBool:
            result.bval = some data["value"].bval
        of JString:
            result.str = some data["value"].str
        of JInt:
            result.ival = some data["value"].getInt
        else:
            discard

proc newApplicationCommandInteractionData*(
    data: JsonNode
): ApplicationCommandInteractionData =
    result = ApplicationCommandInteractionData(
        id: data["id"].str,
        name: data["name"].str,
        options: initTable[string, ApplicationCommandInteractionDataOption]()
    )
    for option in data{"options"}.getElems:
        result.options[option["name"].str] = 
            newApplicationCommandInteractionDataOption(option)

proc newInteraction*(data: JsonNode): Interaction =
    result = Interaction(
        id: data["id"].str,
        kind: InteractionType data["type"].getInt,
        channel_id: data["channel_id"].str,
        token: data["token"].str,
        version: data["version"].getInt
    )
    data.keyCheckOptStr(result, guild_id)

    if "member" in data and data["member"].kind != JNull:
        result.member = some data["member"].newMember
    if "user" in data and data["user"].kind != JNull:
        result.user = some data["user"].newUser

    if "data" in data and data["data"].kind != JNull: # nice
        result.data = some newApplicationCommandInteractionData(data["data"])

proc newApplicationCommandOption*(data: JsonNode): ApplicationCommandOption =
    result = ApplicationCommandOption(
        kind: ApplicationCommandOptionType data["type"].getInt,
        name: data["name"].str,
        description: data["description"].str,
        choices: data{"choices"}.getElems.map(
            proc (x: JsonNode): ApplicationCommandOptionChoice =
                result = ApplicationCommandOptionChoice(
                    name: x["name"].str)
                if x["value"].kind == JInt:
                    result.value[1] = some x["value"].getInt # this is 
                if x["value"].kind == JString: # a tuple btw
                    result.value[0] = some x["value"].str
        ),
        options: data{"options"}.getElems.map newApplicationCommandOption
    )
    data.keyCheckOptBool(result, default, required)

proc `%%*`*(a: ApplicationCommandOption): JsonNode =
    result = %*{"type": int a.kind, "name": a.name,
                "description": a.description,
                "required": %(a.required.get false)
    }

    if a.choices.len > 0:
        result["choices"] = %a.choices.map(
            proc (x: ApplicationCommandOptionChoice): JsonNode =
                let json = %*{"name": %x.name}
                if x.value[0].isSome:
                    json["value"] = %x.value[0]
                if x.value[1].isSome:
                    json["value"] = %x.value[1]
                return json
        )
    if a.options.len > 0:
        result["options"] = %a.options.map(
            proc (x: ApplicationCommandOption): JsonNode =
                return %%*x # avoid conflicts with json
        )

proc newApplicationCommand*(data: JsonNode): ApplicationCommand =
    result = ApplicationCommand(
        id: data["id"].str,
        application_id: data["application_id"].str,
        name: data["name"].str,
        description: data["description"].str,
        options: data{"options"}.getElems.map newApplicationCommandOption
    )
