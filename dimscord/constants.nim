## This file contains types/enums for every discord object or permission types
## NOTE: Every bitwise enum ends with "Flags", an exception to this,
## is GatewayIntent.
when defined(dimscordDebug):
    import strformat
{.hint[XDeclaredButNotUsed]: off.}

type
    PermissionFlags* = enum
        permCreateInstantInvite = "Create Instant Invite"
        permKickMembers = "Kick Members"
        permBanMembers = "Ban Members"
        permAdministrator = "Administrator"
        permManageChannels = "Manage Channels"
        permManageGuild = "Manage Server"
        permAddReactions = "Add Reactions"
        permViewAuditLogs = "View Audit Log"
        permPrioritySpeaker = "Priority Speaker"
        permVoiceStream = "Voice Stream"
        permViewChannel = "View Channel"
        permSendMessages = "Send Messages"
        permSendTTSMessage = "Send TTS Messages"
        permManageMessages = "Manage Messages"
        permEmbedLinks = "Embed Links"
        permAttachFiles = "Attach Files"
        permReadMessageHistory = "Read Message History"
        permMentionEveryone = "Mention @everyone, @here and All Roles"
        permUseExternalEmojis = "Use External Emojis"
        permViewGuildInsights = "View Guild Insights"
        permVoiceConnect = "Voice Connect"
        permVoiceSpeak = "Voice Speak"
        permVoiceMuteMembers = "Voice Mute Members"
        permVoiceDeafenMembers = "Voice Deafen Members"
        permVoiceMoveMembers = "Voice Move Members"
        permUseVAD = "Use VAD"
        permChangeNickname = "Change Nickname"
        permManageNicknames = "Manage Nicknames"
        permManageRoles = "Manage Roles"
        permManageWebhooks = "Manage Webhooks"
        permManageEmojis = "Manage Emojis"
    GatewayIntent* = enum
        giGuilds,
        giGuildMembers,
        giGuildBans,
        giGuildEmojis,
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
        mfUrgent
    UserFlags* = enum
        ufNone,
        ufDiscordEmployee,
        ufPartneredServerOwner,
        ufHypesquadEvents,
        ufBugHunterLevel1,
        ufHouseBravery = 64,
        ufHouseBrilliance,
        ufHouseBalance,
        ufEarlySupporter,
        ufTeamUser,
        ufSystem = 4096
        ufBugHunterLevel2 = 16384
        ufVerifiedBot = 65536,
        ufEarlyVerifiedBotDeveloper
const
    libName* = "Dimscord"
    libVer* = "1.2.4"
    libAgent* = "DiscordBot (https://github.com/krisppurg/dimscord, v" & libVer & ")"

    cdnBase* = "https://cdn.discordapp.com/"
    restBase* = "https://discord.com/api/"
    cdnCustomEmojis* = cdnBase & "emojis/"
    cdnAttachments* = cdnBase & "attachments/"
    cdnAvatars* = cdnBase & "avatars/"
    cdnIcons* = cdnBase & "icons/"
    cdnSplashes* = cdnBase & "splashes/"
    cdnChannelIcons* = cdnBase & "channel-icons/"
    cdnTeamIcons* = cdnBase & "team-icons/"
    cdnAppAssets* = cdnBase & "app-assets/" # KrispPurg, really? Come on you can do better than that no one is going to use this.
    cdnDiscoverySplashes* = cdnBase & "discovery-splashes/"
    cdnDefaultUserAvatars* = cdnBase & "embed/avatars/"
    cdnAppIcons* = cdnBase & "app-icons/"

