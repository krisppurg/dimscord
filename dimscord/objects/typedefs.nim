import options as optns, json, asyncdispatch
import tables, ../constants
from ws import Websocket
import std/asyncnet
# when (NimMajor, NimMinor, NimPatch) >= (1, 6, 0):
#     {.warning[DuplicateModule]: off.}

type
    RestError* = object of CatchableError
    DiscordHttpError* = ref object of CatchableError
        ## - `code` the status code e.g. 400 for a bad request.
        ## - `message` the message field from the json e.g. "You are being rate-limited"
        ## **Note:** if you want exception msg, it's DiscordHttpError.msg
        code*: int
        message*: string
        errors*: JsonNode
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
        waits*: WaitTable
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
    MessageCall* = object
        participants*: seq[string]
        ended_timestamp*: Option[string]
    MessageReference* = object
        kind*: MessageReferenceType
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
        interaction_metadata*: Option[MessageInteractionMetadata]
        role_subscription_data*: Option[RoleSubscriptionData]
        message_reference*: Option[MessageReference]
        message_snapshots*: Table[string, Message]
        sticker_items*: Table[string, tuple[
            id, name: string,
            format_type: MessageStickerFormat
        ]]
        referenced_message*: Option[Message]
        resolved*: Option[ResolvedData]
        poll*: Option[Poll]
        call*: Option[MessageCall]
    PrimaryGuild* = object
        identity_guild_id*, tag*, badge*: Option[string]
        identity_enabled: Option[bool]
    Nameplate* = object
        sku_id*, asset*, label*, palette*: string
    User* = ref object
        ## The fields for bot and system are false by default
        ## simply because they are assumable.
        id*, username*, discriminator*: string
        global_name*, display_name*: Option[string]
        banner*, banner_color*: Option[string]
        bot*, system*: bool
        mfa_enabled*: Option[bool]
        accent_color*: Option[int]
        premium_type*: Option[UserPremiumType]
        flags*: set[UserFlags]
        public_flags*: set[UserFlags]
        avatar*, avatar_decoration*, locale*: Option[string]
        primary_guild*: Option[PrimaryGuild]
        avatar_decoration_data*: Option[tuple[sku_id, asset: string]]
        collectibles*: Option[tuple[nameplate: Nameplate]]
    Member* = ref object
        ## - `permissions` Returned in the interaction object.
        ## Be aware that Member.user could be nil in some cases.
        ## ALso if `joined_at` appears to be "" that's usually due to the fact that the member is a guest.
        user*: User
        guild_id*: string
        nick*, premium_since*, avatar*: Option[string]
        avatar_decoration_data*: Option[tuple[asset, sku_id: string]]
        communication_disabled_until*: Option[string]
        joined_at*: string
        roles*: seq[string]
        deaf*, mute*: bool
        pending*: Option[bool]
        flags*: set[GuildMemberFlags]
        permissions*: set[PermissionFlags]
        presence*: Presence
        voice_state*: Option[VoiceState]
    Attachment* = ref object
        ## `DiscordFile` is used for sending/editing attachments.
        ## `DiscordFile` is like `body` in DiscordFile, but for attachments.
        id*, filename*, title*: string
        description*, content_type*, waveform*: Option[string]
        proxy_url*, url*: string
        file*: string
        height*, width*: Option[int]
        flags: set[AttachmentFlags]
        ephemeral*: Option[bool]
        size*: int
    Reaction* = object
        kind*: Option[ReactionType] ## will return a some(...) for reaction events.
        count*: int
        count_details*: tuple[burst, normal: int]
        emoji*: Emoji
        burst_colors*: seq[string]
        reacted*, me_burst*, burst*: bool
    Emoji* = object
        id*, name*: Option[string]
        require_colons*, animated*: Option[bool]
        managed*, available*: Option[bool]
        user*: Option[User]
        roles*: seq[string]
    PollAnswer* = object
        answer_id*: int
        poll_media*: PollMedia
    Poll* = ref object
        question*: PollMedia
        answers*: seq[PollAnswer]
        expiry*: Option[string]
        allow_multiselect*: bool
        layout_type*: PollLayoutType
        results*: Option[PollResults]
    PollRequest* = object
        question*: PollMedia
        answers*: seq[PollAnswer]
        duration*: int
        allow_multiselect*: bool
        layout_type*: PollLayoutType
    PollResults* = ref object
        is_finalized*: bool
        answer_counts*: seq[PollAnswerCount]
    PollAnswerCount* = ref object
        id*, count*: int
        me_voted*: bool
    PollMedia* = object
        text*: Option[string]
        emoji*: Option[Emoji]
    PartialUser* = object
        id*, username*, discriminator*: string
        avatar*: Option[string]
        public_flags*, flags*: set[UserFlags]
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
    RoleSubscriptionData* = object
        tier_name*, role_susbcription_listing_id*: string
        total_months_subscribed*: int
        is_renewal*: bool
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
    DefaultForumReaction* = object
        emoji_id*, emoji_name*: Option[string]
    ForumTag* = object
        id*, name*: string
        moderated: bool
        emoji_id*, emoji_name*: Option[string]
    GuildChannel* = ref object
        id*, name*, guild_id*: string
        nsfw*: bool
        topic*, parent_id*, owner_id*: Option[string]
        last_pin_timestamp*: Option[string]
        permission_overwrites*: Table[string, Overwrite]
        position*: Option[int]
        default_auto_archive_duration*: Option[int]
        rate_limit_per_user*: Option[int]
        permissions*: set[PermissionFlags]
        messages*: Table[string, Message]
        icon_emoji*: Option[Emoji]
        last_message_id*: string
        case kind*: ChannelType
        of ctGuildVoice, ctGuildStageVoice:
            rtc_region*: Option[string]
            video_quality_mode*: Option[VideoQualityMode]
            bitrate*, user_limit*: int
        of ctGuildPublicThread, ctGuildPrivateThread, ctGuildNewsThread:
            message_count*, member_count*: Option[int]
            total_message_sent*: Option[int]
            thread_metadata*: ThreadMetadata
            member*: Option[ThreadMember]
            flags*: set[ChannelFlags]
            applied_tags*: Option[seq[string]]
        of ctGuildForum, ctGuildMedia:
            available_tags*: seq[ForumTag]
            default_reaction_emoji*: Option[DefaultForumReaction]
            default_thread_rate_limit_per_user*: Option[int]
            default_sort_order*: Option[ForumSortOrder]
            default_forum_layout*: Option[ForumLayout]
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
    ActivityAssets* = object
        ## Read more at:
        ## https://discord.com/developers/docs/topics/gateway-events#activity-object-activity-asset-image
        small_text*, small_image*: string
        large_text*, large_image*: string
    GameAssets* = ActivityAssets
    Activity* = object
        name*: string
        kind*: ActivityType
        flags*: set[ActivityFlags]
        application_id*: Option[string]
        url*, details*, state*: Option[string]
        created_at*: BiggestFloat
        timestamps*: Option[tuple[start, final: BiggestFloat]]
        emoji*: Option[Emoji]
        party*: Option[tuple[id: string, size: seq[int]]] ## todo
        assets*: Option[ActivityAssets]
        secrets*: Option[tuple[join, spectate, match: string]]
        buttons*: seq[tuple[label, url: string]]
        instance*: bool
    Presence* = ref object
        user*: User
        guild_id*, status*: string
        activities*: seq[Activity]
        client_status*: tuple[web, desktop, mobile: string]
    WelcomeChannel* = object
        channel_id*, description*: string
        emoji_id*, emoji_name*: Option[string]
    Entitlement* = object
        id*, sku_id*, application_id*: string
        user_id*, guild_id*: Option[string]
        starts_at*, ends_at*: Option[string]
        kind*: EntitlementType
        deleted*: bool
        consumed*: Option[bool]
    Sku* = object
        id*, name*, slug*, application_id*: string
        dependent_sku_id*, release_date*, manifest_labels*: Option[string]
        show_age_gate*, premium*: bool
        kind*: SkuType
        flags*: set[SkuFlags]
    Guild* = ref object
        id*, name*, owner_id*: string
        preferred_locale*: string
        rtc_region*, permissions_new*: Option[string]
        icon_hash*, description*, banner*: Option[string]
        public_updates_channel_id*, rules_channel_id*: Option[string]
        icon*, splash*, discovery_splash*: Option[string]
        afk_channel_id*, vanity_url_code*, application_id*: Option[string]
        widget_channel_id*, system_channel_id*, joined_at*: Option[string]
        safety_alerts_channel_id*: Option[string]
        system_channel_flags*: set[SystemChannelFlags]
        permissions*: set[PermissionFlags]
        premium_progress_bar_enabled*, nsfw*, owner*, widget_enabled*: bool
        large*, unavailable*: Option[bool]
        max_stage_video_channel_uses*: Option[int]
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
        member*: Option[Member]
        deaf*, mute*, suppress*: bool
        self_deaf*, self_mute*: bool
        self_stream*: Option[bool]
        request_to_speak_timestamp*: Option[string]
    VoiceChannelEffectSend* = object
        channel_id*, guild_id*, user_id*: string
        emoji*: Option[Emoji]
        animation_type*, animation_id*: Option[int]
        sound_id*: JsonNode
        sound_volume*: Option[BiggestFloat]
    RecurrenceRuleNWeekday* = object
        n*: int
        day*: RecurrenceRuleWeekday
    RecurrenceRule* = ref object
        ## Read for more information
        ## https://discord.com/developers/docs/resources/guild-scheduled-event#guild-scheduled-event-recurrence-rule-object
        ## 
        ## Ranges:
        ## - `by_n_weekday` - (1,5)
        ## - `by_year_day` - (1,364)
        start*: string
        `end`*: Option[string]
        frequency*: RecurrenceRuleFrequency
        interval*: int
        by_weekday*: Option[seq[RecurrenceRuleWeekday]]
        by_n_weekday*: Option[seq[RecurrenceRuleNWeekday]]
        by_month*: Option[seq[RecurrenceRuleMonth]]
        by_month_day*, by_year_day*: Option[seq[int]]
        count*: Option[int]
    GuildScheduledEvent* = ref object
        id*, guild_id*, name*, scheduled_start_time*: string
        channel_id*, creator_id*, scheduled_end_time*: Option[string]
        description*, entity_id*, image*: Option[string]
        privacy_level*: GuildScheduledEventPrivacyLevel
        status*: GuildScheduledEventStatus
        entity_type*: EntityType
        entity_metadata*: Option[EntityMetadata]
        creator*: Option[User]
        user_count*: Option[int]
        recurrence_rule*: RecurrenceRule
    GuildScheduledEventUser* = object # todo: member.guild_id appendings?
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
        flags*: set[RoleFlags]
    RoleTag* = object
        bot_id*, integration_id*: Option[string]
        subscription_listing_id*: Option[string]
        premium_subscriber*: Option[bool] #no idea what type is supposed to be
        available_for_purchase*, guild_connections*: Option[bool]
    TriggerMetadata* = object
        keyword_filter*, regex_patterns*, allow_list*: seq[string]
        presets*: seq[KeywordPresetType]
        mention_total_limit*: int
        mention_raid_protection_enabled*: bool
    AutoModerationRule* = object
        ## trigger_metadata info: https://discord.com/developers/docs/resources/auto-moderation#auto-moderation-rule-object-trigger-metadata
        ## event_type: https://discord.com/developers/docs/resources/auto-moderation#auto-moderation-rule-object-event-types
        ## presets: https://discord.com/developers/docs/resources/auto-moderation#auto-moderation-rule-object-keyword-preset-types
        id*, guild_id*, name*, creator_id*: string
        event_type*: int
        trigger_type*: ModerationTriggerType
        trigger_metadata*: TriggerMetadata
        actions*: seq[ModerationAction]
        enabled*: bool
        exempt_roles*, exempt_channels*: seq[string]
    ModerationAction* = object
        kind*: ModerationActionType
        metadata*: tuple[
            channel_id: string,
            duration_seconds: int,
            custom_message: Option[string]
        ]
    ModerationActionExecution* = object
        guild_id*, rule_id*, user_id*, content*: string
        channel_id*, message_id*, alert_system_message_id*: Option[string]
        matched_keyword*, matched_content*: Option[string]
        action*: ModerationAction
        rule_trigger_type*: ModerationTriggerType
    GuildOnboarding* = object
        guild_id*: string
        prompts*: seq[GuildOnboardingPrompt]
        default_channel_ids*: seq[string]
        enabled*: bool
        mode*: GuildOnboardingMode
    GuildOnboardingPrompt* = object
        id*, title*: string
        kind*: GuildOnboardingPromptType
        options*: seq[GuildOnboardingPromptOption]
        single_select*, required*, in_onboarding*: bool
    GuildOnboardingPromptOption* = object
        id*, title*: string
        description*, emoji_name*, emoji_id*: Option[string]
        channel_ids*, role_ids*: seq[string]
        emoji*: Option[Emoji]
        emoji_animated*: Option[bool]
    GuildTemplate* = object
        code*, name*, creator_id*: string
        description*: Option[string]
        usage_count*: int
        creator*: User
        source_guild_id*, updated_at*, created_at*: string
        serialized_source_guild*: PartialGuild
        is_dirty*: Option[bool]
    Subscription* = object
        id*, user_id*: string
        sku_ids*, entitlement_ids*: seq[string]
        renewal_sku_ids*: Option[seq[string]]
        current_period_start*, current_period_end*: string
        canceled_at*, country*: Option[string]
        status*: SubscriptionStatus
    ActivityStatus* = object
        ## This is used for status updates.
        name*: string
        kind*: ActivityType
        url*: Option[string]
        state*: Option[string]  ## Only required when a custom activity type is set.
    Overwrite* = object
        ## - `kind` will be either ("role" or "member") or ("0" or "1")
        id*: string
        kind*: int
        allow*, deny*: set[PermissionFlags]
    PermObj* = object
        allowed*, denied*: set[PermissionFlags]
    PartialGuild* = object
        id*, name*: string
        icon*, splash*: Option[string]
    PartialChannel* = object
        id*, name*: string
        kind*: ChannelType
    SomeChannel* = DMChannel|GuildChannel
    Channel* = object
        ## Used for creating guilds.
        name*, parent_id*: string
        id*, kind*: int
    TeamMember* = object
        membership_state*: TeamMembershipState
        team_id*, role*: string
        user*: User
    Team* = object
        icon*: Option[string]
        name*: string
        id*, owner_user_id*: string
        members*: seq[TeamMember]
    ApplicationInstallParams* = object
        scopes*: seq[string]
        permissions*: set[PermissionFlags]
    ApplicationIntegrationTypeConfig* = object
        oauth2_install_params*: Option[ApplicationInstallParams]
    Application* = object
        id*, description*, name*: string
        verify_key*: string
        rpc_origins*, tags*: seq[string]
        redirect_uris*: Option[seq[string]]
        approximate_guild_count*: Option[int]
        bot_public*, bot_require_code_grant*: bool
        terms_of_service_url*, privacy_policy_url*: Option[string]
        interactions_endpoint_url*: Option[string]
        guild_id*, custom_install_url*: Option[string]
        icon*, primary_sku_id*, slug*, cover_image*: Option[string]
        role_connections_verification_url*: Option[string]
        interactions_type_config*: Table[ApplicationIntegrationType,
            ApplicationIntegrationTypeConfig]
        owner*, bot*: PartialUser
        guild*: PartialGuild
        team*: Option[Team]
        flags*: set[ApplicationFlags]
        install_params*: ApplicationInstallParams
    ApplicationCommand* = object
        id*, application_id*, version*: string
        guild_id*: Option[string]
        kind*: ApplicationCommandType
        name*, description*: string
        name_localizations*: Option[Table[string, string]]
        description_localizations*: Option[Table[string, string]]
        default_member_permissions*: Option[set[PermissionFlags]]
        default_permission*, nsfw*, dm_permission*: Option[bool]
        options*: seq[ApplicationCommandOption]
        integration_types*: Option[seq[ApplicationIntegrationType]]
        contexts*: Option[seq[InteractionContextType]]
    GuildApplicationCommandPermissions* = object
        id*, application_id*, guild_id*: string
        permissions*: seq[ApplicationCommandPermission]
    ApplicationCommandPermission* = object
        id*: string ## ID of role or user
        kind*: ApplicationCommandPermissionType
        permission*: bool ## true to allow, false to disallow
    ApplicationRoleConnectionMetadata* = object
        kind*: RoleConnectionMetadataType
        key*, name*, description*: string
        name_localizations*: Option[Table[string, string]]
        description_localizations*: Option[Table[string, string]]
    ApplicationRoleConnection* = object
        platform_name*, platform_username*: Option[string]
        metadata*: Table[string, string]
    ApplicationCommandOption* = object
        kind*: ApplicationCommandOptionType
        name*, description*: string
        name_localizations*: Option[Table[string, string]]
        description_localizations*: Option[Table[string, string]]
        required*, autocomplete*: Option[bool]
        channel_types*: seq[ChannelType]
        min_value*, max_value*: (Option[BiggestInt], Option[float])
        min_length*, max_length*: Option[int]
        choices*: seq[ApplicationCommandOptionChoice]
        options*: seq[ApplicationCommandOption]
    ApplicationCommandOptionChoice* = object
        ## For some clarification on the `value` field and accessing values
        ## 
        ## ```nim
        ## let choice_value = choice.value # returns a tuple e.g. (some "...", none int)
        ## if choice_value[0].isSome:
        ##     echo choice_value[0].get, " is your stringified value"
        ## else: # the second value (1th element) must not be none given that 0th one is none
        ##     echo choice_value[1].get, " is your numerical value"
        ## ```
        name*: string
        name_localizations*: Option[Table[string, string]]
        value*: (Option[string], Option[int])
    MessageInteractionMetadata* = object
        id*, name*: string
        kind*: InteractionType
        user*: User
        authorizing_integration_owners*: Table[string, JsonNode]
        interacted_message_id*, original_response_message_id*: Option[string]
        target_user*: Option[User]
        target_message_id*: Option[string]
        triggering_interaction_metadata*: JsonNode ## Because Nim hates recursion types -_- 
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
        entitlements*: seq[Entitlement]
        authorizing_integration_owners*: Table[string, JsonNode]
        context*: Option[ApplicationIntegrationType]
        attachment_size_limit*: int
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
            of mctSelectMenu, mctUserSelect, mctRoleSelect, mctMentionableSelect, mctChannelSelect:
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
    ResolvedData* = object
        users*: Table[string, User]
        attachments*: Table[string, Attachment]
        members*: Table[string, Member]
        roles*: Table[string, Role]
        channels*: Table[string, ResolvedChannel]
        messages*: Table[string, Message]
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
            data*: Option[InteractionCallbackDataMessage]
        of irtAutoCompleteResult:
            choices*: seq[ApplicationCommandOptionChoice]
        of irtInvalid: discard
        of irtModal:
            custom_id*, title*: string
            components*: seq[MessageComponent]
    InteractionCallbackDataMessage* = ref object
        ## if you are setting message flags, there are limited amount.
        ## e.g. `mfEphemeral` and `mfSuppressEmbeds`.
        tts*: Option[bool]
        content*: string
        embeds*: seq[Embed]
        allowed_mentions*: AllowedMentions
        flags*: set[MessageFlags]
        attachments*: seq[Attachment]
        components*: seq[MessageComponent]
    # InteractionCallbackDataMessage* = InteractionApplicationCommandCallbackData
    InteractionCallbackDataAutocomplete* = object
        choices*: seq[ApplicationCommandOptionChoice]
    InteractionCallbackDataModal* = object
        custom_id*, title*: string
        components*: seq[MessageComponent]
    Invite* = object
        kind*: InviteType
        code*: string
        guild*: Option[PartialGuild]
        channel*: Option[PartialChannel]
        target_type*: Option[InviteTargetType]
        target_user*, inviter*: Option[User]
        target_application*: Option[Application]
        approximate_presence_count*, approximate_member_count*: Option[int]
        expires_at*: Option[string]
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
    TextDisplay* = object
        kind*: MessageComponentType
        id*: Option[int]
        content*: string
    UnfurledMediaItem* = object
        url*: string
        proxy_url*, content_type*: Option[string]
        attachment_id*: Option[string]
        height*, width*: Option[int]
    MediaGallery* = object
        media*: UnfurledMediaItem
        description*: Option[string]
        spoiler*: Option[bool]
    MessageComponent* = ref object
        ## `custom_id` is only needed for things other than action row
        ## but the new case object stuff isn't implemented in nim
        ## so it can't be shared
        ## same goes with disabled.
        ## `id` is not to be confused with custom_id.
        ## It's used to identify components in the response from an interaction
        id*: Option[int]
        custom_id*: Option[string]
        disabled*: Option[bool]
        placeholder*: Option[string]
        spoiler*: Option[bool]
        case kind*: MessageComponentType
        of mctNone: discard
        of mctActionRow, mctContainer:
            components*: seq[MessageComponent]
            accent_color*: Option[int] ## container only
        of mctButton: # Message Component
            style*: ButtonStyle
            label*: Option[string]
            emoji*: Option[Emoji]
            url*, sku_id*: Option[string]
        of mctSelectMenu, mctUserSelect, mctRoleSelect, mctMentionableSelect, mctChannelSelect:
            default_values*: seq[tuple[id, kind: string]] # !
            options*: seq[SelectMenuOption]
            channel_types*: seq[ChannelType] # !
            min_values*, max_values*: Option[int]
        of mctTextInput:
            input_style*: Option[TextInputStyle] # also known as "style"
            input_label*, value*: Option[string] # also known as "label"
            required*: Option[bool]
            min_length*, max_length*: Option[int]
        of mctThumbnail:
            media*: UnfurledMediaItem
            description*: Option[string]
        of mctSection:
            sect_components*: seq[TextDisplay]
            accessory*: MessageComponent
        of mctMediaGallery:
            items*: seq[MediaGallery]
        of mctFile:
            file*: UnfurledMediaItem
            name*: string
            size*: int
        of mctSeparator: # prolly is gonna be deprecated due to how niche it is lol
            divider*: Option[bool]
            spacing*: Option[int]
        of mctTextDisplay:
            content*: string
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
        ## - `kind` represents overwritten entity. -> ("0" or "1")
        ## 
        ## `"0"` is role and `"1"` is member
        auto_moderation_rule_name*: Option[string]
        auto_moderation_rule_trigger_type*: Option[string]
        delete_member_days*, members_removed*: Option[string]
        channel_id*, count*, role_name*: Option[string]
        id*, message_id*, application_id*: Option[string]
        kind*, integration_type*: Option[string] #.
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
        application_commands*: seq[ApplicationCommand]
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
        message_create*: proc (s: Shard, msg: Message) {.async.}
        message_delete*: proc (s: Shard, msg: Message, exists: bool) {.async.}
        message_update*: proc (s: Shard, msg: Message,
                old: Option[Message], exists: bool) {.async.}
        message_reaction_add*: proc (s: Shard,
                msg: Message, u: User, emj: Emoji, exists: bool) {.async.}
        message_reaction_remove*: proc (s: Shard,
                msg: Message, u: User,
                rtn: Reaction, exists: bool) {.async.}
        message_reaction_remove_all*: proc (s: Shard, msg: Message,
                exists: bool) {.async.}
        message_reaction_remove_emoji*: proc (s: Shard,
                msg: Message, emj: Emoji, exists: bool) {.async.}
        message_delete_bulk*: proc (s: Shard, m: seq[tuple[
                msg: Message, exists: bool]]) {.async.}
        channel_create*: proc (s: Shard, g: Option[Guild],
                c: Option[GuildChannel], dm: Option[DMChannel]) {.async.}
        channel_update*: proc (s: Shard, g: Guild,
                c: GuildChannel, old: Option[GuildChannel]) {.async.}
        channel_delete*: proc (s: Shard, g: Option[Guild],
                c: Option[GuildChannel], dm: Option[DMChannel]) {.async.}
        channel_pins_update*: proc (s: Shard, chan_id: string,
                g: Option[Guild], last_pin: Option[string]) {.async.}
        presence_update*: proc (s: Shard, p: Presence,
                old: Option[Presence]) {.async.}
        typing_start*: proc (s: Shard, evt: TypingStart) {.async.}
        guild_emojis_update*: proc (s: Shard, g: Guild;
                emojis: seq[Emoji]) {.async.}
        guild_ban_add*, guild_ban_remove*: proc (s: Shard, g: Guild,
                u: User) {.async.}
        guild_audit_log_entry_create*: proc (s: Shard; g: Guild;
                entry: AuditLogEntry) {.async.}
        guild_integrations_update*: proc (s: Shard, g: Guild) {.async.}
        integration_create*: proc (s: Shard, u: User, g: Guild) {.async.}
        integration_update*: proc (s: Shard, u: User, g: Guild) {.async.}
        integration_delete*: proc (s: Shard, integ_id: string, g: Guild,
                app_id: Option[string]) {.async.}
        guild_member_add*, guild_member_remove*: proc (s: Shard, g: Guild,
                m: Member) {.async.}
        guild_member_update*: proc (s: Shard, g: Guild,
                m: Member, old: Option[Member]) {.async.}
        guild_update*: proc (s: Shard,g: Guild,old: Option[Guild]) {.async.}
        guild_create*, guild_delete*: proc (s: Shard, g: Guild) {.async.}
        guild_members_chunk*: proc (s: Shard, g: Guild,
                m: GuildMembersChunk) {.async.}
        guild_role_create*, guild_role_delete*: proc (s: Shard, g: Guild,
                r: Role) {.async.}
        guild_role_update*: proc (s: Shard, g: Guild,
                r: Role, old: Option[Role]) {.async.}
        invite_create*: proc (s: Shard, i: InviteCreate) {.async.}
        invite_delete*: proc (s: Shard, g: Option[Guild],
                chan_id, code: string) {.async.}
        user_update*: proc (s: Shard, u: User) {.async.}
        voice_state_update*: proc (s: Shard, v: VoiceState,
                old: Option[VoiceState]) {.async.}
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
                c: GuildChannel, old: Option[GuildChannel]) {.async.}
        thread_delete*: proc (s: Shard, g: Guild,
                c: GuildChannel, exists: bool) {.async.}
        thread_list_sync*: proc (s: Shard, e: ThreadListSync) {.async.}
        thread_member_update*: proc (s: Shard,g: Guild,t: ThreadMember) {.async.}
        thread_members_update*: proc (s: Shard, e: ThreadMembersUpdate) {.async.}
        stage_instance_create*: proc (s: Shard, g: Guild;
                i: StageInstance) {.async.}
        stage_instance_update*: proc (s: Shard, g: Guild,
                si: StageInstance, old: Option[StageInstance]) {.async.}
        stage_instance_delete*: proc (s: Shard, g: Guild,
                si: StageInstance, exists: bool) {.async.}
        guild_stickers_update*: proc (s: Shard, g: Guild,
                stickers: seq[Sticker]) {.async.}
        guild_scheduled_event_create*, guild_scheduled_event_delete*: proc (
                s: Shard, g: Guild, evt: GuildScheduledEvent) {.async.}
        guild_scheduled_event_update*: proc (s: Shard,
                    g: Guild, evt: GuildScheduledEvent;
                    old: Option[GuildScheduledEvent]
            ) {.async.}
        guild_scheduled_event_user_add*,guild_scheduled_event_user_remove*: proc(
            s: Shard, g: Guild, evt: GuildScheduledEvent, u: User) {.async.}
        auto_moderation_rule_create*,auto_moderation_rule_update*: proc(s:Shard;
            g: Guild, r: AutoModerationRule) {.async.}
        auto_moderation_rule_delete*: proc(s: Shard;
            g: Guild, r: AutoModerationRule) {.async.}
        auto_moderation_action_execution*: proc(s: Shard,
            g: Guild, e: ModerationActionExecution) {.async.}
        message_poll_vote_add*, message_poll_vote_remove*: proc(s: Shard, m: Message;
                u: User, ans_id: int){.async.}
        entitlement_create*: proc(s: Shard, e: Entitlement){.async.}
        entitlement_update*: proc(s: Shard, e: Entitlement){.async.}
        entitlement_delete*: proc(s: Shard, e: Entitlement) {.async.}

    WaitHandler = proc (data: pointer): bool {.closure.}
      ## This proc will filter an object to see what it should do.
      ## It should be a closure that can complete a future it has already returned.
      ## If the filter passes then it should return true to let the WaitTable know it can remove it
      ##
      ## The data pointer will be a tuple containing parameters relating to that event.
      ## Parameters are the same as the normal handlers except without the shard parameter
    WaitTable = array[DispatchEvent, seq[WaitHandler]]
      ## Mapping of event to handlers that are awaiting for something to happen via that event.
      ## e.g. MessageCreate: @[waitingForDeleting(), waitingForResponse()]

