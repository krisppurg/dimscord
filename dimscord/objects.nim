##[
    All Optional fields in these object are:
    
    * Fields that cannot be assumed. such as bools
    * Optional fields for example embeds, which they may not be
      present.
    
    Some may not be optional, but they can be assumable or always present.
]##

import options, json, tables, constants, macros
import sequtils, strutils, asyncdispatch, ws

type
    DiscordClient* = ref object
        api*: RestApi
        events*: Events
        token*: string
        shards*: Table[int, Shard]
        restMode*, autoreconnect*, guildSubscriptions*: bool
        largeThreshold*, gatewayVersion*, maxShards*: int
        intents*: set[GatewayIntent]
    Shard* = ref object
        ## This is where you interact with the gateway api with.
        ## It's basically a gateway connection.
        id*, sequence*: int
        client*: DiscordClient
        user*: User
        gatewayUrl*, session_id*: string
        cache*: CacheTable
        connection*: Websocket
        hbAck*, hbSent*, stop*: bool
        lastHBTransmit*, lastHBReceived*: float
        retry_info*: tuple[ms, attempts: int]
        heartbeating*, resuming*, reconnecting*: bool
        authenticating*, networkError*, ready*: bool
        interval*: int
    CacheTable* = ref object
        preferences*: CacheTablePrefs
        users*: Table[string, User]
        guilds*: Table[string, Guild]
        guildChannels*: Table[string, GuildChannel]
        dmChannels*: Table[string, DMChannel]
    CacheTablePrefs* = object
        cache_users*, cache_guilds*: bool
        cache_guild_channels*, cache_dm_channels*: bool
        large_message_threshold*, max_message_size*: int
    CacheError* = object of KeyError
    Embed* = object
        title*, `type`*, description*: Option[string]
        url*, timestamp*: Option[string]
        color*: Option[int]
        footer*: Option[EmbedFooter]
        image*: Option[EmbedImage]
        thumbnail*: Option[EmbedThumbnail]
        video*: Option[EmbedVideo]
        provider*: Option[EmbedProvider]
        author*: Option[EmbedAuthor]
        fields*: Option[seq[EmbedField]]
    EmbedThumbnail* = object
        url*, proxy_url*: Option[string]
        height*, width*: Option[int]
    EmbedVideo* = object
        url*: Option[string]
        height*, width*: Option[int]
    EmbedImage* = object
        url*, proxy_url*: Option[string]
        height*, width*: Option[int]
    EmbedProvider* = object
        name*, url*: Option[string]
    EmbedAuthor* = object
        name*, url*: Option[string]
        icon_url*, proxy_icon_url*: Option[string]
    EmbedFooter* = object
        text*: string
        icon_url*, proxy_icon_url*: Option[string]
    EmbedField* = object
        name*, value*: string
        inline*: Option[bool]
    MentionChannel* = object
        id*, guild_id*, name*: string
        kind*: int
    MessageReference* = object
        channel_id*: string
        message_id*, guild_id*: Option[string]
    Message* = ref object
        id*, channel_id*: string
        content*, timestamp*: string
        edited_timestamp*, guild_id*: Option[string]
        webhook_id*, nonce*: Option[string]
        tts*, mention_everyone*, pinned*: bool
        kind*, flags*: int
        author*: User
        member*: Option[Member]
        mention_users*: seq[User]
        mention_roles*: seq[string]
        mention_channels*: seq[MentionChannel]
        attachments*: seq[Attachment]
        embeds*: seq[Embed]
        reactions*: Table[string, Reaction]
        activity*: Option[tuple[kind: int, party_id: string]]
        application*: Option[Application]
        message_reference*: Option[MessageReference]
    User* = ref object
        id*, username*, discriminator*: string
        bot*, system*: bool
        premium_type*, flags*: Option[int]
        public_flags*: Option[int]
        avatar*: Option[string]
    Member* = ref object
        user*: User
        nick*, premium_since*: Option[string]
        joined_at*: string
        roles*: seq[string]
        deaf*, mute*: bool
        presence*: Presence
        voice_state*: Option[VoiceState]
    Attachment* = object
        id*, filename*: string
        proxy_url*, url*: string
        height*, width*: Option[int]
        size*: int
    Reaction* = object
        count*: int
        emoji*: Emoji
        reacted*: bool
    Emoji* = object
        id*, name*: Option[string]
        require_colons*, managed*, animated*: Option[bool]
        user*: Option[User]
        roles*: seq[string]
    Application* = object
        id*, cover_image*: string
        description*, icon*, name*: string
    RestApi* = ref object
        token*: string
        endpoints*: Table[string, Ratelimit]
        restVersion*: int
    Ratelimit* = ref object
        retry_after*: float
        processing*, ratelimited*: bool
    UnavailableGuild* = object
        id*: string
        unavailable*: bool
    Ready* = object
        v*: int
        user*: User
        guilds*: seq[UnavailableGuild]
        session_id*: string
        shard*: Option[seq[int]]
    DMChannel* = ref object
        id*, last_message_id*: string
        kind*: int
        recipients*: seq[User]
        messages*: Table[string, Message]
    GuildChannel* = ref object
        id*, name*, guild_id*: string
        last_message_id*: string
        kind*, position*, rate_limit_per_user*: int
        bitrate*, user_limit*: int
        parent_id*, topic*: Option[string]
        permission_overwrites*: Table[string, Overwrite]
        messages*: Table[string, Message]
        nsfw*: bool
    GameAssets* = object
        small_text*, small_image*: string
        large_text*, large_image*: string
    GameActivity* = object
        name*: string
        kind*, flags*: int
        url*, application_id*, details*, state*: Option[string]
        created_at*: BiggestInt
        timestamps*: Option[tuple[start, final: BiggestInt]]
        emoji*: Option[Emoji]
        party*: Option[tuple[id: string, size: seq[int]]]
        assets*: Option[GameAssets]
        secrets*: Option[tuple[join, spectate, match: string]]
        instance*: bool
    Presence* = object
        user*: User
        game*: Option[GameActivity]
        guild_id*, status*: string
        activities*: seq[GameActivity]
        client_status*: tuple[web, desktop, mobile: string]
    Guild* = ref object
        id*, name*, owner_id*: string
        region*, preferred_locale*: string
        permissions_new*: Option[string]
        description*, banner*: Option[string]
        public_updates_channel_id*: Option[string]
        icon*, splash*, discovery_splash*: Option[string]
        afk_channel_id*, vanity_url_code*, application_id*: Option[string]
        widget_channel_id*, system_channel_id*, joined_at*: Option[string]
        owner*, widget_enabled*: bool
        large*, unavailable*: Option[bool]
        max_video_channel_uses*: Option[int]
        permissions*, afk_timeout*, member_count*: Option[int]
        approximate_member_count*, approximate_presence_count*: Option[int]
        max_presences*, max_members*, premium_subscription_count*: Option[int]
        explicit_content_filter*, mfa_level*, premium_tier*: int
        verification_level*, default_message_notifications*: int
        features*: seq[string]
        roles*: Table[string, Role]
        emojis*: Table[string, Emoji]
        voice_states*: Table[string, VoiceState]
        members*: Table[string, Member]
        channels*: Table[string, GuildChannel]
        presences*: Table[string, Presence]
    VoiceState* = ref object
        guild_id*, channel_id*: Option[string]
        user_id*, session_id*: string
        deaf*, mute*, suppress*: bool
        self_deaf*, self_mute*, self_stream*: bool
    Role* = object
        id*, name*, permissions_new*: string
        color*, position*, permissions*: int
        hoist*, managed*, mentionable*: bool
    GameStatus* = object
        ## This is used for status updates.
        name*: string
        kind*: int
        url*: Option[string]
    Overwrite* = object
        id*, kind*: string
        allow*, deny*: int
        allow_new*, deny_new*: string
        permObj*: PermObj
    PermObj* = object
        allowed*, denied*: set[PermEnum]
    PartialGuild* = object
        id*, name*: string
        icon*, splash*: Option[string]
    PartialChannel* = object
        id*, name*: string
        kind*: int
    Channel* = object
        ## Used for creating guilds.
        name*, parent_id*: string
        id*, kind*: int
    TeamMember* = object
        membership_state*: int
        permissions*: seq[string] ## always would be @["*"]
        team_id*: string
        user*: User
    Team* = object
        icon*: Option[string]
        id*, owner_user_id*: string
        members*: seq[TeamMember]
    OAuth2Application* = object
        id*, name*: string
        description*, summary*: string
        verify_key*: string
        icon*, guild_id*, primary_sku_id*: Option[string]
        slug*, cover_image*: Option[string]
        rpc_origins*: seq[string]
        bot_public*, bot_require_code_grant*: bool
        owner*: User
        team*: Option[Team]
    Invite* = object
        code*: string
        guild*: Option[PartialGuild]
        channel*: PartialChannel
        inviter*, target_user*: Option[User]
        target_user_type*: Option[int]
        approximate_presence_count*, approximate_member_count*: Option[int]
    InviteMetadata* = object
        code*, created_at*: string
        guild_id*: Option[string]
        uses*, max_uses*, max_age*: int
        temporary*: bool
    InviteCreate* = object
        code*, created_at*: string
        guild_id*: Option[string]
        uses*, max_uses*, max_age*: int
        channel_id*: string
        inviter*, target_user*: Option[User]
        target_user_type*: Option[int]
        temporary*: bool
    TypingStart* = object
        channel_id*, user_id*: string
        guild_id*: Option[string]
        member*: Option[Member]
        timestamp*: int
    GuildMembersChunk* = object
        guild_id*: string
        nonce*: Option[string]
        chunk_index*, chunk_count*: int
        members*: seq[Member]
        not_found*: seq[string]
        presences*: seq[Presence]
    GuildBan* = object
        user*: User
        reason*: Option[string]
    Webhook* = object
        id*, channel_id*: string
        kind*: int
        guild_id*, avatar*: Option[string]
        name*, token*: Option[string]
        user*: Option[User]
    Integration* = object
        id*, name*, kind*: string
        role_id*, synced_at*: string
        enabled*, syncing*: bool
        enable_emoticons*: Option[bool]
        expire_behavior*, expire_grace_period*: int
        user*: User
        account*: tuple[id, name: string]
    GuildPreview* = object
        id*, name*: string
        icon*, splash, emojis*: Option[string]
        discovery_splash*, description*: Option[string]
        approximate_member_count*, approximate_presence_count*: int
    VoiceRegion* = object
        id*, name*: string
        vip*, optimal*: bool
        deprecated*, custom*: bool
    AuditLogOptions* = object
        delete_member_days*, members_removed*: Option[string]
        channel_id*, count*: Option[string]
        id*, role_name*: Option[string]
        kind*: Option[string] ## ("member" or "role")
    AuditLogChangeValue* = object
        case kind*: AuditLogChangeKind
        of alcString:
            str*: string
        of alcInt:
            ival*: int
        of alcBool:
            bval*: bool
        of alcRoles:
            roles*: seq[tuple[id, name: string]]
        of alcOverwrites:
            overwrites*: seq[Overwrite]
        of alcNil:
            nil
    AuditLogEntry* = ref object
        target_id*, reason*: Option[string]
        before*, after*: Table[string, AuditLogChangeValue]
        opts*: Option[AuditLogOptions]
        user_id*, id*: string
        action_type*: int
    AuditLog* = object
        webhooks*: seq[Webhook]
        users*: seq[User]
        audit_log_entries*: seq[AuditLogEntry]
        integrations*: seq[Integration]
    GatewaySession* = object
        total*, remaining*: int
        reset_after*, max_concurrency*: int
    GatewayBot* = object
        url*: string
        shards*: int
        session_start_limit*: GatewaySession
    Events* = ref object
        ## An object containing events that can be changed.
        ## 
        ## - `exists` Checks message is cached or not. Other cachable objects dont have them.
        ## 
        ## - `on_dispatch` event gives you the raw event data for you to handle things.
        ## [For reference](https://discord.com/developers/docs/topics/gateway#commands-and-events-gateway-events)
        on_dispatch*: proc (s: Shard, evt: string, data: JsonNode) {.async.}
        on_ready*: proc (s: Shard, r: Ready) {.async.}
        on_disconnect*: proc (s: Shard) {.async.}
        message_create*: proc (s: Shard, m: Message) {.async.}
        message_delete*: proc (s: Shard, m: Message, exists: bool) {.async.}
        message_update*: proc (s: Shard, m: Message,
                o: Option[Message], exists: bool) {.async.}
        message_reaction_add*, message_reaction_remove*: proc (s: Shard,
                m: Message, u: User,
                r: Reaction, exists: bool) {.async.}
        message_reaction_remove_all*: proc (s: Shard, m: Message,
                exists: bool) {.async.}
        message_reaction_remove_emoji*: proc (s: Shard, m: Message,
                e: Emoji, exists: bool) {.async.}
        message_delete_bulk*: proc (s: Shard, m: seq[tuple[
                msg: Message, exists: bool]]) {.async.}
        channel_create*: proc (s: Shard, g: Option[Guild],
                c: Option[GuildChannel], d: Option[DMChannel]) {.async.}
        channel_update*: proc (s: Shard, g: Guild,
                c: GuildChannel, o: Option[GuildChannel]) {.async.}
        channel_delete*: proc (s: Shard, g: Option[Guild],
                c: Option[GuildChannel], d: Option[DMChannel]) {.async.}
        channel_pins_update*: proc (s: Shard, cid: string,
                g: Option[Guild], last_pin: Option[string]) {.async.}
        presence_update*: proc (s: Shard, p: Presence,
                o: Option[Presence]) {.async.}
        typing_start*: proc (s: Shard, t: TypingStart) {.async.}
        guild_emojis_update*: proc (s: Shard, g: Guild, e: seq[Emoji]) {.async.}
        guild_ban_add*, guild_ban_remove*: proc (s: Shard, g: Guild,
                u: User) {.async.}
        guild_integrations_update*: proc (s: Shard, g: Guild) {.async.}
        guild_member_add*, guild_member_remove*: proc (s: Shard, g: Guild,
                m: Member) {.async.}
        guild_member_update*: proc (s: Shard, g: Guild,
                m: Member, o: Option[Member]) {.async.}
        guild_update*: proc (s: Shard, g: Guild, o: Option[Guild]) {.async.}
        guild_create*, guild_delete*: proc (s: Shard, g: Guild) {.async.}
        guild_members_chunk*: proc (s: Shard, g: Guild,
                m: GuildMembersChunk) {.async.}
        guild_role_create*, guild_role_delete*: proc (s: Shard, g: Guild,
                r: Role) {.async.}
        guild_role_update*: proc (s: Shard, g: Guild,
                r: Role, o: Option[Role]) {.async.}
        invite_create*: proc (s: Shard, i: InviteCreate) {.async.}
        invite_delete*: proc (s: Shard, g: Option[Guild],
                cid, code: string) {.async.}
        user_update*: proc (s: Shard, u: User) {.async.}
        voice_state_update*: proc (s: Shard, v: VoiceState,
                o: Option[VoiceState]) {.async.}
        voice_server_update*: proc (s: Shard, g: Guild,
                token: string, e: Option[string]) {.async.}
        webhooks_update*: proc (s: Shard, g: Guild, c: GuildChannel) {.async.}

