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
    
    var apiVersion = restVersion
    when defined(discordv8) and not defined(discordv9):
        apiVersion = 8
    when defined(discordv9) and not defined(discordv8): 
        apiVersion = 9
    when defined(discordv8) and defined(discordv9):
        raise newException(Exception,
            "Both v8 and v9 are defined, please define either one of them only."
        )
    result = DiscordClient(
        token: auth_token,
        api: RestApi(
            token: auth_token,
            restVersion: apiVersion),
        max_shards: 1,
        restMode: rest_mode,
        events: Events(
            on_dispatch: proc (s: Shard, evt: string,
                    data: JsonNode) {.async.} = discard,
            on_ready: proc (s: Shard, r: Ready) {.async.} = discard,
            on_invalid_session: proc (s: Shard,
                    resumable: bool) {.async.} = discard,
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
            interaction_create: proc (s:Shard, i:Interaction){.async.} = discard,
            application_command_create: proc (s: Shard, g: Option[Guild],
                    a: ApplicationCommand) {.async.} = discard,
            application_command_update: proc(s: Shard, g: Option[Guild],
                    a: ApplicationCommand) {.async.} = discard,
            application_command_delete: proc (s: Shard,
                    g: Option[Guild], a: ApplicationCommand) {.async.} = discard,
            thread_create: proc (s: Shard, g: Guild,
                    c: GuildChannel) {.async.} = discard,
            thread_update: proc (s: Shard, g: Guild,
                    c:GuildChannel, o:Option[GuildChannel]){.async.} = discard,
            thread_delete: proc (s: Shard, g: Guild,
                    c: GuildChannel, exists: bool) {.async.} = discard,
            thread_list_sync: proc (s: Shard, e: ThreadListSync) {.async.} = discard,
            thread_member_update: proc (s: Shard, g: Guild, t: ThreadMember) {.async.} = discard,
            thread_members_update: proc (s: Shard, e: ThreadMembersUpdate) {.async.} = discard
        ))

proc newGuildPreview*(data: JsonNode): GuildPreview =
    result = GuildPreview(
        id: data["id"].str,
        name: data["name"].str,
        features: data["features"].elems.mapIt(it.getStr),
        approximate_member_count: data["approximate_member_count"].getInt,
        approximate_presence_count: data["approximate_presence_count"].getInt,
        system_channel_flags: cast[set[SystemChannelFlags]](
            data{"system_channel_flags"}.getStr("0").parseBiggestInt
        )
    )
    data.keyCheckOptStr(result, icon, banner, splash, emojis,
        preferred_locale, discovery_splash, description)

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
    when defined(discordv8) or defined(discordv9):
        result.kind = data["type"].getInt
        result.allow = cast[set[PermissionFlags]](
            data["allow"].str.parseBiggestInt
        )
        result.deny = cast[set[PermissionFlags]](
            data["deny"].str.parseBiggestInt
        )
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
    if "tags" in data:
        result.tags = some data["tags"].to(RoleTag)
    when defined(discordv8) or defined(discordv9):
        result.permissions = cast[set[PermissionFlags]](
            data["permissions"].str.parseBiggestInt
        )
    else:
        result.permissions = cast[set[PermissionFlags]](
            data{"permissions"}.getBiggestInt # incase
        )
        result.permissions_new = data["permissions_new"].str

proc newGuildChannel*(data: JsonNode): GuildChannel =
    result = GuildChannel(
        id: data["id"].str,
        name: data["name"].str,
        kind: ChannelType data["type"].getInt,
        guild_id: data["guild_id"].str,
        nsfw: data{"nsfw"}.getBool,
        last_message_id: data{"last_message_id"}.getStr,
        messages: initTable[string, Message]()
    )

    if "permissions" in data and data["permissions"].kind != JNull:
        result.permissions = cast[set[PermissionFlags]](
            data["permissions"].str.parseBiggestInt
        )
    for ow in data{"permission_overwrites"}.getElems:
        result.permission_overwrites[ow["id"].str] = newOverwrite(ow)

    data.keyCheckOptStr(result, parent_id)
    data.keyCheckOptInt(result,
        position,
        default_auto_archive_duration,
        rate_limit_per_user
    )

    case result.kind:
    of ctGuildText, ctGuildNews:
        data.keyCheckOptStr(result, topic)
    of ctGuildVoice, ctGuildStageVoice:
        result.bitrate = data["bitrate"].getInt
        result.user_limit = data["user_limit"].getInt
        data.keyCheckOptStr(result, rtc_region)
        data.keyCheckOptInt(result, video_quality_mode)
    of ctGuildPublicThread, ctGuildPrivateThread, ctGuildNewsThread:
        if "member" in data and data["member"].kind != JNull:
            result.member = some data["member"].to ThreadMember
        result.thread_metadata = data["thread_metadata"].to ThreadMetadata

        data.keyCheckOptInt(result, message_count, member_count)
    else:
        discard

