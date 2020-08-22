when defined(dimscordDebug):
    import strformat
{.hint[XDeclaredButNotUsed]: off.}

type
    PermEnum* = enum
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
    AuditLogChangeKind* = enum
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
const
    libName* = "Dimscord"
    libVer* = "1.0.6"
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

    mtDefault* = 0
    mtRecipientAdd* = 1
    mtRecipientRemove* = 2
    mtCall* = 3
    mtChannelNameChange* = 4
    mtChannelIconChange* = 5
    mtChannelPinnedMessage* = 6
    mtGuildMemberJoin* = 7
    mtUserGuildBoost* = 8
    mtUserGuildBoostTier1* = 9
    mtUserGuildBoostTier2* = 10
    mtUserGuildBoostTier3* = 11
    mtChannelFollowAdd* = 12

    matJoin* = 1
    matSpectate* = 2
    matListen* = 3
    matJoinRequest* = 4

    ctGuildText* = 0
    ctDirect* = 1
    ctGuildVoice* = 2
    ctGroupDM* = 3
    ctGuildParent* = 4
    ctGuildNews* = 5
    ctGuildStore* = 6

    mnlAllMessages* = 0
    mnlOnlyMentions* = 1

    ecfDisabled* = 0
    ecfMembersWithoutRoles* = 1
    ecfAllMembers* = 2

    mfaNone* = 0
    mfaElevated* = 1

    vlNone* = 0
    vlLow* = 1
    vlMedium* = 2
    vlHigh* = 3
    vlVeryHigh* = 4

    ptNone* = 0
    ptTier1* = 1
    ptTier2* = 2
    ptTier3* = 3

    gatPlaying* = 0
    gatStreaming* = 1
    gatListening* = 2
    gatWatching* = 3 # shhhh, this is a secret
    gatCustom* = 4

    whIncoming* = 1
    whFollower* = 2

    iebRemoveRole* = 0
    iebKick* = 1

    aleGuildUpdate* = 1
    aleChannelCreate* = 10
    aleChannelUpdate* = 11
    aleChannelDelete* = 12
    aleChannelOverwriteCreate* = 13
    aleChannelOverwriteUpdate* = 14
    aleChannelOverwriteDelete* = 15
    aleMemberKick* = 20
    aleMemberPrune* = 21
    aleMemberBanAdd* = 22
    aleMemberBanRemove* = 23
    aleMemberUpdate* = 24
    aleMemberRoleUpdate* = 25
    aleMemberMove* = 26
    aleMemberDisconnect* = 27
    aleBotAdd* = 28
    aleRoleCreate* = 30
    aleRoleUpdate* = 31
    aleRoleDelete* = 32
    aleInviteCreate* = 40
    aleInviteUpdate* = 41
    aleInviteDelete* = 42
    aleWebhookCreate* = 50
    aleWebhookUpdate* = 51
    aleWebhookDelete* = 52
    aleEmojiCreate* = 60
    aleEmojiUpdate* = 61
    aleEmojiDelete* = 62
    aleMessageDelete* = 72
    aleMessageBulkDelete* = 73
    aleMessagePin* = 74
    aleMessageUnpin* = 75
    aleIntegrationCreate* = 80
    aleIntegrationUpdate* = 81
    aleIntegrationDelete* = 82

    tmsInvited* = 1 # not to be confused with "The Mysterious Song" lol
    tmsAccepted* = 2

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
    result = endpointGuilds(gid) & "/members" & (if mid != "": "/" & mid else: "")

proc endpointGuildMembersNick*(gid: string; mid = "@me"): string =
    result = endpointGuildMembers(gid, mid) & "/nick"

proc endpointGuildMembersRole*(gid, mid, rid: string): string =
    result = endpointGuildMembers(gid, mid) & "/roles/" & rid

proc endpointGuildIntegrations*(gid: string; iid = ""): string =
    result = endpointGuilds(gid) & "/integrations" & (if iid != "": "/" & iid else: "")

proc endpointGuildIntegrationsSync*(gid, iid: string): string =
    result = endpointGuildIntegrations(gid, iid) & "/sync"

proc endpointGuildEmbed*(gid: string): string =
    result = endpointGuilds(gid) & "/embed"

proc endpointGuildEmojis*(gid: string; eid = ""): string =
    result = endpointGuilds(gid) & "/emojis" & (if eid != "": "/" & eid else: "")

proc endpointGuildRoles*(gid: string; rid = ""): string =
    result = endpointGuilds(gid) & "/roles" & (if rid != "": "/" & rid else: "")

proc endpointGuildPrune*(gid: string): string =
    result = endpointGuilds(gid) & "/prune"

proc endpointInvites*(code = ""): string =
    result = "invites" & (if code != "": "/" & code else: "")

proc endpointGuildInvites*(gid: string): string =
    result = endpointGuilds(gid) & "/" & endpointInvites()

proc endpointGuildVanity*(gid: string): string =
    result = endpointGuilds(gid) & "/vanity-url"

proc endpointGuildChannels*(gid: string; cid = ""): string =
    result = endpointGuilds(gid) & "/channels" & (if cid != "": "/" & cid else: "")

proc endpointChannelOverwrites*(cid, oid: string): string =
    result = endpointChannels(cid) & "/permissions/" & oid

proc endpointWebhooks*(wid: string): string =
    result = "webhooks/" & wid

proc endpointChannelWebhooks*(cid: string): string =
    result = endpointChannels(cid) & "/webhooks"

proc endpointGuildWebhooks*(gid: string): string =
    result = endpointGuilds(gid) & "/webhooks"

proc endpointWebhookToken*(wid, tok: string): string =
    result = endpointWebhooks(wid) & "/" & tok

proc endpointWebhookTokenSlack*(wid, tok: string): string =
    result = endpointWebhookToken(wid, tok) & "/slack"

proc endpointWebhookTokenGithub*(wid, tok: string): string =
    result = endpointWebhookToken(wid, tok) & "/github"

proc endpointChannelMessages*(cid: string; mid = ""): string =
    result = endpointChannels(cid) & "/messages"
    if mid != "": result = result & "/" & mid

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
        result = result & "/" & $mid

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
