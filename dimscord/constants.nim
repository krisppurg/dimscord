## This file contains types/enums for every discord object or permission types
## NOTE: Every bitwise enum ends with "Flags", an exception to this,
## is GatewayIntent.
when defined(dimscordDebug):
    import strformat
#{.hint[XDeclaredButNotUsed]: off.} Unsure when am I gonna use this
import strutils, regex

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
        giAutoModerationExecution
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
        mfCrossposted,
        mfIsCrosspost,
        mfSuppressEmbeds,
        mfSourceMessageDeleted,
        mfUrgent,
        mfHasThread,
        mfEphemeral,
        mfLoading,
        mfFailedToMentionSomeRolesInThread
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
    GuildMemberFlags* = enum
        gmfDidRejoin
        gmfCompletedOnboarding
        gmfBypassesVerification
        gmfStartedOnboarding
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

const
    libName* =  "Dimscord"
    libVer* =   "1.4.0"
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
    MessageActivityType* = enum
        matJoin =        1
        matSpectate =    2
        matListen =      3
        matJoinRequest = 5 # nice skip
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
    MessageNotificationLevel* = enum
        mnlAllMessages =  0
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
        atPlaying =   0
        atStreaming = 1
        atListening = 2
        atWatching =  3
        atCustom =    4
        atCompeting = 5
    WebhookType* = enum
        whIncoming =    1
        whFollower =    2
        whApplication = 3
    IntegrationExpireBehavior* = enum
        iebRemoveRole = 0
        iebKick =       1
    AuditLogEntryType* = enum
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
        aleAutoModerationRuleCreate =           140
        aleAutoModerationRuleUpdate =           141
        aleAutoModerationRuleDelete =           142
        aleAutoModerationBlockMessage =         143
    TeamMembershipState* = enum
        tmsInvited =  1 # not to be confused with "The Mysterious Song" lol
        tmsAccepted = 2
    MessageStickerFormat* = enum
        msfPng    = 1
        msfAPng   = 2
        msfLottie = 3
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
        atNothing  = 0 ## Should never appear
        atSlash    = 1 ## CHAT_INPUT
        atUser         ## USER
        atMessage      ## MESSAGE
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
    InviteTargetType* = enum
        ittStream              = 1
        ittEmbeddedApplication = 2
    PrivacyLevel* = enum
        plGuildOnly = 2
    UserPremiumType* = enum
        uptNone         = 0
        uptNitroClassic = 1
        uptNitro        = 2
        uptNitroBasic   = 3
    ButtonStyle* = enum
        Primary   = 1
        Secondary = 2
        Success   = 3
        Danger    = 4
        Link      = 5
    TextInputStyle* = enum
        Short     = 1
        Paragraph = 2
    MessageComponentType* = enum
        None              = 0 # This should never happen
        ActionRow         = 1
        Button            = 2
        SelectMenu        = 3
        TextInput         = 4
        UserSelect        = 5
        RoleSelect        = 6
        MentionableSelect = 7
        ChannelSelect     = 8
    StickerType* = enum
        stStandard = 1
        stGuild    = 2
    GuildScheduledEventPrivacyLevel* = enum
        splGuildOnly = 2
    GuildScheduledEventStatus* = enum
        esScheduled = 1
        esActive    = 2
        esCompleted = 3
        esCanceled  = 4
    EntityType* = enum
        etStageInstance = 1
        etVoice         = 2
        etExternal      = 3
    ModerationActionType* = enum
        matBlockMessage     = 1
        matSendAlertMessage = 2
        matTimeout          = 3
    ModerationTriggerType* = enum
        mttKeyword       = 1
        mttHarmfulLink   = 2
        mttSpam          = 3
        mttKeywordPreset = 4
        mttMentionSpam   = 5
    KeywordPresetType* = enum
        kptProfanity =     1
        kptSexualContent = 2
        kptSlurs         = 3
    ForumSortOrder* = enum
        fsoLatestActivity = 0
        fsoCreationDate   = 1
    ForumLayout* = enum
        flNotSet      = 0
        flListView    = 1
        flGalleryView = 2
    GuildOnboardingMode* = enum
        omDefault  = 0,
        omAdvanced = 1
    GuildOnboardingPromptType* = enum
        ptMultipleChoice = 0,
        ptDropdown       = 1
    DispatchEvent* = enum
        deUnknown
        deVoiceStateUpdate              = "VOICE_STATE_UPDATE"
        deChannelPinsUpdate             = "CHANNEL_PINS_UPDATE"
        deGuildEmojisUpdate             = "GUILD_EMOJIS_UPDATE"
        deGuildStickersUpdate           = "GUILD_STICKERS_UPDATE"
        dePresenceUpdate                = "PRESENCE_UPDATE"
        deMessageCreate                 = "MESSAGE_CREATE"
        deMessageReactionAdd            = "MESSAGE_REACTION_ADD"
        deMessageReactionRemove         = "MESSAGE_REACTION_REMOVE"
        deMessageReactionRemoveEmoji    = "MESSAGE_REACTION_REMOVE_EMOJI"
        deMessageReactionRemoveAll      = "MESSAGE_REACTION_REMOVE_ALL"
        deMessageDelete                 = "MESSAGE_DELETE"
        deMessageUpdate                 = "MESSAGE_UPDATE"
        deMessageDeleteBulk             = "MESSAGE_DELETE_BULK"
        deChannelCreate                 = "CHANNEL_CREATE"
        deChannelUpdate                 = "CHANNEL_UPDATE"
        deChannelDelete                 = "CHANNEL_DELETE"
        deGuildMembersChunk             = "GUILD_MEMBERS_CHUNK"
        deGuildMemberAdd                = "GUILD_MEMBER_ADD"
        deGuildMemberUpdate             = "GUILD_MEMBER_UPDATE"
        deGuildMemberRemove             = "GUILD_MEMBER_REMOVE"
        deGuildAuditLogEntryCreate      = "GUILD_AUDIT_LOG_ENTRY_CREATE"
        deGuildBanAdd                   = "GUILD_BAN_ADD"
        deGuildBanRemove                = "GUILD_BAN_REMOVE"
        deGuildUpdate                   = "GUILD_UPDATE"
        deGuildDelete                   = "GUILD_DELETE"
        deGuildCreate                   = "GUILD_CREATE"
        deGuildRoleCreate               = "GUILD_ROLE_CREATE"
        deGuildRoleUpdate               = "GUILD_ROLE_UPDATE"
        deGuildRoleDelete               = "GUILD_ROLE_DELETE"
        deWebhooksUpdate                = "WEBHOOKS_UPDATE"
        deTypingStart                   = "TYPING_START"
        deInviteCreate                  = "INVITE_CREATE"
        deInviteDelete                  = "INVITE_DELETE"
        deGuildIntegrationsUpdate       = "GUILD_INTEGRATIONS_UPDATE"
        deVoiceServerUpdate             = "VOICE_SERVER_UPDATE"
        deUserUpdate                    = "USER_UPDATE"
        deInteractionCreate             = "INTERACTION_CREATE"
        deThreadCreate                  = "THREAD_CREATE"
        deThreadUpdate                  = "THREAD_UPDATE"
        deThreadDelete                  = "THREAD_DELETE"
        deThreadListSync                = "THREAD_LIST_SYNC"
        deThreadMembersUpdate           = "THREAD_MEMBERS_UPDATE"
        deThreadMemberUpdate            = "THREAD_MEMBER_UPDATE"
        deStageInstanceCreate           = "STAGE_INSTANCE_CREATE"
        deStageInstanceUpdate           = "STAGE_INSTANCE_UPDATE"
        deStageInstanceDelete           = "STAGE_INSTANCE_DELETE"
        deGuildScheduledEventUserAdd    = "GUILD_SCHEDULED_EVENT_USER_ADD"
        deGuildScheduledEventUserRemove = "GUILD_SCHEDULED_EVENT_USER_REMOVE"
        deGuildScheduledEventCreate     = "GUILD_SCHEDULED_EVENT_CREATE"
        deGuildScheduledEventUpdate     = "GUILD_SCHEDULED_EVENT_UPDATE"
        deGuildScheduledEventDelete     = "GUILD_SCHEDULED_EVENT_DELETE"
        deAutoModerationRuleCreate      = "AUTO_MODERATION_RULE_CREATE"
        deAutoModerationRuleUpdate      = "AUTO_MODERATION_RULE_UPDATE"
        deAutoModerationRuleDelete      = "AUTO_MODERATION_RULE_DELETE"
        deAutoModerationActionExecution = "AUTO_MODERATION_ACTION_EXECUTION"

