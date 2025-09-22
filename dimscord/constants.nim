## This file contains types/enums for every discord object or permission types
## NOTE: Every bitwise enum ends with "Flags", an exception to this,
## is GatewayIntent.
when defined(dimscordDebug):
    import strformat
#{.hint[XDeclaredButNotUsed]: off.} Unsure when am I gonna use this
# import strutils, regex

type
    PermissionFlags* = enum
        ## Note on this enum:
        ## - The values assigned `n` are equal to `1 shl n`, e.g.
        ## `cast[int]({permManageThreads})` == `1 shl 34`
        permCreateInstantInvite,
        permKickMembers =      1
        permBanMembers
        permAdministrator
        permManageChannels
        permManageGuild
        permAddReactions
        permViewAuditLogs
        permPrioritySpeaker
        permVoiceStream
        permViewChannel
        permSendMessages
        permSendTTSMessage
        permManageMessages
        permEmbedLinks
        permAttachFiles
        permReadMessageHistory
        permMentionEveryone
        permUseExternalEmojis
        permViewGuildInsights
        permVoiceConnect
        permVoiceSpeak
        permVoiceMuteMembers
        permVoiceDeafenMembers
        permVoiceMoveMembers
        permUseVAD
        permChangeNickname
        permManageNicknames
        permManageRoles
        permManageWebhooks
        permManageExpressions
        permUseSlashCommands
        permRequestToSpeak
        permManageEvents
        permManageThreads
        permUsePublicThreads
        permUsePrivateThreads
        permUseExternalStickers
        permSendMessagesInThreads
        permStartEmbeddedActivities
        permModerateMembers
        permViewCreatorMonetizationInsights
        permUseSoundboard
        permCreateExpressions
        permCreateEvents
        permUseExternalSounds
        permSendVoiceMessages
        permUsePolls = 49
        permUseExternalApps
    GatewayIntent* = enum
        giGuilds,
        giGuildMembers,
        giGuildModeration,
        giGuildEmojisAndStickers,
        giGuildIntegrations,
        giGuildWebhooks,
        giGuildInvites,
        giGuildVoiceStates,
        giGuildPresences,
        giGuildMessages,
        giGuildMessageReactions,
        giGuildMessageTyping,
        giDirectMessages,
        giDirectMessageReactions,
        giDirectMessageTyping,
        giMessageContent,
        giGuildScheduledEvents = 16,
        giAutoModerationConfiguration = 20,
        giAutoModerationExecution,
        giGuildMessagePolls = 24,
        giDirectMessagePolls
    AuditLogChangeType* = enum
        alcString,
        alcInt,
        alcBool,
        alcRoles,
        alcOverwrites,
        alcNil
    ActivityFlags* = enum
        afInstance,
        afJoin,
        afSpectate,
        afJoinRequest,
        afSync,
        afPlay,
        afPartyPrivacyFriends,
        afPartyPrivacyVoiceChannel,
        afEmbeded
    RoleFlags* = enum
        rfInPrompt = 1
    VoiceSpeakingFlags* = enum
        vsfMicrophone,
        vsfSoundshare,
        vsfPriority
    MessageFlags* = enum
        mfCrossposted = 0
        mfIsCrosspost,
        mfSuppressEmbeds,
        mfSourceMessageDeleted,
        mfUrgent,
        mfHasThread,
        mfEphemeral,
        mfLoading,
        mfFailedToMentionSomeRolesInThread
        mfSuppressNotifications = 12
        mfIsVoiceMessage,
        mfHasSnapshot,
        mfIsComponentsV2
    AttachmentFlags* = enum
        afNone = 0
        afIsRemix = 2
    UserFlags* = enum
        ## Note on this enum:
        ## - The values assigned `n` are equal to `1 shl n`, if
        ## you were to do for example: `cast[int]({apfGatewayPresence})`
        ufDiscordEmployee,
        ufPartneredServerOwner =  1
        ufHypesquadEvents,
        ufBugHunterLevel1,
        ufHouseBravery =          6,
        ufHouseBrilliance,
        ufHouseBalance,
        ufEarlySupporter,
        ufTeamUser,
        ufBugHunterLevel2 =      14,
        ufVerifiedBot =          16,
        ufEarlyVerifiedBotDeveloper,
        ufDiscordCertifiedModerator,
        ufBotHttpInteractions
        ufActiveDeveloper      = 22
    MemberFlags* = enum
        mfDidRejoin,
        mfCompletedOnboarding,
        mfBypassesVerification,
        mfStartedOnboarding,
        mfIsGuest,
        mfStartedHomeActions,
        mfCompletedHomeActions,
        mfAutomodQuarantinedUsername = 7,
        mfDmSettingsUpsellAcknowledged = 9,
        mfAutomodQuarantinedGuildTag
    SystemChannelFlags* = enum
        scfSuppressJoinNotifications,
        scfSuppressPremiumSubscriptions,
        scfSuppressGuildReminderNotifications
        scfSuppressJoinNotificationReplies
        scfSuppressRoleSubscriptionPurchaseNotifications
        scfSuppressRoleSubscriptionPurchaseNotificationReplies
    ApplicationFlags* = enum
        ## Note on this enum:
        ## - The values assigned `n` are equal to `1 shl n`, if
        ## you were to do for example: `cast[int]({apfGatewayPresence})`
        apfNone,
        apfApplicationAutoModerationRuleCreateBadge = 6,
        apfGatewayPresence                          = 12,
        apfGatewayPresenceLimited,
        apfGatewayGuildMembers,
        apfGatewayGuildMembersLimited,
        apfVerificationPendingGuildLimit,
        apfEmbeded,
        apfGatewayMessageContent,
        apfGatewayMessageContentLimited,
        apfApplicationCommandBadge = 23
    ChannelFlags* = enum
        cfNone,
        cfPinned = 1
        cfRequireTag = 4
        cfHideMediaDownloadOptions = 15
    SkuFlags* = enum
        sfNone,
        sfAvailable         = 2
        sfGuildSubscription = 7
        sfUserSubscription  = 8