proc newUser*(data: JsonNode): User =
    result = User(
        id: data["id"].str,
        username: data{"username"}.getStr,
        discriminator: data{"discriminator"}.getStr,
        bot: data{"bot"}.getBool,
        system: data{"system"}.getBool,
        public_flags: cast[set[UserFlags]](
            data{"public_flags"}.getBiggestInt
        ),
        flags: cast[set[UserFlags]](
            data{"flags"}.getBiggestInt
        )
    )

    data.keyCheckOptStr(result,
        avatar, locale)
    data.keyCheckOptBool(result,
        mfa_enabled)

proc newTeam(data: JsonNode): Team =
    result = Team(
        id: data["id"].str,
        name: data["name"].str,
        owner_user_id: data["owner_user_id"].str,
        members: data["members"].elems.map(
            proc(x:JsonNode):TeamMember =
                TeamMember(
                    membership_state: TeamMembershipState(
                        x["membership_state"].getInt
                    ),
                    permissions: x["permissions"].elems.mapIt(it.getStr),
                    team_id: x["team_id"].str,
                    user: x["user"].newUser
                )
        )
    )
    data.keyCheckOptStr(result, icon)

proc newApplication*(data: JsonNode): Application =
    result = Application(
        id: data["id"].str,
        name: data["name"].str,
        description: data["description"].str,
        rpc_origins: data{"rpc_origins"}.getElems.mapIt(it.getStr),
        bot_public: data{"bot_public"}.getBool,
        bot_require_code_grant: data{"bot_require_code_grant"}.getBool,
        owner: data["owner"].newUser,
        summary: data["summary"].str,
        verify_key: data["verify_key"].str,
        flags: cast[set[ApplicationFlags]](
            data{"flags"}.getBiggestInt
        )
    )
    data.keyCheckOptStr(result, icon,
        terms_of_service_url, privacy_policy_url,
        guild_id, primary_sku_id, slug, cover_image)

    if "team" in data and data["team"].kind != JNull:
        result.team = some data["team"].newTeam

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

proc newStageInstance*(data: JsonNode): StageInstance =
    result = StageInstance(
        id: data["id"].str,
        guild_id: data["guild_id"].str,
        channel_id: data["channel_id"].str,
        topic: data["topic"].str,
        privacy_level: PrivacyLevel data["privacy_level"].getInt,
        discoverable_disabled: data["discoverable_disabled"].bval
    )

proc newEmoji*(data: JsonNode): Emoji =
    result = Emoji(
        roles: data{"roles"}.getElems.mapIt(it.str)
    )

    if "user" in data:
        result.user = some newUser(data["user"])

    data.keyCheckOptStr(result, id, name)
    data.keyCheckOptBool(result, require_colons, managed, animated)
    data.keyCheckOptBool(result, available, managed, animated)

