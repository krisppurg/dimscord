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
        permManageEmojis
        permUseSlashCommands
        permRequestToSpeak
        permManageThreads =   34
        permUsePublicThreads
        permUsePrivateThreads
    GatewayIntent* = enum
        giGuilds,
        giGuildMembers,
        giGuildBans,
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
        giDirectMessageTyping
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
        afPlay
    VoiceSpeakingFlags* = enum
        vsfMicrophone,
        vsfSoundshare,
        vsfPriority
    MessageFlags* = enum
        mfCrossposted,
        mfIsCrosspost,
        mfSupressEmbeds,
        mfSourceMessageDeleted
        mfUrgent,
        mfHasThread,
        mfEphemeral,
        mfLoading
    UserFlags* = enum
        ## Note on this enum:
        ## - The values assigned `n` are equal to `1 shl n`, if
        ## you were to do for example: `cast[int]({apfGatewayPresence})`
        ufNone,
        ufDiscordEmployee,
        ufPartneredServerOwner,
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
        ufDiscordCertifiedModerator
    SystemChannelFlags* = enum
        scfSuppressJoinNotifications,
        scfSupressPremiumSubscriptions,
        scfSupressGuildReminderNotifications
    ApplicationFlags* = enum
        ## Note on this enum:
        ## - The values assigned `n` are equal to `1 shl n`, if
        ## you were to do for example: `cast[int]({apfGatewayPresence})`
        apfNone,
        apfGatewayPresence =          12,
        apfGatewayPresenceLimited,
        apfGatewayGuildMembers,
        apfGatewayGuildMembersLimited,
        apfVerificationPendingGuildLimit,
        apfEmbeded
const
    libName* =  "Dimscord"
    libVer* =   "1.3.0"
    libAgent* = "DiscordBot (https://github.com/krisppurg/dimscord, v" & libVer & ")"

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
    cdnAppIcons* =           cdnBase & "app-icons/"

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
    MessageActivityType* = enum
        matJoin =        1
        matSpectate =    2
        matListen =      3
        matJoinRequest = 4
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
        gnlDefault = 0
        gnlExplicit = 1
        gnlSafe = 2
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
        whIncoming = 1
        whFollower = 2
    IntegrationExpireBehavior* = enum
        iebRemoveRole = 0
        iebKick =       1
    AuditLogEntryType* = enum
        aleGuildUpdate =            1
        aleChannelCreate =          10
        aleChannelUpdate =          11
        aleChannelDelete =          12
        aleChannelOverwriteCreate = 13
        aleChannelOverwriteUpdate = 14
        aleChannelOverwriteDelete = 15
        aleMemberKick =             20
        aleMemberPrune =            21
        aleMemberBanAdd =           22
        aleMemberBanRemove =        23
        aleMemberUpdate =           24
        aleMemberRoleUpdate =       25
        aleMemberMove =             26
        aleMemberDisconnect =       27
        aleBotAdd =                 28
        aleRoleCreate =             30
        aleRoleUpdate =             31
        aleRoleDelete =             32
        aleInviteCreate =           40
        aleInviteUpdate =           41
        aleInviteDelete =           42
        aleWebhookCreate =          50
        aleWebhookUpdate =          51
        aleWebhookDelete =          52
        aleEmojiCreate =            60
        aleEmojiUpdate =            61
        aleEmojiDelete =            62
        aleMessageDelete =          72
        aleMessageBulkDelete =      73
        aleMessagePin =             74
        aleMessageUnpin =           75
        aleIntegrationCreate =      80
        aleIntegrationUpdate =      81
        aleIntegrationDelete =      82
        aleStageInstanceCreate =    83
        aleStageInstanceUpdate =    84
        aleStageInstanceDelete =    85
        aleStickerCreate =          90
        aleStickerUpdate =          91
        aleStickerDelete =          92
    TeamMembershipState* = enum
        tmsInvited =  1 # not to be confused with "The Mysterious Song" lol
        tmsAccepted = 2
    MessageStickerFormat* = enum
        msfPng =    1
        msfAPng =   2
        msfLottie = 3
    ApplicationCommandOptionType* = enum
        acotNothing = 0 # Will never popup unless the user shoots themselves in the foot
        acotSubCommand = 1
        acotSubCommandGroup = 2
        acotStr = 3
        acotInt = 4
        acotBool = 5
        acotUser = 6
        acotChannel = 7
        acotRole = 8
        acotMentionable = 9 ## Includes Users and Roles
        acotNumber = 10     ## A double
    ApplicationCommandType* = enum
        atNothing  = 0 ## Should never appear
        atSlash    = 1 ## CHAT_INPUT
        atUser         ## USER
        atMessage      ## MESSAGE
    ApplicationCommandPermission* = enum
        acpRole = 1
        acpUser
    InteractionType* = enum
        itPing =               1
        itApplicationCommand = 2
        itMessageComponent =   3
    InteractionResponseType* = enum
        irtPong =                             1
        irtChannelMessageWithSource =         4
        irtDeferredChannelMessageWithSource = 5
        irtDeferredUpdateMessage =            6
        irtUpdateMessage =                    7
    InviteTargetType* = enum
        ittStream =              1
        ittEmbeddedApplication = 2
    PrivacyLevel* = enum
        plPublic =    1
        plGuildOnly = 2
    UserPremiumType* = enum
        uptNone =         0
        uptNitroClassic = 1
        uptNitro =        2
    ButtonStyle* = enum
        Primary = 1
        Secondary = 2
        Success = 3
        Danger = 4
        Link = 5
    MessageComponentType* = enum
        None = 0 # This should never happen
        ActionRow = 1
        Button = 2
        SelectMenu = 3