const
    libName* =  "Dimscord"
    libVer* =   "1.8.0"
    libAgent* = "DiscordBot (https://github.com/krisppurg/dimscord, v"&libVer&")"

    cdnBase* =               "https://cdn.discordapp.com/"
    restBase* =              "https://discord.com/api/"
    cdnCustomEmojis* =       cdnBase & "emojis/"
    cdnAttachments* =        cdnBase & "attachments/"
    cdnAvatars* =            cdnBase & "avatars/"
    cdnIcons* =              cdnBase & "icons/"
    cdnSplashes* =           cdnBase & "splashes/"
    cdnChannelIcons* =       cdnBase & "channel-icons/"
    cdnTeamIcons* =          cdnBase & "team-icons/"
    cdnAppAssets* =          cdnBase & "app-assets/" # KrispPurg, really? Come on you can do better than that no one is going to use this.
    cdnDiscoverySplashes* =  cdnBase & "discovery-splashes/"
    cdnDefaultUserAvatars* = cdnBase & "embed/avatars/"
    cdnAvatarDecorations*  = cdnBase & "avatar-decorations/"
    cdnAppIcons* =           cdnBase & "app-icons/"
    cdnRoleIcons* =          cdnBase & "role-icons/"
    cdnStickers* =           cdnBase & "stickers/"
    cdnBanners* =            cdnBase & "banners/"