proc kind*(c: CacheTable, channel_id: string): int =
    ## Checks for a channel kind. (Shortcut)
    if channel_id in c.dmChannels:
        result = c.dmChannels[channel_id].kind
    elif channel_id in c.guildChannels:
        result = c.guildChannels[channel_id].kind
    else:
        raise newException(CacheError, "Channel doesn't exist in cache.")

proc clear*(c: CacheTable) =
    ## Empties cache.
    c.users.clear()
    c.guilds.clear()
    c.guildChannels.clear()
    c.dmChannels.clear()

proc `$`*(e: Emoji): string =
    result = if e.id.isSome:
            e.name.get("?") & ":" & e.id.get
        else:
            e.name.get("?")

macro keyCheckOptInt(obj: typed, obj2: typed,
                        lits: varargs[untyped]): untyped =
  result = newStmtList()
  for lit in lits:
    let fieldName = lit.strVal
    result.add quote do:
      if `fieldName` in `obj` and `obj`[`fieldName`].kind != JNull:
        `obj2`.`lit` = some `obj`[`fieldName`].getInt

macro keyCheckInt(obj: typed, obj2: typed,
                        lits: varargs[untyped]): untyped =
  result = newStmtList()
  for lit in lits:
    let fieldName = lit.strVal
    result.add quote do:
      if `fieldName` in `obj` and `obj`[`fieldName`].kind != JNull:
        `obj2`.`lit` = `obj`[`fieldName`].getInt

