{.hint[XDeclaredButNotUsed]: off.}

type
    PermEnum* = enum
        permCreateInstantInvite 
        permKickMembers 
        permBanMembers 
        permAdministrator 
        permManageChannels 
        permManageGuild 
        permAddReactions 
        permViewAuditLogs 
        permPrioritySpeaker 
        permViewChannel 
        permSendMessages 
        permSendTTSMessage 
        permManageMessages 
        permEmbedLinks 
        permAttachFiles 
        permReadMessageHistory 
        permMentionEveryone 
        permUseExternalEmojis 
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
    GatewayIntent* = enum
        intentGuilds,
        intentGuildMembers,
        intentGuildBans,
        intentGuildEmojis,
        intentGuildIntegrations,
        intentGuildWebhooks,
        intentGuildInvites,
        intentGuildVoiceStates,
        intentGuildPresences,
        intentGuildMessages,
        intentGuildMessageReactions,
        intentGuildMessageTyping,
        intentDirectMessages,
        intentDirectMessageReactions,
        intentDirectMessageTyping
const
    libName* = "Dimscord"
    libVer* = "0.1.0"

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

    gatewayVer* = "6"

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

    eclDisabled* = 0
    eclMembersWithoutRoles* = 1
    eclAllMembers* = 2

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
    gatSteaming* = 1
    gatListening* = 2
    gatWatching* = 3 # shhhh, this is a secret
    gatCustom* = 4

    whIncoming* = 1
    whFollower* = 2

    iebRemoveRole* = 0
    iebKick* = 1

    permAllText* = {permViewChannel, 
        permSendMessages, 
        permSendTTSMessage, 
        permManageMessages,
        permEmbedLinks, 
        permAttachFiles,
        permReadMessageHistory,
        permMentionEveryone}
    permAllVoice* = {permVoiceConnect,
        permVoiceSpeak,
        permVoiceMuteMembers,
        permVoiceMoveMembers,
        permVoiceDeafenMembers,
        permUseVAD,
        permPrioritySpeaker}
    permAllChannel* = {permCreateInstantInvite,
        permManageRoles,
        permManageChannels,
        permAddReactions,
        permViewAuditLogs} + permAllText + permAllVoice
    permAll* = {permKickMembers,
        permBanMembers,
        permManageGuild,
        permAdministrator} + permAllChannel

# Rest Endpoints

proc endpointUsers*(uid: string = "@me"): string =
    result = "users/" & uid

proc endpointUserChannels*(): string =
    result = endpointUsers("@me") & "/channels"

proc endpointUserGuilds*(gid: string): string =
    result = endpointUsers("@me") & "/guilds/" & gid

proc endpointChannels*(cid = ""): string =
    result = "channels"
    if cid != "": result = result & "/" & cid

proc endpointGuilds*(gid = ""): string =
    result = "guilds" & (if gid != "": "/" & gid else: "")

proc endpointGuildPreview*(gid: string): string =
    result = endpointGuilds(gid) & "/preview"

proc endpointGuildMembers*(gid: string; mid = ""): string =
    result = endpointGuilds(gid) & "/members" & (if mid != "": "/" & mid else: "")

proc endpointGuildMembersNick*(gid: string; mid: string = "@me"): string =
    result = endpointGuildMembers(gid, mid) & "/nick"

proc endpointGuildMembersRole*(gid, mid, rid: string): string =
    result = endpointGuildMembers(gid, mid) & "/roles/" & rid

proc endpointGuildRegions*(gid: string): string =
    result = endpointGuilds(gid) & "/regions"

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
    if uid != "": # Actually I could just add "/@me"
        result = result & "/" & uid