type
    MessageType* = enum
        mtDefault =                                 0
        mtRecipientAdd =                            1
        mtRecipientRemove =                         2
        mtCall =                                    3
        mtChannelNameChange =                       4
        mtChannelIconChange =                       5
        mtChannelPinnedMessage =                    6
        mtGuildMemberJoin =                         7
        mtUserGuildBoost =                          8
        mtUserGuildBoostTier1 =                     9
        mtUserGuildBoostTier2 =                     10
        mtUserGuildBoostTier3 =                     11
        mtChannelFollowAdd =                        12
        mtGuildDiscoveryDisqualified =              14
        mtGuildDiscoveryRequalified =               15
        mtGuildDiscoveryGracePeriodInitialWarning = 16
        mtGuildDiscoveryGracePeriodFinalWarning =   17
        mtThreadCreated =                           18
        mtReply =                                   19
        mtApplicationCommand =                      20
        mtThreadStarterMessage =                    21
        mtGuildInviteReminder =                     22
        mtContextMenuCommand =                      23
        mtAutoModerationAction =                    24
        mtRoleSubscriptionPurchase =                25
        mtInteractionPremiumUpsell =                26
        mtStageStart =                              27
        mtStageEnd =                                28
        mtStageSpeaker =                            29
        mtStageTopic =                              31
        mtGuildApplicationPremiumSubscription =     32
        mtGuildIncidentAlertModeEnabled =           36
        mtGuildIncidentAlertModeDisabled =          37
        mtGuildIncidentReportRaid =                 38
        mtGuildIncidentReportFalseAlarm =           39
        mtPurchaseNotification =                    44
        mtPollResult =                              46
        mtUnknown
    MessageActivityType* = enum
        matNone =        0
        matJoin =        1
        matSpectate =    2
        matListen =      3
        matJoinRequest = 5 # nice skip
    MessageReferenceType* = enum
        mrtDefault = 0
        mrtForward = 1
        mrtUnknown = 2
    ChannelType* = enum
        ctGuildText =          0
        ctDirect =             1
        ctGuildVoice =         2
        ctGroupDM =            3
        ctGuildParent =        4
        ctGuildNews =          5
        ctGuildStore =         6
        ctGuildNewsThread =    10
        ctGuildPublicThread =  11
        ctGuildPrivateThread = 12
        ctGuildStageVoice =    13
        ctGuildDirectory =     14
        ctGuildForum =         15
        ctGuildMedia =         16
    VideoQualityMode* = enum
        vqmAuto        = 0
        vqmFull        = 1
    ReactionType* = enum
        rtNormal        = 0
        rtBurst        = 1
    MessageNotificationLevel* = enum
        mnlAllMessages  = 0
        mnlOnlyMentions = 1
    ExplicitContentFilter* = enum
        ecfDisabled =            0
        ecfMembersWithoutRoles = 1
        ecfAllMembers =          2
    MFALevel* = enum
        mfaNone =     0
        mfaElevated = 1
    VerificationLevel* = enum
        vlNone =     0
        vlLow =      1
        vlMedium =   2
        vlHigh =     3
        vlVeryHigh = 4
    GuildNSFWLevel* = enum
        gnlDefault =       0
        gnlExplicit =      1
        gnlSafe =          2
        gnlAgeRestricted = 3
    PremiumTier* = enum
        ptNone =  0
        ptTier1 = 1
        ptTier2 = 2
        ptTier3 = 3
    ActivityType* = enum
        atPlaying =     0
        atStreaming =   1
        atListening =   2
        atWatching =    3
        atCustom =      4
        atCompeting =   5
        atCustomState = 6
    WebhookType* = enum
        whIncoming =    1
        whFollower =    2
        whApplication = 3
    EventWebhookStatus* = enum
        ewsNone               = 0
        ewsDisabled           = 1
        ewsEnabled            = 2
        ewsDisabledByDiscord  = 3
    IntegrationExpireBehavior* = enum
        iebRemoveRole = 0
        iebKick =       1
    AuditLogEntryType* = enum
        aleUnknown =                            0
        aleGuildUpdate =                        1
        aleChannelCreate =                      10
        aleChannelUpdate =                      11
        aleChannelDelete =                      12
        aleChannelOverwriteCreate =             13
        aleChannelOverwriteUpdate =             14
        aleChannelOverwriteDelete =             15
        aleMemberKick =                         20
        aleMemberPrune =                        21
        aleMemberBanAdd =                       22
        aleMemberBanRemove =                    23
        aleMemberUpdate =                       24
        aleMemberRoleUpdate =                   25
        aleMemberMove =                         26
        aleMemberDisconnect =                   27
        aleBotAdd =                             28
        aleRoleCreate =                         30
        aleRoleUpdate =                         31
        aleRoleDelete =                         32
        aleInviteCreate =                       40
        aleInviteUpdate =                       41
        aleInviteDelete =                       42
        aleWebhookCreate =                      50
        aleWebhookUpdate =                      51
        aleWebhookDelete =                      52
        aleEmojiCreate =                        60
        aleEmojiUpdate =                        61
        aleEmojiDelete =                        62
        aleMessageDelete =                      72
        aleMessageBulkDelete =                  73
        aleMessagePin =                         74
        aleMessageUnpin =                       75
        aleIntegrationCreate =                  80
        aleIntegrationUpdate =                  81
        aleIntegrationDelete =                  82
        aleStageInstanceCreate =                83
        aleStageInstanceUpdate =                84
        aleStageInstanceDelete =                85
        aleStickerCreate =                      90
        aleStickerUpdate =                      91
        aleStickerDelete =                      92
        aleGuildScheduledEventCreate =          100
        aleGuildScheduledEventUpdate =          101
        aleGuildScheduledEventDelete =          102
        aleThreadCreate =                       110
        aleThreadUpdate =                       111
        aleThreadDelete =                       112
        aleApplicationCommandPermissionUpdate = 121
        aleAutoModerationRuleCreate           = 140
        aleAutoModerationRuleUpdate           = 141
        aleAutoModerationRuleDelete           = 142
        aleAutoModerationBlockMessage         = 143
        aleAutoModerationFlagToChannel        = 144
        aleAutoModerationUserMuted            = 145
        aleCreatorMonetizationRequestCreated  = 150
        aleCreatorMonetizationTermsAccepted   = 151
        aleOnboardingPromptCreate             = 163
        aleOnboardingPromptUpdate             = 164
        aleOnboardingPromptDelete             = 165
        aleOnboardingCreate                   = 166
        aleOnboardingUpdate                   = 167
        aleHomeSettingsCreate                 = 190
        aleHomeSettingsUpdate                 = 191
    OverwriteType* = enum
        otRole   = 0
        otMember = 1
    TeamMembershipState* = enum
        tmsInvited =  1 # not to be confused with "The Mysterious Song" lol
        tmsAccepted = 2
    MessageStickerFormat* = enum
        msfPng    = 1
        msfAPng   = 2
        msfLottie = 3
        msfGif    = 4
    ApplicationCommandOptionType* = enum
        acotNothing         = 0 # Will never popup unless the user shoots themselves in the foot
        acotSubCommand      = 1
        acotSubCommandGroup = 2
        acotStr             = 3
        acotInt             = 4
        acotBool            = 5
        acotUser            = 6
        acotChannel         = 7
        acotRole            = 8
        acotMentionable     = 9 ## Includes Users and Roles
        acotNumber          = 10 ## A double
        acotAttachment      = 11
    ApplicationCommandType* = enum
        atNothing  = 0      ## Should never appear
        atSlash    = 1      ## CHAT_INPUT
        atUser              ## USER
        atMessage           ## MESSAGE
        atPrimaryEntryPoint ## PRIMARY_ENTRY_POINT
    ApplicationCommandPermissionType* = enum
        acptRole    = 1
        acptUser    = 2
        acptChannel = 3
    RoleConnectionMetadataType* = enum
        rcmIntegerLessThanOrEqual     = 1
        rcmIntegerGreaterThanOrEqual  = 2
        rcmIntegerEqual               = 3
        rcmIntegerNotEqual            = 4
        rcmDatetimeLessThanOrEqual    = 5
        rcmDatetimeGreaterThanOrEqual = 6
        rcmBooleanEqual               = 7
        rcmBooleanNotEqual            = 8
    InteractionType* = enum
        itPing               = 1
        itApplicationCommand = 2
        itMessageComponent   = 3
        itAutoComplete       = 4
        itModalSubmit        = 5
    InteractionDataType* = enum
        idtApplicationCommand
        idtMessageComponent
        idtAutoComplete
        idtModalSubmit
    InteractionResponseType* = enum
        irtInvalid                          = 0
        irtPong                             = 1
        irtChannelMessageWithSource         = 4
        irtDeferredChannelMessageWithSource = 5
        irtDeferredUpdateMessage            = 6
        irtUpdateMessage                    = 7
        irtAutoCompleteResult               = 8
        irtModal                            = 9
    ApplicationIntegrationType* = enum
        aitGuildInstall = 0
        aitUserInstall  = 1
    InteractionContextType* = enum
        ictGuild          = 0
        ictBotDm          = 1
        ictPrivateChannel = 2
    InviteType* = enum
        itGuild   = 0
        itGroupDm = 1
        itFriend  = 2
    InviteTargetType* = enum
        ittUnknown
        ittStream              = 1
        ittEmbeddedApplication = 2
    PrivacyLevel* = enum
        plGuildOnly = 2
        plUnknown
    UserPremiumType* = enum
        uptNone         = 0
        uptNitroClassic = 1
        uptNitro        = 2
        uptNitroBasic   = 3
    ButtonStyle* = enum
        bsPrimary   = 1
        bsSecondary = 2
        bsSuccess   = 3
        bsDanger    = 4
        bsLink      = 5
        bsPremium   = 6
    TextInputStyle* = enum
        tisShort     = 1
        tisParagraph = 2
    MessageComponentType* = enum
        mctNone              = 0 # This should never happen
        mctActionRow         = 1
        mctButton            = 2
        mctSelectMenu        = 3
        mctTextInput         = 4
        mctUserSelect        = 5
        mctRoleSelect        = 6
        mctMentionableSelect = 7
        mctChannelSelect     = 8
        mctSection           = 9
        mctTextDisplay       = 10
        mctThumbnail         = 11
        mctMediaGallery      = 12
        mctFile              = 13
        mctSeparator         = 14
        mctContainer         = 17
        mctLabel             = 18
        mctFileUpload        = 19
    StickerType* = enum
        stUnknown
        stStandard = 1
        stGuild    = 2
    PollLayoutType* = enum
        plNone
        plDefault = 1
    GuildScheduledEventPrivacyLevel* = enum
        splGuildOnly = 2
        splUnknown
    GuildScheduledEventStatus* = enum
        esUnknown
        esScheduled = 1
        esActive    = 2
        esCompleted = 3
        esCanceled  = 4
    EntityType* = enum
        etNone
        etStageInstance = 1
        etVoice         = 2
        etExternal      = 3
    RecurrenceRuleFrequency* = enum
        rrfYearly  = 0
        rrfMonthly = 1
        rrfWeekly  = 2
        rrfDaily   = 3
    RecurrenceRuleWeekday* = enum
        rrwMonday    = 0,
        rrwTuesday   = 1
        rrwWednesday = 2
        rrwThursday  = 3
        rrwFriday    = 4
        rrwSaturday  = 5
        rrwSunday    = 6
    RecurrenceRuleMonth* = enum
        rrmNone       = 0
        rrmJanuary    = 1
        rrmFebruary   = 2
        rrmMarch      = 3
        rrmApril      = 4
        rrmMay        = 5
        rrmJune       = 6
        rrmJuly       = 7
        rrmAugust     = 8
        rrmSeptember  = 9
        rrmOctober    = 10
        rrmNovember   = 11
        rrmDecember   = 12
    AnimationType* = enum
        atPremium = 0
        atBasic   = 1
        atUnknown
    ModerationActionType* = enum
        matUnknown
        matBlockMessage     = 1
        matSendAlertMessage = 2
        matTimeout          = 3
    ModerationTriggerType* = enum
        mttUnknown
        mttKeyword       = 1
        mttHarmfulLink   = 2
        mttSpam          = 3
        mttKeywordPreset = 4
        mttMentionSpam   = 5
    KeywordPresetType* = enum
        kptUnknown
        kptProfanity =     1
        kptSexualContent = 2
        kptSlurs         = 3
    ForumSortOrder* = enum
        fsoLatestActivity = 0
        fsoCreationDate   = 1
        fsoUnknown
    ForumLayout* = enum
        flNotSet      = 0
        flListView    = 1
        flGalleryView = 2
        flUnknown
    GuildOnboardingMode* = enum
        omDefault  = 0,
        omAdvanced = 1,
        omUnknown
    GuildOnboardingPromptType* = enum
        ptMultipleChoice = 0,
        ptDropdown       = 1,
        ptUnknown
    EntitlementType* = enum
        etUnknown = 0
        etPurchase = 1
        etPremiumSubscription,
        etDeveloperGift,
        etTestModePurchase,
        etFreePurchase,
        etUserGift,
        etPremiumPurchase,
        etApplicationSubscription
    SkuType* = enum
        stDurable           = 2
        stConsumable        = 3
        stSubscription      = 5
        stSubscriptionGroup = 6
        stNone
    SubscriptionStatus* = enum
        ssActive = 0
        ssEnding,
        ssInactive,
        ssUnknown
    EntryPointCommandHandlerType* = enum
        ephUnknown
        ephAppHandler            = 1
        ephDiscordLaunchActivity = 2
    DispatchEvent* = enum
        Unknown
        VoiceStateUpdate              = "VOICE_STATE_UPDATE"
        ChannelPinsUpdate             = "CHANNEL_PINS_UPDATE"
        GuildEmojisUpdate             = "GUILD_EMOJIS_UPDATE"
        GuildStickersUpdate           = "GUILD_STICKERS_UPDATE"
        PresenceUpdate                = "PRESENCE_UPDATE"
        MessageCreate                 = "MESSAGE_CREATE"
        MessageReactionAdd            = "MESSAGE_REACTION_ADD"
        MessageReactionRemove         = "MESSAGE_REACTION_REMOVE"
        MessageReactionRemoveEmoji    = "MESSAGE_REACTION_REMOVE_EMOJI"
        MessageReactionRemoveAll      = "MESSAGE_REACTION_REMOVE_ALL"
        MessageDelete                 = "MESSAGE_DELETE"
        MessageUpdate                 = "MESSAGE_UPDATE"
        MessageDeleteBulk             = "MESSAGE_DELETE_BULK"
        ChannelCreate                 = "CHANNEL_CREATE"
        ChannelUpdate                 = "CHANNEL_UPDATE"
        ChannelDelete                 = "CHANNEL_DELETE"
        GuildMembersChunk             = "GUILD_MEMBERS_CHUNK"
        GuildMemberAdd                = "GUILD_MEMBER_ADD"
        GuildMemberUpdate             = "GUILD_MEMBER_UPDATE"
        GuildMemberRemove             = "GUILD_MEMBER_REMOVE"
        GuildAuditLogEntryCreate      = "GUILD_AUDIT_LOG_ENTRY_CREATE"
        GuildBanAdd                   = "GUILD_BAN_ADD"
        GuildBanRemove                = "GUILD_BAN_REMOVE"
        GuildUpdate                   = "GUILD_UPDATE"
        GuildDelete                   = "GUILD_DELETE"
        GuildCreate                   = "GUILD_CREATE"
        GuildRoleCreate               = "GUILD_ROLE_CREATE"
        GuildRoleUpdate               = "GUILD_ROLE_UPDATE"
        GuildRoleDelete               = "GUILD_ROLE_DELETE"
        WebhooksUpdate                = "WEBHOOKS_UPDATE"
        TypingStart                   = "TYPING_START"
        InviteCreate                  = "INVITE_CREATE"
        InviteDelete                  = "INVITE_DELETE"
        GuildIntegrationsUpdate       = "GUILD_INTEGRATIONS_UPDATE"
        VoiceServerUpdate             = "VOICE_SERVER_UPDATE"
        VoiceChannelEffectSend        = "VOICE_CHANNEL_EFFECT_SEND"
        GuildSoundboardSoundCreate    = "GUILD_SOUNDBOARD_SOUND_CREATE"
        GuildSoundboardSoundUpdate    = "GUILD_SOUNDBOARD_SOUND_UPDATE"
        GuildSoundboardSoundDelete    = "GUILD_SOUNDBOARD_SOUND_DELETE"
        GuildSoundboardSoundsUpdate   = "GUILD_SOUNDBOARD_SOUNDS_UPDATE"
        SoundboardSounds              = "SOUNDBOARD_SOUNDS"
        UserUpdate                    = "USER_UPDATE"
        InteractionCreate             = "INTERACTION_CREATE"
        ThreadCreate                  = "THREAD_CREATE"
        ThreadUpdate                  = "THREAD_UPDATE"
        ThreadDelete                  = "THREAD_DELETE"
        ThreadListSync                = "THREAD_LIST_SYNC"
        ThreadMembersUpdate           = "THREAD_MEMBERS_UPDATE"
        ThreadMemberUpdate            = "THREAD_MEMBER_UPDATE"
        StageInstanceCreate           = "STAGE_INSTANCE_CREATE"
        StageInstanceUpdate           = "STAGE_INSTANCE_UPDATE"
        StageInstanceDelete           = "STAGE_INSTANCE_DELETE"
        GuildScheduledEventUserAdd    = "GUILD_SCHEDULED_EVENT_USER_ADD"
        GuildScheduledEventUserRemove = "GUILD_SCHEDULED_EVENT_USER_REMOVE"
        GuildScheduledEventCreate     = "GUILD_SCHEDULED_EVENT_CREATE"
        GuildScheduledEventUpdate     = "GUILD_SCHEDULED_EVENT_UPDATE"
        GuildScheduledEventDelete     = "GUILD_SCHEDULED_EVENT_DELETE"
        AutoModerationRuleCreate      = "AUTO_MODERATION_RULE_CREATE"
        AutoModerationRuleUpdate      = "AUTO_MODERATION_RULE_UPDATE"
        AutoModerationRuleDelete      = "AUTO_MODERATION_RULE_DELETE"
        AutoModerationActionExecution = "AUTO_MODERATION_ACTION_EXECUTION"
        MessagePollVoteAdd            = "MESSAGE_POLL_VOTE_ADD"
        MessagePollVoteRemove         = "MESSAGE_POLL_VOTE_REMOVE"
        IntegrationCreate             = "INTEGRATION_CREATE"
        IntegrationUpdate             = "INTEGRATION_UPDATE"
        IntegrationDelete             = "INTEGRATION_DELETE"
        EntitlementCreate             = "ENTITLEMENT_CREATE"
        EntitlementUpdate             = "ENTITLEMENT_UPDATE"
        EntitlementDelete             = "ENTITLEMENT_DELETE"