proc newActivity*(data: JsonNode): Activity =
    result = Activity(
        name: data["name"].str,
        kind: ActivityType data["type"].getInt,
        created_at: data["created_at"].num,
        flags: cast[set[ActivityFlags]](data{"flags"}.getInt),
        buttons: data{"buttons"}.getElems.mapIt(
            it.getStr
        )
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
    when not defined(discordv8) and not defined(discordv9):
        if data["game"].kind != JNull:
            result.activity = some newActivity(data["game"])

    data["client_status"].keyCheckStr(result.client_status,
        desktop, web, mobile)

proc newMember*(data: JsonNode): Member =
    result = Member(
        joined_at: data["joined_at"].str,
        roles: data["roles"].elems.mapIt(it.str),
        deaf: data{"deaf"}.getBool(false),
        mute: data{"mute"}.getBool(false),
        presence: Presence(
            status: "offline",
            client_status: ("offline", "offline", "offline")
        ),
        permissions: cast[set[PermissionFlags]](
            data{"permissions"}.getStr("0").parseBiggestInt
        )
    )
    if "user" in data and data["user"].kind != JNull:
        result.user = newUser(data["user"])

    data.keyCheckOptStr(result, nick, premium_since)
    data.keyCheckOptBool(result, pending)

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
        result.inviter = some data["inviter"].newUser
    if "target_user" in data:
        result.target_user = some data["target_user"].newUser
    if "target_type" in data:
        result.target_type = some InviteTargetType(
            data["target_type"].getInt
        )
    if "target_application" in data:
        result.target_application = some data[
            "target_application"
        ].newApplication

    if "stage_instance" in data:
        let x = data["stage_instance"]
        result.stage_instance = some (
            members: x{"members"}.getElems.map(newMember),
            topic: x["topic"].str,
            participant_count: x["participant_count"].getInt,
            speaker_count: x["speaker_count"].getInt
        )

    data.keyCheckOptStr(result,expires_at)
    data.keyCheckOptInt(result,
        approximate_presence_count,
        approximate_member_count
    )

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
    if "target_application" in data and data["target_application"].kind!=JNull:
        result.target_application=some data["target_application"].newApplication
    if "target_type" in data and data["target_type"].kind != JNull:
        result.target_type = some InviteTargetType data["target_type"].getInt

    data.keyCheckOptStr(result, guild_id)

proc newReady*(data: JsonNode): Ready =
    result = Ready(
        v: data["v"].getInt,
        user: newUser(data["user"]),
        session_id: data["session_id"].str,
        application: (
            data["application"]["id"].str,
            cast[set[ApplicationFlags]](
                data["application"]["flags"].getBiggestInt
            )
        )
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
        not_found: data{"not_found"}.getElems.mapIt(it.getStr),
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
        result.application = some data["application"].newApplication

proc newSticker*(data: JsonNode): Sticker =
    result = Sticker(
        id: data["id"].str,
        name: data["name"].str,
        tags: data["tags"].str,
        kind: StickerType data["type"].getInt
    )

    if "user" in data and data["user"].kind != JNull:
        result.user = some data["user"].newUser

    data.keyCheckOptStr(result, description, guild_id)
    data.keyCheckOptBool(result, available)
    data.keyCheckOptInt(result, sort_value)

proc newStickerPack*(data: JsonNode): StickerPack =
    result = StickerPack(
        id: data["id"].str,
        stickers: data["stickers"].getElems.map(newSticker),
        name: data["name"].str,
        sku_id: data["sku_id"].str,
        description: data["description"].str,
        banner_asset_id: data["banner_asset_id"].str
    )
    data.keyCheckOptStr(result, cover_sticker_id)

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
        flags: cast[set[MessageFlags]](
            data{"flags"}.getBiggestInt
        ),
        attachments: data{"attachments"}.getElems.map newAttachment,
        mention_roles: data{"mention_roles"}.getElems.mapIt(it.str),
        mention_users: data{"mentions"}.getElems.map newUser,
        embeds:data{"embeds"}.getElems.map(proc(e:JsonNode):Embed=e.to(Embed)),
        reactions: initTable[string, Reaction]()
    )
    data.keyCheckOptStr(result, edited_timestamp,
        guild_id, nonce, webhook_id)

    if "author" in data:
        result.author = data["author"].newUser
    if "member" in data and data["member"].kind != JNull:
        result.member = some data["member"].newMember
    if "referenced_message" in data and data["referenced_message"].kind!=JNull:
        result.referenced_message = some data["referenced_message"].newMessage

    for chan in data{"mention_channels"}.getElems:
        result.mention_channels.add(MentionChannel(
            id: chan["id"].str,
            guild_id: chan["guild_id"].str,
            kind: ChannelType chan["type"].getInt,
            name: chan["name"].str
        ))

    for s in data{"sticker_items"}.getElems:
        result.sticker_items[s["id"].str] = (
            id: s["id"].str,
            name: s["name"].str,
            format_type: MessageStickerFormat s["format_type"].getInt
        )

    for rn in data{"reactions"}.getElems:
        let r = rn.newReaction
        result.reactions[$r.emoji] = r

    if "activity" in data:
        let act = data["activity"]
        result.activity = some (
            kind: act["type"].getInt,
            party_id: act{"party_id"}.getStr
        )

    if "application" in data:
        result.application = some data["application"].newApplication
    if "message_reference" in data:
        var message_reference = MessageReference()
        data["message_reference"].keyCheckOptStr(
            message_reference, channel_id,
            message_id, guild_id
        )
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

proc newIntegration*(data: JsonNode): Integration =
    result = Integration(
        id: data["id"].str,
        name: data["name"].str,
        kind: data["type"].str,
        enabled: data["enabled"].bval,
        account: data["account"].to(tuple[id, name: string]))
    if "expire_behavior" in data and data["expire_behavior"].kind != JNull:
        result.expire_behavior = some IntegrationExpireBehavior(
            data["expire_behavior"].getInt
        )
    if "user" in data and data["user"].kind != JNull:
        result.user = some data["user"].newUser

    data.keyCheckOptBool(result, syncing, enable_emoticons, revoked)
    data.keyCheckOptStr(result, role_id, synced_at)
    data.keyCheckOptInt(result, expire_grace_period, subscriber_count)

proc newAuditLog*(data: JsonNode): AuditLog =
    AuditLog(
        webhooks: data["webhooks"].elems.map(newWebhook),
        users: data["users"].elems.map(newUser),
        audit_log_entries: data["audit_log_entries"].elems.map(
            newAuditLogEntry),
        integrations: data{"integrations"}.getElems.map(
            newIntegration)
    )

proc newGuild*(data: JsonNode): Guild =
    result = Guild(
        id: data["id"].str,
        name: data["name"].str,
        nsfw: data["nsfw"].bval,
        owner: data{"owner"}.getBool, # it is actually possible to
        owner_id: data["owner_id"].str, # have no owner, just a glitch ;)
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
        threads: initTable[string, GuildChannel](),
        stickers: initTable[string, Sticker](),
        presences: initTable[string, Presence](),
        mfa_level: MFALevel data["mfa_level"].getInt,
        nsfw_level: GuildNSFWLevel data["nsfw_level"].getInt,
        premium_tier: PremiumTier data["premium_tier"].getInt,
        preferred_locale: data["preferred_locale"].str
    )
    when defined(discordv9):
        if "rtc_region" in data and data["rtc_region"].kind != JNull:
            result.rtc_region = some data["rtc_region"].str
    else:
        if "region" in data and data["region"].kind != JNull:
            result.rtc_region = some data["region"].str

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
    data.keyCheckOptStr(result, joined_at, icon, icon_hash, splash,
        afk_channel_id, permissions_new, application_id, system_channel_id,
        vanity_url_code, discovery_splash, description, banner,
        widget_channel_id, public_updates_channel_id)
    data.keyCheckOptBool(result, large, unavailable)

    for m in data{"members"}.getElems:
        result.members[m["user"]["id"].str] = newMember(m)

    for v in data{"voice_states"}.getElems:
        let state = newVoiceState(v)

        result.members[v["user_id"].str].voice_state = some state
        result.voice_states[v["user_id"].str] = state

    for sticker in data{"stickers"}.getElems:
        result.stickers[sticker["id"].str] = newSticker(sticker)

    for thread in data{"threads"}.getElems:
        thread["guild_id"] = %result.id
        result.threads[thread["id"].str] = newGuildChannel(thread)

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
        kind: ApplicationCommandOptionType(data["type"].getInt())
    )
    result.name = data["name"].getStr()
    if result.kind notin {acotSubCommand, acotSubCommandGroup}:
        # SubCommands/Groups don't have a value
        let value = data["value"]
        case result.kind
            of acotBool:
                result.bval = value.bval
            of acotInt:
                result.ival = value.getInt()
            of acotStr:
                result.str  = value.getStr()
            of acotUser:
                result.userID = value.getStr()
            of acotChannel:
                result.channelID = value.getStr()
            of acotRole:
                result.roleID = value.getStr()
            else: discard
    else:
        # Convert the array of sub options into a key value table
        result.options = toTable data{"options"}
            .getElems
            .map() do (x: JsonNode) -> (string, ApplicationCommandInteractionDataOption):
                    (
                        x["name"].str,
                        newApplicationCommandInteractionDataOption(x)
                    )

