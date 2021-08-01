import options as optns, json, asyncdispatch
import tables, ../constants
from ws import Websocket

type
    RestError* = object of CatchableError
    DiscordFile* = ref object
        ## A Discord file.
        name*, body*: string
    AllowedMentions* = object
        ## An object of allowed mentions.
        ## For parse: The values should be "roles", "users", "everyone"
        parse*, roles*, users*: seq[string]
        replied_user*: bool
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
        ## 
        ## For `voiceConnections`, the string is a guild_id.
        id*, sequence*: int
        client*: DiscordClient
        user*: User
        gatewayUrl*, session_id*: string
        cache*: CacheTable
        voiceConnections*: Table[string, VoiceClient]
        connection*: Websocket
        hbAck*, hbSent*, stop*: bool
        lastHBTransmit*, lastHBReceived*: float
        retry_info*: tuple[ms, attempts: int]
        heartbeating*, resuming*, reconnecting*: bool
        authenticating*, networkError*, ready*: bool
        interval*: int
    VoiceClient* = ref object
        shard*: Shard
        voice_events*: VoiceEvents
        endpoint*, token*: string
        session_id*, guild_id*, channel_id*: string
        connection*: WebSocket
        hbAck*, hbSent*, stop*: bool
        lastHBTransmit*, lastHBReceived*: float
        retry_info*: tuple[ms, attempts: int]
        heartbeating*, resuming*, reconnecting*: bool
        networkError*, ready*: bool
        interval*: int
    VoiceEvents* = ref object
        on_dispatch*: proc (v: VoiceClient,
                            d: JsonNode, event: string) {.async.}
        on_speaking*: proc (v: VoiceClient,
                            speaking: bool) {.async.}
        on_ready*, on_disconnect*: proc (v: VoiceClient) {.async.}
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
        url*, proxy_url*: Option[string]
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
        kind*: ChannelType
    MessageReference* = object
        channel_id*: Option[string]
        message_id*, guild_id*: Option[string]
        fail_if_not_exists*: Option[bool]
    Message* = ref object
        ## - `sticker_items` == Table[sticker_id, object]
        ## - `reactions` == Table["REACTION_EMOJI", object]
        id*, channel_id*: string
        content*, timestamp*: string
        edited_timestamp*, guild_id*: Option[string]
        webhook_id*, nonce*, application_id*: Option[string]
        tts*, mention_everyone*, pinned*: bool
        kind*: MessageType
        flags*: set[MessageFlags]
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
        sticker_items*: Table[string, tuple[
            id, name: string,
            format_type: MessageStickerFormat
        ]]
        referenced_message*: Option[Message]
    User* = ref object
        ## The fields for bot and system are false by default
        ## simply because they are assumable.
        id*, username*, discriminator*: string
        bot*, system*: bool
        mfa_enabled*: Option[bool]
        premium_type*: Option[int]
        flags*: set[UserFlags]
        public_flags*: set[UserFlags]
        avatar*, locale*: Option[string]
    Member* = ref object
        ## - `permissions` Returned in the interaction object.
        user*: User
        nick*, premium_since*: Option[string]
        joined_at*: string
        roles*: seq[string]
        deaf*, mute*: bool
        pending*: Option[bool]
        permissions*: set[PermissionFlags]
        presence*: Presence
        voice_state*: Option[VoiceState]
    Attachment* = object
        id*, filename*: string
        content_type*: Option[string]
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
    PartialUser* = object
        id*, username*, discriminator*: string
        avatar*: Option[string]
        public_flags*: set[UserFlags]
        bot*: bool
    Sticker* = object
        id*: string
        name*, description*, tags*: string
        guild_id*, pack_id*, format_asset*: Option[string]
        format_type*: MessageStickerFormat
        available*: Option[bool]
        user*: Option[User]
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
        application*: tuple[id: string, flags: set[ApplicationFlags]]
    DMChannel* = ref object
        id*, last_message_id*: string
        kind*: ChannelType
        recipients*: seq[User]
        messages*: Table[string, Message]
    GuildChannel* = ref object
        id*, name*, guild_id*: string
        last_message_id*: string
        kind*: ChannelType
        position*, rate_limit_per_user*: int
        bitrate*, user_limit*: int
        rtc_region*, parent_id*, topic*: Option[string]
        video_quality_mode*, message_count*, member_count*: Option[int]
        default_auto_archive_duration*: Option[int]
        permission_overwrites*: Table[string, Overwrite]
        messages*: Table[string, Message]
        permissions*: set[PermissionFlags]
        nsfw*: bool
        thread_metadata*: Option[ThreadMetadata]
        member*: Option[ThreadMember] # I swear if I get anyone joining my
    StageInstance* = object # server for threads im gonna ban 'em :)
        id*: string
        guild_id*: string
        channel_id*: string
        topic*: string
        privacy_level*: PrivacyLevel
        discoverable_disabled*: bool
    ThreadMetadata* = object
        archived*: bool
        archiver_id*: Option[string]
        auto_archive_duration*: int
        archive_timestamp*: string
        locked*: Option[bool]
    ThreadMember* = object
        ## - `id` The thread id the member is in.
        id*, user_id*: Option[string]
        join_timestamp*: string
        flags*: int
    GameAssets* = object
        small_text*, small_image*: string
        large_text*, large_image*: string
    Activity* = object
        name*: string
        kind*: ActivityType
        flags*: set[ActivityFlags]
        url*, application_id*, details*, state*: Option[string]
        created_at*: BiggestInt
        timestamps*: Option[tuple[start, final: BiggestInt]]
        emoji*: Option[Emoji]
        party*: Option[tuple[id: string, size: seq[int]]]
        assets*: Option[GameAssets]
        secrets*: Option[tuple[join, spectate, match: string]]
        instance*: bool
    Presence* = ref object
        user*: User
        when not defined(discordv8):
            activity*: Option[Activity]
        guild_id*, status*: string
        activities*: seq[Activity]
        client_status*: tuple[web, desktop, mobile: string]
    WelcomeChannel* = object
        channel_id*, description: string
        emoji_id*, emoji_name*: Option[string]
    Guild* = ref object
        id*, name*, owner_id*: string
        preferred_locale*: string
        rtc_region*, permissions_new*: Option[string]
        icon_hash*, description*, banner*: Option[string]
        public_updates_channel_id*: Option[string]
        icon*, splash*, discovery_splash*: Option[string]
        afk_channel_id*, vanity_url_code*, application_id*: Option[string]
        widget_channel_id*, system_channel_id*, joined_at*: Option[string]
        system_channel_flags*: set[SystemChannelFlags]
        nsfw*, owner*, widget_enabled*: bool
        large*, unavailable*: Option[bool]
        max_video_channel_uses*: Option[int]
        permissions*, afk_timeout*, member_count*: Option[int]
        approximate_member_count*, approximate_presence_count*: Option[int]
        max_presences*, max_members*, premium_subscription_count*: Option[int]
        explicit_content_filter*: ExplicitContentFilter
        welcome_screen*: Option[tuple[
            description: Option[string],
            welcome_channels: seq[WelcomeChannel]
        ]]
        mfa_level*: MFALevel
        nsfw_level*: GuildNSFWLevel
        premium_tier*: PremiumTier
        verification_level*: VerificationLevel
        default_message_notifications*: MessageNotificationLevel
        features*: seq[string]
        roles*: Table[string, Role]
        emojis*: Table[string, Emoji]
        voice_states*: Table[string, VoiceState]
        members*: Table[string, Member]
        channels*: Table[string, GuildChannel]
        presences*: Table[string, Presence]
        stage_instances*: Table[string, StageInstance]

    VoiceState* = ref object
        guild_id*, channel_id*: Option[string]
        user_id*, session_id*: string
        deaf*, mute*, suppress*: bool
        self_deaf*, self_mute*, self_stream*: bool
        request_to_speak_timestamp*: Option[string]
    Role* = object
        id*, name*, permissions_new*: string
        color*, position*: int
        permissions*: set[PermissionFlags]
        hoist*, managed*, mentionable*: bool
    GuildTemplate* = object
        code*, name*, creator_id*: string
        description*: Option[string]
        usage_count*: int
        creator*: User
        source_guild_id*, updated_at*, created_at*: string
        serialized_source_guild*: PartialGuild
        is_dirty*: Option[bool]
    ActivityStatus* = object
        ## This is used for status updates.
        name*: string
        kind*: ActivityType
        url*: Option[string]
    Overwrite* = object
        ## - `kind` will be either ("role" or "member") or ("0" or "1")
        id*: string
        when defined(discordv8):
            kind*: int
        else:
            kind*: string
            allow_new*, deny_new*: string
        allow*, deny*: set[PermissionFlags]
    PermObj* = object
        allowed*, denied*: set[PermissionFlags]
    PartialGuild* = object
        id*, name*: string
        icon*, splash*: Option[string]
    PartialChannel* = object
        id*, name*: string
        kind*: ChannelType
    Channel* = object
        ## Used for creating guilds.
        name*, parent_id*: string
        id*, kind*: int
    TeamMember* = object
        membership_state*: TeamMembershipState
        permissions*: seq[string] ## always would be @["*"]
        team_id*: string
        user*: User
    Team* = object
        icon*: Option[string]
        name*: string
        id*, owner_user_id*: string
        members*: seq[TeamMember]
    Application* = object
        id*, description*, name*: string
        rpc_origins*: seq[string]
        bot_public*, bot_require_code_grant*: bool
        terms_of_service_url*, privacy_policy_url*: Option[string]
        guild_id*: Option[string]
        owner*: User
        summary*, verify_key*: string
        team*: Option[Team]
        icon*, primary_sku_id*, slug*, cover_image*: Option[string]
        flags*: set[ApplicationFlags]
    ApplicationCommand* = object
        id*, application_id*: string
        name*, description*: string
        options*: seq[ApplicationCommandOption]
    ApplicationCommandOption* = object
        kind*: ApplicationCommandOptionType
        name*, description*: string
        default*, required*: Option[bool]
        choices*: seq[ApplicationCommandOptionChoice]
        options*: seq[ApplicationCommandOption]
    ApplicationCommandOptionChoice* = object
        name*: string
        value*: (Option[string], Option[int])
    Interaction* = object
        ## if `member` is present, then that means the interaction is in guild,
        ## and `user` is therefore not present.
        ##
        ## if `user` is present and `member` isn't, then that means that the
        ## interaction is in a DM.
        id*, channel_id*: string
        guild_id*: Option[string]
        kind*: InteractionType
        member*: Option[Member]
        user*: Option[User]
        token*: string
        data*: Option[ApplicationCommandInteractionData]
        version*: int
    ApplicationCommandInteractionData* = ref object
        ## `options` Table[option_name, obj]
        id*, name*: string
        options*: Table[string, ApplicationCommandInteractionDataOption]

    ApplicationCommandInteractionDataOption* = object
        name*: string
        case kind*: ApplicationCommandOptionType
            of acotNothing: discard
            of acotBool:
                bval*: bool
            of acotInt:
                ival*: int
            of acotStr:
                str*: string
            of acotUser:
                userID*: string
            of acotChannel:
                channelID*: string
            of acotRole:
                roleID*: string
            of acotSubCommand, acotSubCommandGroup:
                options*: Table[string, ApplicationCommandInteractionDataOption]
            of acotNumber:
                fval*: float
            of acotMentionable:
                mentionID*: string
    InteractionResponse* = object
        kind*: InteractionResponseType
        data*: Option[InteractionApplicationCommandCallbackData]
    InteractionApplicationCommandCallbackData* = object
        tts*: Option[bool]
        content*: string
        embeds*: seq[Embed]
        allowed_mentions*: AllowedMentions
        flags*: int
    Invite* = object
        code*: string
        guild*: Option[PartialGuild]
        channel*: PartialChannel
        target_type*: Option[InviteTargetType]
        target_user*, inviter*: Option[User]
        target_application*: Option[Application]
        approximate_presence_count*, approximate_member_count*: Option[int]
        expires_at*: Option[string]
        stage_instance*: Option[tuple[
            members: seq[Member],
            topic: string,
            participant_count, speaker_count: int
        ]]
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
        target_type*: Option[InviteTargetType]
        target_application*: Option[Application]
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
        kind*: WebhookType
        guild_id*, avatar*: Option[string]
        name*, token*: Option[string]
        user*: Option[User]
    Integration* = object
        id*, name*, kind*: string
        role_id*, synced_at*: Option[string]
        enabled*: bool
        syncing*: Option[bool]
        enable_emoticons*, revoked*: Option[bool]
        expire_behavior*: Option[IntegrationExpireBehavior]
        expire_grace_period*: Option[int]
        user*: Option[User]
        account*: tuple[id, name: string]
        subscriber_count*: Option[int]
        application*: Option[Application]
    SelectMenuOption* = object
        label*: string
        value*: string
        description*: Option[string]
        emoji*: Option[Emoji]
        default*: Option[bool]

    MessageComponent* = object
        # custom_id is only needed for things other than action row
        # but the new case object stuff isn't implemented in nim
        # so it can't be shared
        # same goes with disabled
        custom_id*: Option[string]
        disabled*: Option[bool]
        case kind*: MessageComponentType
            of None: discard
            of ActionRow:
                components*: seq[MessageComponent]
            of Button: # Message Component
                style*: ButtonStyle
                label*: Option[string]
                emoji*: Option[Emoji]
                url*: Option[string]
            of SelectMenu:
                options*: seq[SelectMenuOption]
                placeholder*: Option[string]
                min_values*: Option[int]
                max_values*: Option[int]
    GuildPreview* = object
        id*, name*: string
        system_channel_flags*: set[SystemChannelFlags]
        icon*, banner*, splash*, emojis*: Option[string]
        preferred_locale*, discovery_splash*, description*: Option[string]
        approximate_member_count*, approximate_presence_count*: int
        features*: seq[string]
    VoiceRegion* = object
        id*, name*: string
        vip*, optimal*: bool
        deprecated*, custom*: bool
    AuditLogOptions* = object
        ## - `kind` ("role" or "member") or (0 or 1)
        delete_member_days*, members_removed*: Option[string]
        channel_id*, count*: Option[string]
        id*, role_name*: Option[string]
        when defined(discordv8):
            kind*: Option[int]
        else:
            kind*: Option[string] 
    AuditLogChangeValue* = object
        case kind*: AuditLogChangeType
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
        action_type*: AuditLogEntryType
    AuditLog* = object
        webhooks*: seq[Webhook]
        users*: seq[User]
        audit_log_entries*: seq[AuditLogEntry]
        integrations*: seq[Integration]
    GuildWidgetJson* = object
        id*, name*: string
        instant_invite*: string
        channels*: seq[tuple[ # dear god how many
            id, name: string,# versions of partial channels are there?
            position: int
        ]]
        members*: seq[tuple[
            id, username, discriminator: string,
            avatar: Option[string],
            status, avatar_url: string
        ]]
        presence_count: int
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
        on_invalid_session: proc (s: Shard, resumable: bool) {.async.}
        message_create*: proc (s: Shard, m: Message) {.async.}
        message_delete*: proc (s: Shard, m: Message, exists: bool) {.async.}
        message_update*: proc (s: Shard, m: Message,
                o: Option[Message], exists: bool) {.async.}
        message_reaction_add*: proc (s: Shard,
                m: Message, u: User, e: Emoji, exists: bool) {.async.}
        message_reaction_remove*: proc (s: Shard,
                m: Message, u: User,
                r: Reaction, exists: bool) {.async.}
        message_reaction_remove_all*: proc (s: Shard, m: Message,
                exists: bool) {.async.}
        message_reaction_remove_emoji*: proc (s: Shard,
                m: Message, e: Emoji, exists: bool) {.async.}
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
                token: string, endpoint: Option[string]) {.async.}
        webhooks_update*: proc (s: Shard, g: Guild, c: GuildChannel) {.async.}
        interaction_create*: proc (s: Shard, i: Interaction) {.async.}

proc kind*(c: CacheTable, channel_id: string): ChannelType =
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