const
    deGuildMembersChunk*      = DispatchEvent.GuildMembersChunk
    deTypingStart*            = DispatchEvent.TypingStart
    deInviteCreate*           = DispatchEvent.InviteCreate
    deThreadListSync*         = DispatchEvent.ThreadListSync
    deThreadMembersUpdate*    = DispatchEvent.ThreadMembersUpdate
    deVoiceChannelEffectSend* = DispatchEvent.VoiceChannelEffectSend

const mctStringSelect* = mctSelectMenu ## alias equivalent

const
    ActionRow* {.deprecated: "use mctActionRow".}                 = mctActionRow
    Button* {.deprecated: "use mctButton".}                       = mctButton
    SelectMenu* {.deprecated: "use mctSelectMenu".}               = mctSelectMenu
    TextInput* {.deprecated: "use mctTextInput".}                 = mctTextInput
    UserSelect* {.deprecated: "use mctUserSelect".}               = mctUserSelect
    RoleSelect* {.deprecated: "use mctRoleSelect".}               = mctRoleSelect
    MentionableSelect* {.deprecated: "use mctMentionableSelect".} = mctMentionableSelect
    ChannelSelect* {.deprecated: "use mctChannelSelect".}         = mctChannelSelect

    Primary* {.deprecated: "use bsPrimary".}     = bsPrimary
    Secondary* {.deprecated: "use bsSecondary".} = bsSecondary
    Success* {.deprecated: "use bsSuccess".}     = bsSuccess
    Danger* {.deprecated: "use bsDanger".}       = bsDanger
    Link* {.deprecated: "use bsLink".}           = bsLink

    Short* {.deprecated: "use tisShort".}         = tisShort
    Paragraph* {.deprecated: "use tisParagraph".} = tisParagraph