const
    permAllText* = {permCreateInstantInvite,
        permManageChannels,
        permAddReactions,
        permViewChannel,
        permSendMessages,
        permSendTTSMessage,
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
        permSendVoiceMessages}
    permAllVoice* = {permCreateInstantInvite,
        permMentionEveryone,
        permManageChannels,
        permUseExternalStickers,
        permUseExternalEmojis,
        permReadMessageHistory,
        permSendTTSMessage,
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
        permUseVAD,
        permUseSoundboard,
        permUseExternalSounds,
        permStartEmbeddedActivities,
        permSendVoiceMessages}
    permAllStage* = {permCreateInstantInvite,
        permUseExternalStickers,
        permUseSlashCommands,
        permManageWebhooks,
        permMentionEveryone,
        permUseExternalEmojis,
        permReadMessageHistory,
        permAddReactions,
        permManageChannels,
        permSendTTSMessage,
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

proc `$`*(p:PermissionFlags): string=
    if p==permMentionEveryone:
        return "Mention @everyone, @here and All Roles"
    system.`$`(p)[4..^1].findandcaptureall(
        re"(^[a-z]|[A-Z]+)[a-z]*"
    ).join" "

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
    result = "users/" & uid

proc endpointUserChannels*(): string =
    result = endpointUsers("@me") & "/channels"

proc endpointVoiceRegions*(): string =
    result = "voice/regions"

proc endpointUserGuilds*(gid=""): string =
    result = endpointUsers("@me")&"/guilds"&(if gid != "": "/" & gid else: "")

proc endpointUserGuildMember*(gid: string): string =
    result = endpointUserGuilds(gid) & "/member"

proc endpointChannels*(cid = ""): string =
    result = "channels"&(if cid != "": "/" & cid else: "")

proc endpointStageInstances*(cid = ""): string =
    result = "stage-instances" & (if cid != "": "/" & cid else: "")

proc endpointGuilds*(gid = ""): string =
    result = "guilds" & (if gid != "": "/" & gid else: "")

proc endpointGuildStickers*(gid: string; sid=""): string =
    result = endpointGuilds(gid)&"/stickers"&(if sid != "": "/"&sid else: "")

proc endpointGuildPreview*(gid: string): string =
    result = endpointGuilds(gid) & "/preview"

proc endpointGuildRegions*(gid: string): string =
    result = endpointGuilds(gid) & "/regions"

proc endpointGuildMFA*(gid: string): string =
    result = endpointGuilds(gid) & "/mfa"

proc endpointGuildAuditLogs*(gid: string): string =
    result = endpointGuilds(gid) & "/audit-logs"

proc endpointGuildAutoModerationRules*(gid: string; rid = ""): string =
    endpointGuilds(gid)&"/auto-moderation/rules"&(if rid!="":"/"&rid else:"")

proc endpointGuildMembers*(gid: string; mid = ""): string =
    result = endpointGuilds(gid) & "/members" & (if mid != "":"/"&mid else: "")

proc endpointGuildScheduledEvents*(gid: string; eid = ""): string =
    result = endpointGuilds(gid)&"/scheduled-events"&(if eid!="":"/"&eid else:"")

proc endpointGuildScheduledEventUsers*(gid, eid: string): string =
    result = endpointGuildScheduledEvents(gid, eid) & "/users"

proc endpointGuildMembersSearch*(gid: string): string =
    result = endpointGuildMembers(gid) & "/search"

proc endpointGuildMembersNick*(gid: string; mid = "@me"): string =
    result = endpointGuildMembers(gid, mid) & "/nick"

proc endpointGuildMembersRole*(gid, mid, rid: string): string =
    result = endpointGuildMembers(gid, mid) & "/roles/" & rid

proc endpointGuildIntegrations*(gid: string; iid = ""): string =
    result = endpointGuilds(gid)&"/integrations"&(if iid!="":"/"&iid else:"")

proc endpointGuildVoiceStatesUser*(gid, uid = "@me"): string =
    result = endpointGuilds(gid) & "/voice-states/" & uid

proc endpointGuildWelcomeScreen*(gid: string): string =
    result = endpointGuilds(gid) & "/welcome-screen"

proc endpointGuildIntegrationsSync*(gid, iid: string): string =
    result = endpointGuildIntegrations(gid, iid) & "/sync"

proc endpointGuildWidget*(gid: string): string =
    result = endpointGuilds(gid) & "/widget"

proc endpointGuildEmojis*(gid: string; eid = ""): string =
    result = endpointGuilds(gid)&"/emojis"&(if eid != "": "/" & eid else: "")

proc endpointGuildRoles*(gid: string; rid = ""): string =
    result = endpointGuilds(gid) & "/roles" & (if rid!="": "/" & rid else: "")

proc endpointGuildPrune*(gid: string): string =
    result = endpointGuilds(gid) & "/prune"

proc endpointInvites*(code = ""): string =
    result = "invites" & (if code != "": "/" & code else: "")

proc endpointGuildInvites*(gid: string): string =
    result = endpointGuilds(gid) & "/" & endpointInvites()

proc endpointGuildVanity*(gid: string): string =
    result = endpointGuilds(gid) & "/vanity-url"

proc endpointGuildOnboarding*(gid: string): string =
    result = endpointGuilds(gid) & "/onboarding"

proc endpointGuildChannels*(gid: string; cid = ""): string =
    result = endpointGuilds(gid) & "/channels" & (if cid != "":"/"&cid else:"")

proc endpointChannelOverwrites*(cid, oid: string): string =
    result = endpointChannels(cid) & "/permissions/" & oid

proc endpointWebhooks*(wid: string): string =
    result = "webhooks/" & wid

proc endpointChannelWebhooks*(cid: string): string =
    result = endpointChannels(cid) & "/webhooks"

proc endpointGuildTemplates*(gid, tid = ""): string =
    result = endpointGuilds(gid) & "/templates" & (if tid!="": "/"&tid else:"")

proc endpointGuildWebhooks*(gid: string): string =
    result = endpointGuilds(gid) & "/webhooks"

proc endpointWebhookToken*(wid, tok: string): string =
    result = endpointWebhooks(wid) & "/" & tok

proc endpointWebhookMessage*(wid, tok, mid: string): string =
    result = endpointWebhookToken(wid, tok) & "/messages/" & mid

proc endpointWebhookTokenSlack*(wid, tok: string): string =
    result = endpointWebhookToken(wid, tok) & "/slack"

proc endpointWebhookTokenGithub*(wid, tok: string): string =
    result = endpointWebhookToken(wid, tok) & "/github"

proc endpointChannelMessages*(cid: string; mid = ""): string =
    result = endpointChannels(cid) & "/messages"
    if mid != "": result = result & "/" & mid

proc endpointChannelMessagesThreads*(cid, mid: string): string =
    result = endpointChannelMessages(cid, mid) & "/threads"

proc endpointChannelThreads*(cid: string): string =
    result = endpointChannels(cid) & "/threads"

proc endpointGuildThreads*(gid: string): string =
    result = endpointGuilds(gid) & "/threads"

proc endpointGuildThreadsActive*(gid: string): string =
    result = endpointGuildThreads(gid) & "/active"

proc endpointChannelThreadsArchived*(cid, typ: string): string =
    result = endpointChannelThreads(cid) & "/archived/" & typ

proc endpointChannelUsersThreadsArchived*(cid, typ: string): string =
    result = endpointChannels(cid) & endpointUsers() & "/archived/" & typ

proc endpointChannelThreadsMembers*(cid: string; uid = ""): string =
    result = endpointChannels(cid) & "/thread-members"
    if uid != "":
        result = result & "/" & uid

proc endpointChannelMessagesCrosspost*(cid, mid: string): string =
    result = endpointChannelMessages(cid, mid) & "/crosspost"

proc endpointChannelInvites*(cid: string): string =
    result = endpointChannels(cid) & "/invites"

proc endpointChannelPermissions*(cid, oid: string): string =
    result = endpointChannels(cid) & "/permissions/" & oid

proc endpointGuildBans*(gid: string; uid = ""): string =
    result = endpointGuilds(gid) & "/bans" & (if uid != "": "/" & uid else: "")

proc endpointBulkDeleteMessages*(cid: string): string =
    result = endpointChannelMessages(cid) & "/bulk-delete"

proc endpointTriggerTyping*(cid: string): string =
    result = endpointChannels(cid) & "/typing"

proc endpointChannelPins*(cid: string; mid = ""): string =
    result = endpointChannels(cid) & "/pins"
    if mid != "":
        result = result & "/" & mid

proc endpointGroupRecipient*(cid, rid: string): string =
    result = endpointChannels(cid) & "/recipients/" & rid

proc endpointReactions*(cid, mid: string; e, uid = ""): string =
    result = endpointChannels(cid) & "/messages/" & mid & "/reactions"
    if e != "":
        result = result & "/" & e
    if uid != "":
        result = result & "/" & uid

proc endpointOAuth2Application*(): string =
    result = "oauth2/applications/@me"

proc endpointGlobalCommands*(aid: string; cid = ""): string =
    result = "applications/" & aid & "/commands" & (if cid!="":"/"&cid else:"")

proc endpointGuildCommands*(aid, gid: string; cid = ""): string =
    result = "applications/" & aid & "/guilds/" & gid & "/commands"
    if cid != "":
        result &= "/" & cid

proc endpointGuildCommandPermission*(aid, gid: string; cid = ""): string =
    result = endpointGuildCommands(aid, gid, cid) & "/permissions"

proc endpointInteractionsCallback*(iid, it: string): string =
    result = "interactions/" & iid & "/" & it & "/callback"

proc endpointApplicationRoleConnectionMetadata*(aid: string): string =
    result = "/applications/"&aid&"/role-connections/metadata"

proc endpointUserApplications*(aid: string): string =
    result = endpointUsers()&"/applications"&(if aid != "": "/"&aid else: "")

proc endpointUserApplicationRoleConnection*(aid: string): string =
    result = endpointUserApplicationRoleConnection(aid) & "/role-connection"

proc endpointStickers*(sid: string): string =
    result = "stickers/"&sid

proc endpointStickerPacks*(): string =
    result = "sticker-packs"