proc newApplicationCommandInteractionData*(
    data: JsonNode
): ApplicationCommandInteractionData =
    if "component_type" in data:
        result = ApplicationCommandInteractionData(
            interactionType: idtComponent,
            component_type: MessageComponentType data["component_type"].getInt(),
            custom_id: data["custom_id"].str
        )
        if result.component_type == SelectMenu:
            result.values = data["values"].getElems()
                .map() do (x: JsonNode) -> string: x.str
    else:
        result = ApplicationCommandInteractionData(
            interactionType: idtApplicationCommand,
            id: data["id"].str,
            name: data["name"].str,
            kind: ApplicationCommandType data{"type"}.getInt(1)
        )
        case result.kind:
            of atSlash:
                result.options = initTable[string, ApplicationCommandInteractionDataOption]()
                for option in data{"options"}.getElems:
                    result.options[option["name"].str] =
                        newApplicationCommandInteractionDataOption(option)
            of atUser, atMessage:
                result.targetID = data["target_id"].str
                # Set the resolution kind to be the same as the interaction
                # data kind, saves the user needing to user options when it
                # isn't necessary
                var resolution = ApplicationCommandResolution(kind: result.kind)
                let resolvedJson = data["resolved"]
                if result.kind == atUser:
                    # Get users
                    for id, jsonData in resolvedJson{"users"}:
                        resolution.users[id] = newUser(jsonData)
                    # Get members
                    for id, jsonData in resolvedJson{"members"}:
                        resolution.members[id] = newMember(jsonData)
                else: # result.kind will equal atMessage
                    # Get messages
                    for id, jsonData in resolvedJson{"messages"}:
                        resolution.messages[id] = newMessage(jsonData)
                result.resolved = resolution
            else:
                discard



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
    if "message" in data and data["message"].kind != JNull:
        result.message = some data["message"].newMessage
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