const
    permAllText* = {permCreateInstantInvite,
        permManageChannels,
        permAddReactions,
        permViewChannel,
        permSendMessages,
        permSendTtsMessage,
        permManageMessages,
        permEmbedLinks,
        permAttachFiles,
        permReadMessageHistory,
        permMentionEveryone,
        permUseExternalEmojis,
        permUseExternalStickers,
        permManageRoles,
        permManageWebhooks,
        permUseSlashCommands,
        permManageThreads,
        permSendMessagesInThreads,
        permUsePublicThreads,
        permUsePrivateThreads,
        permSendVoiceMessages,
        permUsePolls}
    permAllVoice* = {permCreateInstantInvite,
        permMentionEveryone,
        permManageChannels,
        permUseExternalStickers,
        permUseExternalEmojis,
        permReadMessageHistory,
        permSendTtsMessage,
        permAddReactions,
        permManageWebhooks,
        permUseSlashCommands,
        permPrioritySpeaker,
        permVoiceStream,
        permViewChannel,
        permVoiceConnect,
        permVoiceSpeak,
        permVoiceMuteMembers,
        permVoiceDeafenMembers,
        permVoiceMoveMembers,
        permUseVad,
        permUseSoundboard,
        permUseExternalSounds,
        permStartEmbeddedActivities,
        permSendVoiceMessages,
        permUsePolls}
    permAllStage* = {permCreateInstantInvite,
        permUseExternalStickers,
        permUseSlashCommands,
        permManageWebhooks,
        permMentionEveryone,
        permUseExternalEmojis,
        permReadMessageHistory,
        permAddReactions,
        permManageChannels,
        permSendTtsMessage,
        permViewChannel,
        permVoiceConnect,
        permVoiceMuteMembers,
        permVoiceMoveMembers,
        permManageRoles,
        permRequestToSpeak,
        permSendVoiceMessages,
        permVoiceStream}
    permAllChannel* = permAllText + permAllVoice + permAllStage
    permAll* = {permKickMembers,
        permBanMembers,
        permAdministrator,
        permManageGuild,
        permViewAuditLogs,
        permViewGuildInsights,
        permChangeNickname,
        permManageNicknames,
        permCreateExpressions,
        permViewCreatorMonetizationInsights,
        permModerateMembers,
        permManageExpressions,
        permManageThreads,
        permManageEvents,
        permUseExternalApps,
        permCreateEvents} + permAllChannel
    permManageEmojis* = permManageExpressions # ;) no need to thank me

