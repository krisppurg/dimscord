{.hint[XDeclaredButNotUsed]: off.}
import strutils
var restVer* = "7"
var base* = "https://discordapp.com/api/v" & restVer & "/"
const
    libName* = "Dimscord"
    libVer* = "0.0.8"

    cdnBase* = "https://cdn.discordapp.com/"
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

    opDispatch* = 0
    opHeartbeat* = 1
    opIdentify* = 2
    opStatusUpdate* = 3
    opVoiceStateUpdate* = 4
    opResume* = 6
    opReconnect* = 7
    opRequestGuildMembers* = 8
    opInvalidSession* = 9
    opHello* = 10
    opHeartbeatAck* = 11

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

    permCreateInstantInvite* = 0x00000001
    permKickMembers* = 0x00000002
    permBanMembers* = 0x00000004
    permAdministrator* = 0x00000008
    permManageChannels* = 0x00000010
    permManageGuild* = 0x00000020
    permAddReactions* = 0x00000040
    permViewAuditLogs* = 0x00000080
    permPrioritySpeaker* = 0x00000100
    permViewChannel* = 0x00000400
    permSendMessages* = 0x00000800
    permSendTTSMessage* = 0x00001000
    permManageMessages* = 0x00002000
    permEmbedLinks* = 0x00004000
    permAttachFiles* = 0x00008000
    permReadMessageHistory* = 0x00010000
    permMentionEveryone* = 0x00020000
    permUseExternalEmojis* = 0x00040000
    permVoiceConnect* = 0x00100000
    permVoiceSpeak* = 0x00200000
    permVoiceMuteMembers* = 0x00400000
    permVoiceDeafenMemebers* = 0x00800000
    permVoiceMoveMembers* = 0x01000000
    permUseVAD* = 0x02000000
    permChangeNickname* = 0x04000000
    permManageNicknames* = 0x08000000
    permManageRoles* = 0x10000000
    permManageWebhooks* = 0x20000000
    permManageEmojis* = 0x40000000
    permAllText* = 261120
    permAllVoice* = 66060288
    permAllChannel* = 334757073
    permAll* = 334757119

    intentGuilds* = 1 shl 0
    intentGuildMembers* = 1 shl 1
    intentGuildBans* = 1 shl 2
    intentGuildEmojis* = 1 shl 3
    intentGuildIntegrations* = 1 shl 4
    intentGuildWebhooks* = 1 shl 5
    intentGuildInvites* = 1 shl 6
    intentGuildVoiceStates* = 1 shl 7
    intentGuildPresences* = 1 shl 8
    intentGuildMessages* = 1 shl 9
    intentGuildMessageReactions* = 1 shl 10
    intentGuildMessageTyping* = 1 shl 11
    intentDirectMessages* = 1 shl 12
    intentDirectMessageReactions* = 1 shl 13
    intentDirectMessageTyping* = 1 shl 14

    whIncoming* = 1
    whFollower* = 2

proc changeApiVersion*(ver: string = "7") =
    ## Changes the Discord API REST Version
    assert parseInt(ver) >= 6 and parseInt(ver) < 8 # min max number conditions are quite tricky for me.
    restVer = ver

# Rest Endpoints

proc endpointUsers*(uid: string = "@me"): string =
    result = "users/" & uid

proc endpointUserChannels*(): string =
    result = endpointUsers("@me") & "/channels"

proc endpointUserGuilds*(gid: string): string =
    result = endpointUsers("@me") & "/guilds/" & gid

proc endpointChannels*(cid: string = ""): string =
    result = "channels"
    if cid != "": result = result & "/" & cid

proc endpointGuilds*(gid: string = ""): string =
    result = "guilds" & (if gid != "": "/" & gid else: "")

proc endpointGuildMembers*(gid: string, mid: string = ""): string =
    result = endpointGuilds(gid) & "/members" & (if mid != "": "/" & mid else: "")

proc endpointGuildMembersNick*(gid: string, mid: string = "@me"): string =
    result = endpointGuildMembers(gid, mid) & "/nick"

proc endpointGuildMembersRole*(gid: string, mid: string, rid: string): string =
    result = endpointGuildMembers(gid, mid) & "/roles/" & rid

proc endpointGuildRegions*(gid: string): string =
    result = endpointGuilds(gid) & "/regions"

proc endpointGuildIntegrations*(gid: string, iid: string = ""): string =
    result = endpointGuilds(gid) & "/integrations" & (if iid != "": "/" & iid else: "")

proc endpointGuildIntegrationsSync*(gid: string, iid: string): string =
    result = endpointGuildIntegrations(gid, iid) & "/sync"

proc endpointGuildEmbed*(gid: string): string =
    result = endpointGuilds(gid) & "/embed"

proc endpointGuildEmojis*(gid: string, eid: string = ""): string =
    result = endpointGuilds(gid) & "/emojis" & (if eid != "": "/" & eid else: "")

proc endpointGuildRoles*(gid: string, rid: string = ""): string =
    result = endpointGuilds(gid) & "/roles" & (if rid != "": "/" & rid else: "")

proc endpointGuildPrune*(gid: string): string =
    result = endpointGuilds(gid) & "/prune"

proc endpointInvites*(code: string = ""): string =
    result = "invites" & (if code != "": "/" & code else: "")

proc endpointGuildInvites*(gid: string): string =
    result = endpointGuilds(gid) & "/" & endpointInvites()

proc endpointGuildVanity*(gid: string): string =
    result = endpointGuilds(gid) & "/vanity-url"

proc endpointGuildChannels*(gid: string, cid = ""): string =
    result = endpointGuilds(gid) & "/channels" & (if cid != "": "/" & cid else: "")

proc endpointChannelOverwrites*(cid: string, oid: string): string =
    result = endpointChannels(cid) & "/permissions/" & oid

proc endpointChannelMessages*(cid: string; mid: string = ""): string =
    result = endpointChannels(cid) & "/messages"
    if mid != "": result = result & "/" & mid

proc endpointChannelInvites*(cid: string): string =
    result = endpointChannels(cid) & "/invites"

proc endpointChannelPermissions*(cid: string, oid: string): string =
    result = endpointChannels(cid) & "/permissions/" & oid

proc endpointGuildBans*(gid: string, uid: string = ""): string =
    result = endpointGuilds(gid) & "/bans" & (if uid != "": "/" & uid else: "")

proc endpointBulkDeleteMessages*(cid: string): string =
    result = endpointChannelMessages(cid) & "/bulk-delete"

proc endpointTriggerTyping*(cid: string): string =
    result = endpointChannels(cid) & "/typing"

proc endpointChannelPins*(cid: string; mid: string = ""): string =
    result = endpointChannels(cid) & "/pins"
    if mid != "":
        result = result & "/" & $mid

proc endpointGroupRecipient*(cid: string, rid: string): string =
    result = endpointChannels(cid) & "/recipients/" & rid

proc endpointReactions*(cid: string, mid: string; e: string = ""; uid: string = ""): string =
    result = endpointChannels(cid) & "/messages/" & mid & "/reactions"
    if e != "":
        result = result & "/" & e
    if uid != "": # Actually I could just add "/@me"
        result = result & "/" & uid