macro keyCheckOptBool(obj: typed, obj2: typed,
                        lits: varargs[untyped]): untyped =
  result = newStmtList()
  for lit in lits:
    let fieldName = lit.strVal
    result.add quote do:
      if `fieldName` in `obj` and `obj`[`fieldName`].kind != JNull:
        `obj2`.`lit` = some `obj`[`fieldName`].getBool

macro keyCheckBool(obj: typed, obj2: typed,
                        lits: varargs[untyped]): untyped =
  result = newStmtList()
  for lit in lits:
    let fieldName = lit.strVal
    result.add quote do:
      if `fieldName` in `obj` and `obj`[`fieldName`].kind != JNull:
        `obj2`.`lit` = `obj`[`fieldName`].getBool

macro keyCheckOptStr(obj: typed, obj2: typed,
                        lits: varargs[untyped]): untyped =
  result = newStmtList()
  for lit in lits:
    let fieldName = lit.strVal
    result.add quote do:
      if `fieldName` in `obj` and `obj`[`fieldName`].kind != JNull:
        `obj2`.`lit` = some `obj`[`fieldName`].getStr

macro keyCheckStr(obj: typed, obj2: typed,
                        lits: varargs[untyped]): untyped =
  result = newStmtList()
  for lit in lits:
    let fieldName = lit.strVal
    result.add quote do:
      if `fieldName` in `obj` and `obj`[`fieldName`].kind != JNull:
        `obj2`.`lit` = `obj`[`fieldName`].getStr

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
        api: RestApi(token: auth_token, restVersion: restVersion),
        max_shards: 1,
        restMode: rest_mode,
        events: Events(
            on_dispatch: proc (s: Shard, evt: string,
                    data: JsonNode) {.async.} = discard,
            on_ready: proc (s: Shard, r: Ready) {.async.} = discard,
            message_create: proc (s: Shard, m: Message) {.async.} = discard,
            message_delete: proc (s: Shard, m: Message,
                    exists: bool) {.async.} = discard,
            message_update: proc (s: Shard, m: Message,
                    o: Option[Message], exists: bool) {.async.} = discard,
            message_reaction_add: proc (s: Shard, m: Message,
                    u: User, r: Reaction, exists: bool) {.async.} = discard,
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
            invite_create: proc (s: Shard, i: InviteCreate) {.async.} = discard,
            invite_delete: proc (s: Shard, g: Option[Guild],
                    c, code: string) {.async.} = discard,
            user_update: proc (s: Shard, u: User) {.async.} = discard,
            voice_state_update: proc (s: Shard, v: VoiceState,
                    o: Option[VoiceState]) {.async.} = discard,
            voice_server_update: proc (s: Shard, g: Guild,
                    token: string,
                    e: Option[string]) {.async.} = discard,
            webhooks_update: proc (s: Shard, g: Guild,
                    c: GuildChannel) {.async.} = discard
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
    result = Overwrite(
        id: data["id"].str,
        kind: data["type"].str,
        allow: data["allow"].getInt,
        deny: data["deny"].getInt,
        allow_new: data["allow_new"].str,
        deny_new: data["deny_new"].str
    )

    if result.allow != 0:
        result.permObj.allowed = cast[set[PermEnum]](result.allow)

    if result.deny != 0:
        result.permObj.denied = cast[set[PermEnum]](result.deny)

proc newRole*(data: JsonNode): Role =
    result = Role(
        id: data["id"].str,
        name: data["name"].str,
        color: data["color"].getInt,
        hoist: data["hoist"].bval,
        position: data["position"].getInt,
        permissions: data["permissions"].getInt,
        permissions_new: data["permissions_new"].str,
        managed: data["managed"].bval,
        mentionable: data["mentionable"].bval
    )

proc newGuildChannel*(data: JsonNode): GuildChannel =
    result = GuildChannel(
        id: data["id"].str,
        name: data["name"].str,
        kind: data["type"].getInt,
        guild_id: data["guild_id"].str,
        position: data["position"].getInt,
        last_message_id: data{"last_message_id"}.getStr
    )

    for ow in data["permission_overwrites"].getElems:
        result.permission_overwrites.add(ow["id"].str, newOverwrite(ow))

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
        kind: data["type"].getInt,
        channel_id: data["channel_id"].str)

    if "user" in data:
        result.user = some newUser(data["user"])

    data.keyCheckOptStr(result, guild_id, token, name, avatar)