proc `%%*`*(a: ApplicationCommand): JsonNode =
    assert a.name.len in 3..32
    # This ternary is needed so that the enums can stay similar to
    # the discord api
    let commandKind = if a.kind == atNothing: atSlash else: a.kind
    result = %*{
        "name": a.name,
        "type": commandKind.ord
    }
    if commandKind == atSlash:
        assert a.description.len in 1..100
        result["description"] = %a.description
        if a.options.len > 0: result["options"] = %(a.options.map(
            proc (x: ApplicationCommandOption): JsonNode =
                %%*x
        ))
    result["default_permission"] = %a.default_permission

proc newApplicationCommandPermission*(data: JsonNode): ApplicationCommandPermission =
    result = ApplicationCommandPermission(
        id: data["id"].str,
        kind: ApplicationCommandPermissionType data["type"].getInt(),
        permission: data["permission"].getBool(true)
    )

proc newGuildApplicationCommandPermissions*(data: JsonNode): GuildApplicationCommandPermissions =
    result = GuildApplicationCommandPermissions(
        id: data["id"].str,
        application_id: data["application_id"].str,
        guild_id: data["guild_id"].str
    )
    result.permissions = data["permissions"].getElems.map newApplicationCommandPermission

proc newApplicationCommand*(data: JsonNode): ApplicationCommand =
    result = ApplicationCommand(
        id: data["id"].str,
        kind: ApplicationCommandType data["type"].getInt(),
        application_id: data["application_id"].str,
        name: data["name"].str,
        description: data["description"].str,
        options: data{"options"}.getElems.map newApplicationCommandOption,
        default_permission: data["default_permission"].getBool(true)
    )


proc toPartial(emoji: Emoji): JsonNode =
    ## Creates a partial emoji from an Emoji object
    result = %* { # create partial emoji
        "name": emoji.name,
        "id": emoji.id,
        "animated": emoji.animated
    }

proc `%`(option: SelectMenuOption): JsonNode =
    result = %* {
        "label": option.label,
        "value": option.value,
        "description": option.description,
        "default": option.default.get(false)
    }
    if option.emoji.isSome:
        result["emoji"] = option.emoji.get().toPartial()

proc `%`*(permission: ApplicationCommandPermission): JsonNode =
    result = %* {
        "id": %permission.id,
        "type": %ord(permission.kind),
        "permission": %permission.permission
    }

proc `%%*`*(comp: MessageComponent): JsonNode =
    result = %*{"type": comp.kind.ord}
    case comp.kind:
        of None: discard
        of ActionRow:
            result["components"] = newJArray()
            for child in comp.components:
                result["components"] &= %%* child
        of Button:
            result["custom_id"] = %comp.customID.get()
            result["label"] = %comp.label
            result["style"] = %comp.style.ord
            if comp.emoji.isSome:
                result["emoji"] = comp.emoji.get().toPartial()
            result["url"] = %comp.url
        of SelectMenu:
            result["custom_id"] = %comp.customID.get()
            result["options"] = %comp.options
            result["placeholder"] = %comp.placeholder
            result["min_values"] = %comp.minValues
            result["max_values"] = %comp.maxValues