proc kind*(c: CacheTable, channel_id: string): ChannelType =
    ## Checks for a channel kind. (Shortcut)
    if channel_id in c.dmChannels:
        result = c.dmChannels[channel_id].kind
    elif channel_id in c.guildChannels:
        result = c.guildChannels[channel_id].kind
    else:
        raise newException(CacheError, "Channel doesn't exist in cache.")

proc guild*(c: CacheTable, obj: ref object | object): Guild =
    ## Get guild from respective object via cache.
    ## This is a nice shortcut.
    assert compiles(obj.guild_id), "guild_id field does not exist in " & $typeof(obj)
    when obj.guild_id is Option[string]:
        assert obj.guild_id.isSome, typeof(obj) & ".guild_id is none!"
        c.guilds[obj.guild_id.get]
    else:
        c.guilds[obj.guild_id]

proc gchannel*(c: CacheTable, obj: ref object | object | string): GuildChannel =
    ## Get channel from respective object via cache.
    ## This is a nice shortcut.
    when not (obj is string):
        assert(
            compiles(obj.channel_id),
            "channel_id field does not exist in " & $typeof(obj)
        )
    
        when obj.channel_id is Option[string]: 
            assert obj.channel_id.isSome, typeof(obj) & ".channel_id is none!"
            c.guildchannels[obj.channel_id.get]
        else:
            c.guildchannels[obj.channel_id]
    else:
        c.guildchannels[obj]

proc dm*(c: CacheTable, obj: ref object | object | string): DMChannel =
    ## Get dm channel from respective object via cache.
    ## This is a nice shortcut.
    when not (obj is string):
        assert(
            compiles(obj.channel_id),
            "channel_id field does not exist in " & $typeof(obj)
        )
    
        when obj.channel_id is Option[string]: 
            assert obj.channel_id.isSome, typeof(obj) & ".channel_id is none!"
            c.dmchannels[obj.channel_id.get]
        else:
            c.dmchannels[obj.channel_id]
    else:
        c.dmchannels[obj]

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

proc `$`*(m: Message): string =
    $m[]

proc `$`*(a: Attachment): string =
    $a[]

proc `$`*(a: ref object): string =
    $a[]

proc getCurrentDiscordHttpError*(): DiscordHttpError =
    ## Use this proc instead of getCurrentException() for advanced details.
    let err = getCurrentException()
    if err.isNil:
        result = nil
    else:
        result = cast[DiscordHttpError](err)