proc newGuildBan*(data: JsonNode): GuildBan =
    result = GuildBan(user: newUser(data["user"]))

    data.keyCheckOptStr(result, reason)

proc newDMChannel*(data: JsonNode): DMChannel =
    result = DMChannel(
        id: data["id"].str,
        kind: data["type"].getInt,
        messages: initTable[string, Message]()
    )

    for r in data["recipients"].elems:
        result.recipients.add(newUser(r))

proc newInvite*(data: JsonNode): Invite =
    result = Invite(
        code: data["code"].str,
        channel: PartialChannel(
            id: data["channel"]["id"].str,
            kind: data["channel"]["type"].getInt,
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

proc newGameActivity*(data: JsonNode): GameActivity =
    result = GameActivity(
        name: data["name"].str,
        kind: data["type"].getInt,
        created_at: data["created_at"].num,
        flags: data{"flags"}.getInt
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
        result.activities.add(newGameActivity(activity))

    if data["game"].kind != JNull:
        result.game = some newGameActivity(data["game"])

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

    if "user" in data and data["user"].kind != JNull:
        result.user = newUser(data["user"])

    data.keyCheckOptStr(result, nick, premium_since)

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

    data.keyCheckInt(result, kind, flags)
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
        kind: data["type"].getInt,
        flags: data["flags"].getInt,
        reactions: initTable[string, Reaction]()
    )
    data.keyCheckOptStr(result, edited_timestamp,
        guild_id, nonce, webhook_id)

    if "author" in data:
        result.author = newUser(data["author"])
    if "member" in data and data["member"].kind != JNull:
        result.member = some newMember(data["member"])

    for r in data{"mention_roles"}.getElems:
        result.mention_roles.add(r.str)

    for usr in data{"mentions"}.getElems:
        result.mention_users.add(newUser(usr))

    for chan in data{"mention_channels"}.getElems:
        result.mention_channels.add(MentionChannel(
            id: chan["id"].str,
            guild_id: chan["guild_id"].str,
            kind: chan["type"].getInt,
            name: chan["name"].str
        ))

    for attach in data{"attachments"}.getElems:
        result.attachments.add(newAttachment(attach))

    for embed in data{"embeds"}.getElems:
        result.embeds.add(embed.to(Embed))
    for reaction in data{"reactions"}.getElems:
        let rtn = newReaction(reaction)
        result.reactions.add($rtn.emoji, rtn)

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
        action_type: data["action_type"].getInt
    )
    data.keyCheckOptStr(result, target_id, reason)

    if "options" in data:
        result.opts = some data.to(AuditLogOptions)

    for change in data{"changes"}.getElems:
        if "new_value" in change:
            result.after.add(change["key"].str, newAuditLogChangeValue(
                change["new_value"],
                change["key"].str
            ))
        if "old_value" in change:
            result.before.add(change["key"].str, newAuditLogChangeValue(
                change["old_value"],
                change["key"].str
            ))

proc newAuditLog*(data: JsonNode): AuditLog =
    result = AuditLog(
        webhooks: data["webhooks"].elems.map(newWebhook),
        users: data["users"].elems.map(newUser),
        audit_log_entries: data["audit_log_entries"].elems.map(newAuditLogEntry),
        integrations: data["integrations"].elems.map(proc (x: JsonNode): Integration =
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
                    membership_state: x["membership_state"].getInt,
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

    if "team" in data:
        result.team = some newTeam(data["team"])

proc newGuild*(data: JsonNode): Guild =
    result = Guild(
        id: data["id"].str,
        name: data["name"].str,
        owner: data{"owner"}.getBool,
        owner_id: data["owner_id"].str,
        region: data["region"].str,
        widget_enabled: data{"widget_enabled"}.getBool,
        verification_level: data["verification_level"].getInt,
        explicit_content_filter: data["explicit_content_filter"].getInt,
        default_message_notifications: data["default_message_notifications"].getInt,
        roles: initTable[string, Role](),
        emojis: initTable[string, Emoji](),
        voice_states: initTable[string, VoiceState](),
        members: initTable[string, Member](),
        channels: initTable[string, GuildChannel](),
        presences: initTable[string, Presence](),
        mfa_level: data["mfa_level"].getInt,
        premium_tier: data["premium_tier"].getInt,
        preferred_locale: data["preferred_locale"].str)

    for r in data["roles"].elems:
        result.roles.add(r["id"].str, newRole(r))
    for e in data["emojis"].elems:
        result.emojis.add(e["id"].str, newEmoji(e))

    data.keyCheckOptInt(result, afk_timeout, permissions, member_count,
        premium_subscription_count, max_presences, approximate_member_count,
        approximate_presence_count, max_video_channel_uses)
    data.keyCheckOptStr(result, joined_at, icon, splash, afk_channel_id,
        permissions_new, application_id, system_channel_id, vanity_url_code,
        discovery_splash, description, banner, widget_channel_id,
        public_updates_channel_id)
    data.keyCheckOptBool(result, large, unavailable)

    for m in data{"members"}.getElems:
        result.members.add(m["user"]["id"].str, newMember(m))

    for v in data{"voice_states"}.getElems:
        let state = newVoiceState(v)

        result.members[v["user_id"].str].voice_state = some state
        result.voice_states.add(v["user_id"].str, state)

    for chan in data{"channels"}.getElems:
        chan["guild_id"] = %result.id
        result.channels.add(chan["id"].str, newGuildChannel(chan))

    for p in data{"presences"}.getElems:
        let presence = newPresence(p)
        let uid = presence.user.id

        result.members[uid].presence = presence
        result.presences.add(uid, presence)