# Logging stuffs
proc log*(msg: string, info: tuple) =
    when defined(dimscordDebug):
        var finalmsg = "[Lib]: " & msg
        let tup = $info

        finalmsg = finalmsg & "\n    " & tup[1..tup.high - 1]

        echo finalmsg

proc log*(msg: string) =
    when defined(dimscordDebug):
        echo "[Lib]: " & msg

# CDN Endpoints

proc cdnGuilds(gid=""): string =
    result = cdnBase&"guilds"&(if gid!="":"/"&gid else:"")

proc cdnGuildUsers*(gid, uid:string): string =
    result = cdnGuilds(gid) & "/users/" & uid

proc cdnGuildMemberAvatar*(gid, uid, avatar: string; fmt = "png"): string =
    assert fmt in @["png", "jpg", "webp", "gif"]
    result = cdnGuildUsers(gid, uid)&"/avatars/"&avatar&"."&fmt

proc cdnGuildMemberBanner*(gid, uid, banner: string; fmt = "png"): string =
    assert fmt in @["png", "jpg", "webp", "gif"]
    result = cdnGuildUsers(gid, uid)&"/banners/"&banner&"."&fmt

proc cdnGuildScheduledEvents*(eid: string): string =
    result = cdnBase & "guild-events/" & eid

proc cdnGuildScheduledEventCover*(eid, cover: string; fmt = "png"): string =
    assert fmt in @["png", "jpg", "webp"]
    result = cdnGuildScheduledEvents(eid)&"/"&cover&"."&fmt

proc cdnRoleIcon*(rid, icon: string; fmt = "png"): string =
    assert fmt in @["png", "jpg", "webp"]
    result = cdnRoleIcons&rid&"/"&icon&"."&fmt

proc cdnSticker*(sid: string; fmt = "png"): string =
    assert fmt in @["png", "lottie", "webp"]

proc cdnTeamIcon*(tid, icon: string; fmt = "png"): string =
    assert fmt in @["png", "jpg", "webp"]
    result = cdnTeamIcons&tid&"/"&icon&"."&fmt

proc cdnAppIcon*(aid, icon: string; fmt = "png"): string =
    assert fmt in @["png", "jpg", "webp"]
    result = cdnAppIcons&aid&"/"&icon&"."&fmt

proc cdnAppAsset*(aid, asid: string; fmt = "png"): string =
    assert fmt in @["png", "jpg", "webp"]
    result = cdnAppAssets&aid&"/"&asid&"."&fmt