const
    ## This flag is used for Slash Command interaction callback.
    callbackDataFlagEphemeral* = 1 shl 6
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
        permManageRoles,
        permManageWebhooks,
        permUseSlashCommands,
        permManageThreads,
        permUsePublicThreads,
        permUsePrivateThreads}
    permAllVoice* = {permCreateInstantInvite,
        permManageChannels,
        permPrioritySpeaker,
        permVoiceStream,
        permViewChannel,
        permVoiceConnect,
        permVoiceSpeak,
        permVoiceMuteMembers,
        permVoiceDeafenMembers,
        permVoiceMoveMembers,
        permUseVAD,
        permManageRoles}
    permAllStage* = {permCreateInstantInvite,
        permManageChannels,
        permViewChannel,
        permVoiceConnect,
        permVoiceMuteMembers,
        permVoiceDeafenMembers,
        permVoiceMoveMembers,
        permManageRoles,
        permRequestToSpeak}
    permAllChannel* = permAllText + permAllVoice + permAllStage
    permAll* = {permKickMembers,
        permBanMembers,
        permAdministrator,
        permManageGuild,
        permViewAuditLogs,
        permViewGuildInsights,
        permChangeNickname,
        permManageNicknames,
        permManageEmojis} + permAllChannel

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
    system.`$`(p)[4..^1].findAndCaptureAll(
        re"(^[a-z]|[A-Z])[a-z]*"
    ).join" "

# Rest Endpoints

proc endpointUsers*(uid = "@me"): string =
    result = "users/" & uid

proc endpointUserChannels*(): string =
    result = endpointUsers("@me") & "/channels"

proc endpointVoiceRegions*(): string =
    result = "voice/regions"

proc endpointUserGuilds*(gid: string): string =
    result = endpointUsers("@me") & "/guilds/" & gid

proc endpointChannels*(cid = ""): string =
    result = "channels"&(if cid != "": "/" & cid else: "")

proc endpointStageChannels*(cid = ""): string =
    result = "stage-channels" & (if cid != "": "/" & cid else: "")

proc endpointGuilds*(gid = ""): string =
    result = "guilds" & (if gid != "": "/" & gid else: "")

proc endpointGuildPreview*(gid: string): string =
    result = endpointGuilds(gid) & "/preview"

proc endpointGuildRegions*(gid: string): string =
    result = endpointGuilds(gid) & "/regions"

proc endpointGuildAuditLogs*(gid: string): string =
    result = endpointGuilds(gid) & "/audit-logs"

proc endpointGuildMembers*(gid: string; mid = ""): string =
    result = endpointGuilds(gid) & "/members" & (if mid != "":"/"&mid else: "")

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

proc endpointChannelThreadsActive*(cid: string): string =
    result = endpointChannelThreads(cid) & "/active"

proc endpointChannelThreadsArchived*(cid: string, typ: string): string =
    result = endpointChannelThreads(cid) & "/archived/" & typ

proc endpointChannelUsersThreadsArchived*(cid: string, typ: string): string =
    result = endpointChannels(cid) & endpointUsers() & "/archived/" & typ

proc endpointChannelThreadsMembers*(cid: string; uid = ""): string =
    result = endpointChannels(cid) & "/threads-members"
    if uid != "":
        result = "/" & uid

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

proc endpointInteractionsCallback*(iid, it: string): string =
    result = "interactions/" & iid & "/" & it & "/callback"