type
    MessageType* = enum
        mtDefault = 0
        mtRecipientAdd = 1
        mtRecipientRemove = 2
        mtCall = 3
        mtChannelNameChange = 4
        mtChannelIconChange = 5
        mtChannelPinnedMessage = 6
        mtGuildMemberJoin = 7
        mtUserGuildBoost = 8
        mtUserGuildBoostTier1 = 9
        mtUserGuildBoostTier2 = 10
        mtUserGuildBoostTier3 = 11
        mtChannelFollowAdd = 12
        mtGuildDiscoveryDisqualified = 14
        mtGuildDiscoveryRequalified = 15
        mtReply = 19
        mtApplicationCommand = 20
    MessageActivityType* = enum
        matJoin = 1
        matSpectate = 2
        matListen = 3
        matJoinRequest = 4
    ChannelType* = enum
        ctGuildText = 0
        ctDirect = 1
        ctGuildVoice = 2
        ctGroupDM = 3
        ctGuildParent = 4
        ctGuildNews = 5
        ctGuildStore = 6
    MessageNotificationLevel* = enum
        mnlAllMessages = 0
        mnlOnlyMentions = 1
    ExplicitContentFilter* = enum
        ecfDisabled = 0
        ecfMembersWithoutRoles = 1
        ecfAllMembers = 2
    MFALevel* = enum
        mfaNone = 0
        mfaElevated = 1
    VerificationLevel* = enum
        vlNone = 0
        vlLow = 1
        vlMedium = 2
        vlHigh = 3
        vlVeryHigh = 4
    PremiumTier* = enum
        ptNone = 0
        ptTier1 = 1
        ptTier2 = 2
        ptTier3 = 3
    ActivityType* = enum
        atPlaying = 0
        atStreaming = 1
        atListening = 2
        atWatching = 3 # shhhh, this is a secret
        atCustom = 4
    WebhookType* = enum
        whIncoming = 1
        whFollower = 2
    IntegrationExpireBehavior* = enum
        iebRemoveRole = 0
        iebKick = 1
    AuditLogEntryType* = enum
        aleGuildUpdate = 1
        aleChannelCreate = 10
        aleChannelUpdate = 11
        aleChannelDelete = 12
        aleChannelOverwriteCreate = 13
        aleChannelOverwriteUpdate = 14
        aleChannelOverwriteDelete = 15
        aleMemberKick = 20
        aleMemberPrune = 21
        aleMemberBanAdd = 22
        aleMemberBanRemove = 23
        aleMemberUpdate = 24
        aleMemberRoleUpdate = 25
        aleMemberMove = 26
        aleMemberDisconnect = 27
        aleBotAdd = 28
        aleRoleCreate = 30
        aleRoleUpdate = 31
        aleRoleDelete = 32
        aleInviteCreate = 40
        aleInviteUpdate = 41
        aleInviteDelete = 42
        aleWebhookCreate = 50
        aleWebhookUpdate = 51
        aleWebhookDelete = 52
        aleEmojiCreate = 60
        aleEmojiUpdate = 61
        aleEmojiDelete = 62
        aleMessageDelete = 72
        aleMessageBulkDelete = 73
        aleMessagePin = 74
        aleMessageUnpin = 75
        aleIntegrationCreate = 80
        aleIntegrationUpdate = 81
        aleIntegrationDelete = 82
    TeamMembershipState* = enum
        tmsInvited = 1 # not to be confused with "The Mysterious Song" lol
        tmsAccepted = 2
    MessageStickerFormat* = enum
        msfPng = 1
        msfAPng = 2
        msfLottie = 3
    ApplicationCommandOptionType* = enum
        acotSubCommand = 1
        acotSubCommandGroup = 2
        acotStr = 3
        acotInt = 4
        acotBool = 5
        acotUser = 6
        acotChannel = 7
        acotRole = 8
    InteractionType* = enum
        itPing = 1
        itApplicationCommand = 2
    InteractionResponseType* = enum
        irtPong = 1
        irtAcknowledge = 2
        irtChannelMessage = 3
        irtChannelMessageWithSource = 4
        irtAckWithSource = 5

const
    permAllText* = {permSendTTSMessage,
        permEmbedLinks,
        permReadMessageHistory,
        permUseExternalEmojis,
        permSendMessages,
        permManageMessages,
        permAttachFiles,
        permMentionEveryone,
        permAddReactions}
    permAllVoice* = {permVoiceConnect,
        permVoiceMuteMembers,
        permVoiceMoveMembers,
        permVoiceSpeak,
        permVoiceDeafenMembers,
        permPrioritySpeaker,
        permUseVAD,
        permVoiceStream}
    permAllChannel* = permAllText + permAllVoice
    permAll* = {permAdministrator,
        permManageRoles,
        permKickMembers,
        permCreateInstantInvite,
        permManageNicknames,
        permManageGuild,
        permManageChannels,
        permBanMembers,
        permChangeNickname,
        permManageWebhooks,
        permViewGuildInsights,
        permManageEmojis,
        permViewAuditLogs,
        permViewChannel} + permAllChannel

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
    result = "channels"
    if cid != "": result = result & "/" & cid

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

proc endpointGuildMembersNick*(gid: string; mid = "@me"): string =
    result = endpointGuildMembers(gid, mid) & "/nick"

proc endpointGuildMembersRole*(gid, mid, rid: string): string =
    result = endpointGuildMembers(gid, mid) & "/roles/" & rid

proc endpointGuildIntegrations*(gid: string; iid = ""): string =
    result = endpointGuilds(gid)&"/integrations"&(if iid!="":"/"&iid else:"")

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