proc cdnUserAvatarDecoration*(uid, decoration: string): string =
    result = cdnAvatarDecorations&uid&"/"&decoration&".png"

proc cdnBanner*(bid, banner: string; fmt = "png"): string =
    ## `bid` could be user or guild id
    assert fmt in @["png", "jpg", "webp", "gif"]
    result = cdnBanners&bid&"/"&banner&"."&fmt

proc cdnGuildSplash*(gid, splash: string; fmt = "png"): string =
    assert fmt in @["png", "jpg", "webp"]
    result = cdnSplashes&gid&"/"&splash&"."&fmt

proc cdnGuildDiscoverySplash*(gid, splash: string; fmt = "png"): string =
    assert fmt in @["png", "jpg", "webp"]
    result = cdnDiscoverySplashes&gid&"/"&splash&"."&fmt

# Rest Endpoints

proc endpointUsers*(uid = "@me"): string =
    "users/" & uid

proc endpointUserChannels*(): string =
    endpointUsers("@me") & "/channels"

proc endpointVoiceRegions*(): string =
    "voice/regions"

proc endpointUserGuilds*(gid=""): string =
    endpointUsers("@me")&"/guilds"&(if gid != "": "/" & gid else: "")

proc endpointUserGuildMember*(gid: string): string =
    endpointUserGuilds(gid) & "/member"

proc endpointChannels*(cid = ""): string =
    "channels"&(if cid != "": "/" & cid else: "")

proc endpointStageInstances*(cid = ""): string =
    "stage-instances" & (if cid != "": "/" & cid else: "")

proc endpointGuilds*(gid = ""): string =
    "guilds" & (if gid != "": "/" & gid else: "")

proc endpointGuildStickers*(gid: string; sid=""): string =
    endpointGuilds(gid)&"/stickers"&(if sid != "": "/"&sid else: "")

proc endpointGuildPreview*(gid: string): string =
    endpointGuilds(gid) & "/preview"

proc endpointGuildRegions*(gid: string): string =
    endpointGuilds(gid) & "/regions"

proc endpointGuildMFA*(gid: string): string =
    endpointGuilds(gid) & "/mfa"

proc endpointGuildAuditLogs*(gid: string): string =
    endpointGuilds(gid) & "/audit-logs"

proc endpointGuildAutoModerationRules*(gid: string; rid = ""): string =
    endpointGuilds(gid)&"/auto-moderation/rules"&(if rid!="":"/"&rid else:"")

proc endpointGuildMembers*(gid: string; mid = ""): string =
    endpointGuilds(gid) & "/members" & (if mid != "":"/"&mid else: "")

proc endpointGuildScheduledEvents*(gid: string; eid = ""): string =
    endpointGuilds(gid)&"/scheduled-events"&(if eid!="":"/"&eid else:"")

proc endpointGuildScheduledEventUsers*(gid, eid: string): string =
    endpointGuildScheduledEvents(gid, eid) & "/users"

proc endpointGuildMembersSearch*(gid: string): string =
    endpointGuildMembers(gid) & "/search"

proc endpointGuildMembersNick*(gid: string; mid = "@me"): string =
    endpointGuildMembers(gid, mid) & "/nick"

proc endpointGuildMembersRole*(gid, mid, rid: string): string =
    endpointGuildMembers(gid, mid) & "/roles/" & rid

proc endpointGuildIntegrations*(gid: string; iid = ""): string =
    endpointGuilds(gid)&"/integrations"&(if iid!="":"/"&iid else:"")

proc endpointGuildVoiceStatesUser*(gid, uid = "@me"): string =
    endpointGuilds(gid) & "/voice-states/" & uid

proc endpointGuildWelcomeScreen*(gid: string): string =
    endpointGuilds(gid) & "/welcome-screen"

proc endpointGuildIntegrationsSync*(gid, iid: string): string =
    endpointGuildIntegrations(gid, iid) & "/sync"

proc endpointGuildWidget*(gid: string): string =
    endpointGuilds(gid) & "/widget"

proc endpointGuildEmojis*(gid: string; eid = ""): string =
    endpointGuilds(gid)&"/emojis"&(if eid != "": "/" & eid else: "")

proc endpointGuildRoles*(gid: string; rid = ""): string =
    endpointGuilds(gid) & "/roles" & (if rid!="": "/" & rid else: "")

proc endpointGuildPrune*(gid: string): string =
    endpointGuilds(gid) & "/prune"

proc endpointInvites*(code = ""): string =
    "invites" & (if code != "": "/" & code else: "")

proc endpointGuildInvites*(gid: string): string =
    endpointGuilds(gid) & "/" & endpointInvites()

proc endpointGuildVanity*(gid: string): string =
    endpointGuilds(gid) & "/vanity-url"

proc endpointGuildOnboarding*(gid: string): string =
    endpointGuilds(gid) & "/onboarding"

proc endpointGuildSounds*(gid: string; sid = ""): string =
    endpointGuilds(gid) & "/soundboard-sounds" & (if sid != "":"/"&sid else:"")

proc endpointGuildChannels*(gid: string; cid = ""): string =
    endpointGuilds(gid) & "/channels" & (if cid != "":"/"&cid else:"")

proc endpointChannelOverwrites*(cid, oid: string): string =
    endpointChannels(cid) & "/permissions/" & oid

proc endpointWebhooks*(wid: string): string =
    "webhooks/" & wid

proc endpointChannelWebhooks*(cid: string): string =
    endpointChannels(cid) & "/webhooks"

