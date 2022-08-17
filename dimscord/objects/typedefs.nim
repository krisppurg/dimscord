import options as optns, json, asyncdispatch
import tables, ../constants
from ws import Websocket
import std/asyncnet
# when (NimMajor, NimMinor, NimPatch) >= (1, 6, 0):
#     {.warning[DuplicateModule]: off.}

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
        resumeGatewayUrl*: string
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
    VoiceEncryptionMode* = enum
        Normal = "xsalsa20_poly1305"
        Suffix = "xsalsa20_poly1305_suffix"
        Lite = "xsalsa20_poly1305_lite"
    VoiceClient* = ref object
        ## Representing VoiceClient object
        ## You can also change the values of the fields 
        ##
        ## For example: `v.sleep_offset = 0.96`
        ## But this may cause some effects.
        shard*: Shard
        voice_events*: VoiceEvents
        endpoint*, token*, secret_key*: string
        session_id*, guild_id*, channel_id*: string
        connection*: WebSocket
        udp*: AsyncSocket
        lastHBTransmit*, lastHBReceived*: float
        retry_info*: tuple[ms, attempts: int]
        hbAck*, hbSent*, stop*: bool
        gateway_ready*: bool
        heartbeating*, resuming*, reconnecting*: bool
        networkError*, ready*, migrate*: bool
        paused*, stopped*, reconnectable*: bool
        speaking*, offset_override*: bool
        adjust_range*: HSlice[float64, float64]
        adjust_offset*: float64
        start*, sleep_offset*: float64
        interval*, loops*, sent*: int
        sequence*, time*, ssrc*: uint32
        data*: string
        srcIP*, dstIP*: string
        srcPort*, dstPort*: int # src is our computer, dst is discord servers
        case encryptMode*: VoiceEncryptionMode
        of Lite: # Lites nonce is just an increasing number
            nonce*: uint32
        else: discard
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
        url*: string
        proxy_url*: Option[string]
        height*, width*: Option[int]
    EmbedVideo* = object
        url*, proxy_url*: Option[string]
        height*, width*: Option[int]
    EmbedImage* = object
        url*: string
        proxy_url*: Option[string]
        height*, width*: Option[int]
    EmbedProvider* = object
        name*, url*: Option[string]
    EmbedAuthor* = object
        name*: string
        url*: Option[string]
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
        position*: Option[int]
        author*: User
        member*: Option[Member]
        mention_users*: seq[User]
        mention_roles*: seq[string]
        mention_channels*: seq[MentionChannel]
        attachments*: seq[Attachment]
        embeds*: seq[Embed]
        reactions*: Table[string, Reaction]
        activity*: Option[tuple[kind: int, party_id: string]]
        thread*: Option[GuildChannel]
        application*: Option[Application]
        interaction*: Option[MessageInteraction]
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
        banner*: Option[string]
        bot*, system*: bool
        mfa_enabled*: Option[bool]
        accent_color*, premium_type*: Option[int]
        flags*: set[UserFlags]
        public_flags*: set[UserFlags]
        avatar*, locale*: Option[string]
    Member* = ref object
        ## - `permissions` Returned in the interaction object.
        ## Be aware that Member.user could be nil in some cases.
        user*: User
        nick*, premium_since*, avatar*: Option[string]
        communication_disabled_until*: Option[string]
        joined_at*: string
        roles*: seq[string]
        deaf*, mute*: bool
        pending*: Option[bool]
        permissions*: set[PermissionFlags]
        presence*: Presence
        voice_state*: Option[VoiceState]
    Attachment* = object
        ## `file` is used for sending/editing attachments.
        ## `file` is like `body` in DiscordFile, but for attachments.
        id*, filename*: string
        description*, content_type*: Option[string]
        proxy_url*, url*: string
        file*: string
        height*, width*: Option[int]
        ephemeral*: Option[bool]
        size*: int
    Reaction* = object
        count*: int
        emoji*: Emoji
        reacted*: bool
    Emoji* = object
        id*, name*: Option[string]
        require_colons*, animated*: Option[bool]
        managed*, available*: Option[bool]
        user*: Option[User]
        roles*: seq[string]
    PartialUser* = object
        id*, username*, discriminator*: string
        avatar*: Option[string]
        public_flags*: set[UserFlags]
        bot*: bool
    Sticker* = object
        id*: string
        name*, tags*: string
        guild_id*, description*: Option[string]
        pack_id*: Option[string]
        format_type*: MessageStickerFormat
        kind*: StickerType
        sort_value*: Option[int]
        available*: Option[bool]
        user*: Option[User]
    StickerPack* = object
        id*, name*, description*: string
        stickers*: seq[Sticker]
        sku_id*, banner_asset_id*: string
        cover_sticker_id*: Option[string]
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
        resume_gateway_url*, session_id*: string
        shard*: Option[seq[int]]
        application*: tuple[id: string, flags: set[ApplicationFlags]]
    DMChannel* = ref object
        id*, last_message_id*: string
        kind*: ChannelType
        recipients*: seq[User]
        messages*: Table[string, Message]
    GuildChannel* = ref object
        id*, name*, guild_id*: string
        nsfw*: bool
        parent_id*: Option[string]
        permission_overwrites*: Table[string, Overwrite]
        position*: Option[int]
        default_auto_archive_duration*: Option[int]
        rate_limit_per_user*: Option[int]
        permissions*: set[PermissionFlags]
        messages*: Table[string, Message]
        last_message_id*: string
        case kind*: ChannelType
        of ctGuildText, ctGuildNews:
            topic*: Option[string]
        of ctGuildVoice, ctGuildStageVoice:
            rtc_region*: Option[string]
            video_quality_mode*: Option[int]
            bitrate*, user_limit*: int
        of ctGuildPublicThread, ctGuildPrivateThread, ctGuildNewsThread:
            message_count*, member_count*: Option[int]
            total_message_sent*: Option[int]
            thread_metadata*: ThreadMetadata
            member*: Option[ThreadMember]
            flags*: set[ChannelFlags]
        else:
            discard
    StageInstance* = object
        id*, guild_id*: string
        channel_id*, topic*: string
        privacy_level*: PrivacyLevel
        discoverable_disabled*: bool
        guild_scheduled_event_id*: Option[string]
    ThreadMetadata* = object
        archived*, locked*: bool
        archiver_id*, create_timestamp*: Option[string]
        auto_archive_duration*: int
        archive_timestamp*: string
        invitable*: Option[bool]
    ThreadMember* = object
        ## - `id` The thread id the member is in.
        id*, user_id*: Option[string]
        join_timestamp*: string
        flags*: int
    ThreadListSync* = object
        id*, guild_id*: string
        channel_ids*: seq[string]
        threads*: seq[GuildChannel]
        members*: seq[ThreadMember]
    ThreadMembersUpdate* = object
        id*, guild_id*: string
        member_count*: int
        added_members*: seq[ThreadMember]
        removed_member_ids*: seq[string]
    GameAssets* = object
        small_text*, small_image*: string
        large_text*, large_image*: string
    Activity* = object
        name*: string
        kind*: ActivityType
        flags*: set[ActivityFlags]
        url*, application_id*, details*, state*: Option[string]
        created_at*: BiggestFloat
        timestamps*: Option[tuple[start, final: BiggestFloat]]
        emoji*: Option[Emoji]
        party*: Option[tuple[id: string, size: seq[int]]]
        assets*: Option[GameAssets]
        secrets*: Option[tuple[join, spectate, match: string]]
        buttons*: seq[string]
        instance*: bool
    Presence* = ref object
        user*: User
        guild_id*, status*: string
        activities*: seq[Activity]
        client_status*: tuple[web, desktop, mobile: string]
    WelcomeChannel* = object
        channel_id*, description*: string
        emoji_id*, emoji_name*: Option[string]
    Guild* = ref object
        id*, name*, owner_id*: string
        preferred_locale*: string
        rtc_region*, permissions_new*: Option[string]
        icon_hash*, description*, banner*: Option[string]
        public_updates_channel_id*, rules_channel_id*: Option[string]
        icon*, splash*, discovery_splash*: Option[string]
        afk_channel_id*, vanity_url_code*, application_id*: Option[string]
        widget_channel_id*, system_channel_id*, joined_at*: Option[string]
        system_channel_flags*: set[SystemChannelFlags]
        permissions*: set[PermissionFlags]
        premium_progress_bar_enabled*, nsfw*, owner*, widget_enabled*: bool
        large*, unavailable*: Option[bool]
        max_video_channel_uses*, afk_timeout*, member_count*: Option[int]
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
        threads*, channels*: Table[string, GuildChannel]
        presences*: Table[string, Presence]
        stage_instances*: Table[string, StageInstance]
        stickers*: Table[string, Sticker]
        guild_scheduled_events*: Table[string, GuildScheduledEvent]
    VoiceState* = ref object
        guild_id*, channel_id*: Option[string]
        user_id*, session_id*: string
        deaf*, mute*, suppress*: bool
        self_deaf*, self_mute*, self_stream*: bool
        request_to_speak_timestamp*: Option[string]
    GuildScheduledEvent* = ref object
        id*, guild_id*, scheduled_start_time*: string
        channel_id*, creator_id*, scheduled_end_time*: Option[string]
        description*, entity_id*, image*: Option[string]
        privacy_level*: GuildScheduledEventPrivacyLevel
        status*: GuildScheduledEventStatus
        entity_type*: EntityType
        entity_metadata*: EntityMetadata
        creator*: Option[User]
        user_count*: Option[int]
    GuildScheduledEventUser* = object
        guild_scheduled_event_id*: string
        user*: User
        member*: Option[Member]
    EntityMetadata* = object
        location*: Option[string]
    Role* = object
        id*, name*, permissions_new*: string
        icon*, unicode_emoji*: Option[string]
        color*, position*: int
        permissions*: set[PermissionFlags]
        hoist*, managed*, mentionable*: bool
        tags*: Option[RoleTag]
    RoleTag* = object
        bot_id*, integration_id*: Option[string]
        premium_subscriber*: Option[bool] #no idea what type is supposed to be
    AutoModerationRule* = object
        ## trigger_metadata info: https://discord.com/developers/docs/resources/auto-moderation#auto-moderation-rule-object-trigger-metadata
        ## event_type: https://discord.com/developers/docs/resources/auto-moderation#auto-moderation-rule-object-event-types
        ## presets: https://discord.com/developers/docs/resources/auto-moderation#auto-moderation-rule-object-keyword-preset-types
        id*, guild_id*, name*, creator_id*: string
        event_type*: int
        trigger_type*: ModerationTriggerType
        trigger_metadata*: tuple[keyword_filter: seq[string], presets: seq[int]]
        actions*: seq[ModerationAction]
        enabled*: bool
        exempt_roles*, exempt_channels*: seq[string]
    ModerationAction* = object
        kind*: ModerationActionType
        metadata*: tuple[channel_id: string, duration_seconds: int]
    ModerationActionExecution* = object
        guild_id*, rule_id*, user_id*, content*: string
        channel_id*, message_id*, alert_system_message_id*: Option[string]
        matched_keyword*, matched_content*: Option[string]
        action*: ModerationAction
        rule_trigger_type*: ModerationTriggerType
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
        kind*: int #.
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
        guild_id*, custom_install_url*: Option[string]
        owner*: User
        summary*, verify_key*: string
        team*: Option[Team]
        icon*, primary_sku_id*, slug*, tags*, cover_image*: Option[string]
        flags*: set[ApplicationFlags]
        install_params*: tuple[scopes: seq[string], permissions: string]
    ApplicationCommand* = object
        id*, application_id*, version*: string
        guild_id*: Option[string]
        kind*: ApplicationCommandType
        name*, description*: string
        name_localizations*, description_localizations*: Option[string]
        default_permission*: bool
        default_member_permissions*: Option[PermissionFlags]
        dm_permission*: Option[bool]
        options*: seq[ApplicationCommandOption]
    GuildApplicationCommandPermissions* = object
        id*, application_id*, guild_id*: string
        permissions*: seq[ApplicationCommandPermission]
    ApplicationCommandPermission* = object
        id*: string ## ID of role or user
        kind*: ApplicationCommandPermissionType
        permission*: bool ## true to allow, false to disallow
    ApplicationCommandOption* = object
        kind*: ApplicationCommandOptionType
        name*, description*: string
        name_localizations*, description_localizations*: string
        required*, autocomplete*: Option[bool]
        channel_types*: seq[ChannelType]
        min_value*, max_value*: (Option[BiggestInt], Option[float])
        min_length*, max_length*: Option[int]
        choices*: seq[ApplicationCommandOptionChoice]
        options*: seq[ApplicationCommandOption]
    ApplicationCommandOptionChoice* = object
        name*: string
        name_localizations*: Table[string, string]
        value*: (Option[string], Option[int])
    MessageInteraction* = object
        id*, name*: string
        kind*: InteractionType
        user*: User
        member*: Option[Member]
    Interaction* = object
        ## if `member` is present, then that means the interaction is in guild,
        ## and `user` is therefore not present.
        ##
        ## if `user` is present and `member` isn't, then that means that the
        ## interaction is in a DM.
        id*, application_id*: string
        guild_id*, channel_id*, locale*, guild_locale*: Option[string]
        kind*: InteractionType
        message*: Option[Message]
        member*: Option[Member]
        user*: Option[User]
        app_permissions*: set[PermissionFlags]
        token*: string
        data*: Option[ApplicationCommandInteractionData]
        version*: int
    ApplicationCommandInteractionData* = ref object
        ## `options` Table[option_name, obj]
        case interaction_type*: InteractionDataType
        of idtApplicationCommand:
            id*, name*: string
            guild_id*: Option[string]
            resolved*: ApplicationCommandResolution
            case kind*: ApplicationCommandType
            of atSlash:
                options*: Table[string, ApplicationCommandInteractionDataOption]
            of atUser, atMessage:
                target_id*: string
            of atNothing: discard
        of idtMessageComponent, idtModalSubmit:
            case component_type*: MessageComponentType:
            of SelectMenu:
                values*: seq[string]
            else: discard
            custom_id*: string
        # of idtModalSubmit:
            components*: seq[MessageComponent]
        else: discard
    ResolvedChannel* = object
        ## `thread_metadata` and `parent_id` are for Threads.
        id*, name*: string
        kind*: ChannelType
        permissions*: set[PermissionFlags]
        thread_metadata*: Option[ThreadMetadata]
        parent_id*: Option[string]
    ApplicationCommandResolution* = object
        users*: Table[string, User]
        attachments*: Table[string, Attachment]
        case kind*: ApplicationCommandType
        of atUser:
            members*: Table[string, Member]
            roles*: Table[string, Role]
        of atMessage:
            channels*: Table[string, ResolvedChannel]
            messages*: Table[string, Message]
        else: discard

    ApplicationCommandInteractionDataOption* = object
        name*: string
        case kind*: ApplicationCommandOptionType
        of acotNothing: discard
        of acotBool: bval*: bool
        of acotInt: ival*: BiggestInt
        of acotStr: str*: string
        of acotUser: user_id*: string
        of acotChannel: channel_id*: string
        of acotRole: role_id*: string
        of acotSubCommand, acotSubCommandGroup:
            options*: Table[string, ApplicationCommandInteractionDataOption]
        of acotNumber: fval*: BiggestFloat
        of acotMentionable: mention_id*: string
        of acotAttachment: aval*: string
        focused*: Option[bool] ## Will be true if this is the value the user is typing during auto complete
    InteractionResponse* = object
        case kind*: InteractionResponseType
        of irtPong, irtChannelMessageWithSource,
           irtDeferredChannelMessageWithSource, irtDeferredUpdateMessage,
           irtUpdateMessage:
            data*: Option[InteractionApplicationCommandCallbackData]
        of irtAutoCompleteResult:
            choices*: seq[ApplicationCommandOptionChoice]
        of irtInvalid: discard
        of irtModal:
            custom_id*, title*: string
            components*: seq[MessageComponent]
    InteractionApplicationCommandCallbackData* = object
        ## if you are setting message flags, there are limited amount.
        ## e.g. `mfEphemeral` and `mfSuppressEmbeds`.
        tts*: Option[bool]
        content*: string
        embeds*: seq[Embed]
        allowed_mentions*: AllowedMentions
        flags*: set[MessageFlags]
        attachments*: seq[Attachment]
        components*: seq[MessageComponent]
    InteractionCallbackDataMessage* = InteractionApplicationCommandCallbackData
    InteractionCallbackDataAutocomplete* = object
        choices*: seq[ApplicationCommandOptionChoice]
    InteractionCallbackDataModal* = object
        custom_id*, title*: string
        components*: seq[MessageComponent]
    Invite* = object
        code*: string
        guild*: Option[PartialGuild]
        channel*: Option[PartialChannel]
        target_type*: Option[InviteTargetType]
        target_user*, inviter*: Option[User]
        target_application*: Option[Application]
        approximate_presence_count*, approximate_member_count*: Option[int]
        expires_at*: Option[string]
        # stage_instance*: Option[tuple[
        #     members: seq[Member],
        #     topic: string,
        #     participant_count, speaker_count: int
        # ]] deprecated
        guild_scheduled_event*: Option[GuildScheduledEvent]
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
        inviter*, taget_user*: Option[User]
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
        id*: string
        kind*: WebhookType
        guild_id*, channel_id*, avatar*: Option[string]
        name*, token*, url*: Option[string]
        source_guild*: Option[PartialGuild]
        source_channel*: Option[PartialChannel]
        user*: Option[User]
    Integration* = object
        id*, name*, kind*: string
        role_id*, synced_at*: Option[string]
        enabled*, syncing*: Option[bool]
        enable_emoticons*, revoked*: Option[bool]
        expire_behavior*: Option[IntegrationExpireBehavior]
        expire_grace_period*: Option[int]
        user*: Option[User]
        account*: tuple[id, name: string]
        subscriber_count*: Option[int]
        application*: Option[tuple[
            id, name, description: string,
            icon: Option[string], bot: Option[User]
        ]]
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
        placeholder*: Option[string]
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
            min_values*, max_values*: Option[int]
        of TextInput:
            input_style*: Option[TextInputStyle]
            input_label*, value*: Option[string]
            required*: Option[bool]
            min_length*, max_length*: Option[int]
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
        channel_id*, count*, role_name*: Option[string]
        id*, message_id*, application_id*: Option[string]
        kind*: Option[string] #.
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
        id*: string
        user_id*, target_id*, reason*: Option[string]
        before*, after*: Table[string, AuditLogChangeValue]
        opts*: Option[AuditLogOptions]
        action_type*: AuditLogEntryType
    AuditLog* = object
        webhooks*: seq[Webhook]
        users*: seq[User]
        audit_log_entries*: seq[AuditLogEntry]
        integrations*: seq[Integration]
        threads*: seq[GuildChannel]
        guild_scheduled_events*: seq[GuildScheduledEvent]
        auto_moderation_rules*: seq[AutoModerationRule]
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
                token: string, endpoint: Option[string], initial: bool) {.async.}
        webhooks_update*: proc (s: Shard, g: Guild, c: GuildChannel) {.async.}
        interaction_create*: proc (s: Shard, i: Interaction) {.async.}
        application_command_create*,application_command_update*: proc (s: Shard,
                g: Option[Guild], a: ApplicationCommand) {.async.}
        application_command_delete*: proc (s: Shard,
                g: Option[Guild], a: ApplicationCommand) {.async.}
        thread_create*: proc (s: Shard, g: Guild, c: GuildChannel) {.async.}
        thread_update*: proc (s: Shard, g: Guild,
                c: GuildChannel, o: Option[GuildChannel]) {.async.}
        thread_delete*: proc (s: Shard, g: Guild,
                c: GuildChannel, exists: bool) {.async.}
        thread_list_sync*: proc (s: Shard, e: ThreadListSync) {.async.}
        thread_member_update*: proc (s: Shard, g: Guild, t: ThreadMember) {.async.}
        thread_members_update*: proc (s: Shard, e: ThreadMembersUpdate) {.async.}
        stage_instance_create*: proc (s: Shard, g: Guild, i: StageInstance) {.async.}
        stage_instance_update*: proc (s: Shard, g: Guild,
                i: StageInstance, o: Option[StageInstance]) {.async.}
        stage_instance_delete*: proc (s: Shard, g: Guild,
                i: StageInstance, exists: bool) {.async.}
        guild_stickers_update*: proc (s: Shard, g: Guild,
                stickers: seq[Sticker]) {.async.}
        guild_scheduled_event_create*, guild_scheduled_event_delete*: proc (
                s: Shard, g: Guild, e: GuildScheduledEvent) {.async.}
        guild_scheduled_event_update*: proc (s: Shard,
                    g: Guild, e: GuildScheduledEvent, o: Option[GuildScheduledEvent]
            ) {.async.}
        guild_scheduled_event_user_add*,guild_scheduled_event_user_remove*: proc(
                s: Shard, g: Guild, e: GuildScheduledEvent, u: User) {.async.}
        auto_moderation_rule_create*,auto_moderation_rule_update*: proc(s:Shard,
            g: Guild, r: AutoModerationRule) {.async.}
        auto_moderation_rule_delete*: proc(s: Shard,
            g: Guild, r: AutoModerationRule) {.async.}
        auto_moderation_action_execution*: proc(s: Shard,
            g: Guild, e: ModerationActionExecution) {.async.}

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