proc endpointGuildTemplates*(gid, tid = ""): string =
    endpointGuilds(gid) & "/templates" & (if tid!="": "/"&tid else:"")

proc endpointGuildWebhooks*(gid: string): string =
    endpointGuilds(gid) & "/webhooks"

proc endpointWebhookToken*(wid, tok: string): string =
    endpointWebhooks(wid) & "/" & tok

proc endpointWebhookMessage*(wid, tok, mid: string): string =
    endpointWebhookToken(wid, tok) & "/messages/" & mid

proc endpointWebhookTokenSlack*(wid, tok: string): string =
    endpointWebhookToken(wid, tok) & "/slack"

proc endpointWebhookTokenGithub*(wid, tok: string): string =
    endpointWebhookToken(wid, tok) & "/github"

proc endpointChannelMessages*(cid: string; mid = ""): string =
    result = endpointChannels(cid) & "/messages"
    if mid != "": result &= "/" & mid

proc endpointChannelMessagesThreads*(cid, mid: string): string =
    endpointChannelMessages(cid, mid) & "/threads"

proc endpointChannelThreads*(cid: string): string =
    endpointChannels(cid) & "/threads"

proc endpointGuildThreads*(gid: string): string =
    endpointGuilds(gid) & "/threads"

proc endpointGuildThreadsActive*(gid: string): string =
    endpointGuildThreads(gid) & "/active"

proc endpointChannelThreadsArchived*(cid, typ: string): string =
    endpointChannelThreads(cid) & "/archived/" & typ

proc endpointChannelUsersThreadsArchived*(cid, typ: string): string =
    endpointChannels(cid) & "/" & endpointUsers() & "/archived/" & typ

proc endpointChannelThreadsMembers*(cid: string; uid = ""): string =
    result = endpointChannels(cid) & "/thread-members"
    if uid != "":
        result = result & "/" & uid

proc endpointChannelPollsAnswer*(cid, mid, aid: string): string =
    endpointChannels(cid) & "/polls/" & mid & "/answers/" & aid

proc endpointChannelPollsExpire*(cid, mid: string): string =
    endpointChannels(cid) & "/polls/" & mid & "/expire"

proc endpointChannelMessagesCrosspost*(cid, mid: string): string =
    endpointChannelMessages(cid, mid) & "/crosspost"

proc endpointChannelInvites*(cid: string): string =
    endpointChannels(cid) & "/invites"

proc endpointChannelPermissions*(cid, oid: string): string =
    endpointChannels(cid) & "/permissions/" & oid

proc endpointGuildBanBulk*(gid: string; uid = ""): string =
    endpointGuilds(gid) & "/bulk-ban"

proc endpointGuildBans*(gid: string; uid = ""): string =
    endpointGuilds(gid) & "/bans" & (if uid != "": "/" & uid else: "")

proc endpointBulkDeleteMessages*(cid: string): string =
    endpointChannelMessages(cid) & "/bulk-delete"

proc endpointTriggerTyping*(cid: string): string =
    endpointChannels(cid) & "/typing"

proc endpointChannelPins*(cid: string; mid = ""): string =
    result = endpointChannels(cid) & "/messages/pins"
    if mid != "":
        result = result & "/" & mid

proc endpointGroupRecipient*(cid, rid: string): string =
    endpointChannels(cid) & "/recipients/" & rid

proc endpointReactions*(cid, mid: string; e, uid = ""): string =
    result = endpointChannels(cid) & "/messages/" & mid & "/reactions"
    if e != "":
        result = result & "/" & e
    if uid != "":
        result = result & "/" & uid

proc endpointSkuSubscriptions*(skid: string, sid=""): string =
    "skus/" & skid & "/subscriptions" & (if sid != "": "/"&sid else:"")

proc endpointApplications*(aid:string): string =
    "applications/"&aid

proc endpointApplicationEmojis*(aid:string, eid=""): string =
    endpointApplications(aid)&"/emojis"&(if eid!="":"/"&eid else:"")

proc endpointOAuth2Application*(): string =
    "oauth2/applications/@me"

proc endpointEntitlements*(aid: string; eid = ""): string =
    endpointApplications(aid)&"/entitlements"&(if eid!="":"/"&eid else:"")

proc endpointEntitlementConsume*(aid, eid: string): string =
    endpointEntitlements(aid, eid) & "/consume"

proc endpointListSkus*(aid: string): string =
    endpointApplications(aid) & "/skus"

proc endpointGlobalCommands*(aid: string; cid = ""): string =
    endpointApplications(aid)&"/commands"&(if cid!="":"/"&cid else:"")

proc endpointGuildCommands*(aid, gid: string; cid = ""): string =
    result = endpointApplications(aid)&"/guilds/"&gid&"/commands"
    if cid != "":
        result &= "/" & cid

proc endpointGuildCommandPermission*(aid, gid: string; cid = ""): string =
    endpointGuildCommands(aid, gid, cid) & "/permissions"

proc endpointInteractionsCallback*(iid, it: string): string =
    "interactions/" & iid & "/" & it & "/callback"

proc endpointApplicationRoleConnectionMetadata*(aid: string): string =
    "applications/"&aid&"/role-connections/metadata"

proc endpointUserApplications*(aid: string): string =
    endpointUsers()&"/applications"&(if aid != "": "/"&aid else: "")

proc endpointUserApplicationRoleConnection*(aid: string): string =
    endpointUserApplicationRoleConnection(aid) & "/role-connection"

proc endpointStickers*(sid: string): string =
    "stickers/"&sid

proc endpointStickerPacks*(): string =
    "sticker-packs"
