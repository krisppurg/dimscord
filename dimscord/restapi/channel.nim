import asyncdispatch, json, options
import ../objects, ../constants, ../helpers
import sequtils, requester

proc startTyping*(api: RestApi, channel_id: string) {.async.} =
    ## Starts typing in a specific Discord channel.
    discard await api.request("POST", endpointTriggerTyping(channel_id))

proc pinMessage*(api: RestApi,
        channel_id, message_id: string; reason = "") {.async.} =
    ## Add pinned message.
    discard await api.request(
        "PUT",
        endpointChannelPins(channel_id, message_id),
        audit_reason = reason
    )

proc unpinMessage*(api: RestApi,
        channel_id, message_id: string; reason = "") {.async.} =
    ## Remove pinned message.
    discard await api.request(
        "DELETE",
        endpointChannelPins(channel_id, message_id),
        audit_reason = reason
    )

proc triggerTypingIndicator*(api: RestApi, channel_id: string) {.async, deprecated: "Use startTyping instead".} =
    ## Starts typing in a specific Discord channel.
    ## **Deprecated**: use [startTyping] instead.
    await startTyping(api, channel_id)

proc addChannelMessagePin*(api: RestApi,
        channel_id, message_id: string; reason = "") {.async, deprecated: "Use pinMessage instead.".} =
    ## Add pinned message. (Deprecated: use [pinMessage])
    await api.pinMessage(channel_id, message_id, reason)

proc deleteChannelMessagePin*(api: RestApi,
        channel_id, message_id: string; reason = "") {.async, deprecated: "Use unpinMessage instead".} =
    ## Remove pinned message. (Deprecated: use [unpinMessage])
    await api.unpinMessage(channel_id, message_id, reason)

proc getChannelPins*(api: RestApi,
        channel_id: string): Future[seq[Message]] {.async.} =
    ## Get channel pins.
    result = (await api.request(
        "GET",
        endpointChannelPins(channel_id)
    )).elems.map(newMessage)

proc editGuildChannel*(api: RestApi, channel_id: string;
            name, parent_id, topic, rtc_region = none string;
            default_auto_archive_duration, video_quality_mode = none int;
            flags = none set[ChannelFlags];
            available_tags = none seq[ForumTag];
            default_reaction_emoji = none DefaultForumReaction;
            default_sort_order, default_forum_layout = none int;
            rate_limit_per_user = none range[0..21600];
            default_thread_rate_limit_per_user = none range[0..21600];
            bitrate = none range[8000..128000]; user_limit = none range[0..99];
            position = none int; permission_overwrites = none seq[Overwrite];
            nsfw = none bool;
            reason = ""): Future[GuildChannel] {.async.} =
    ## Modify a guild channel.
    let payload = newJObject()

    if name.isSome: softassert name.get.len in 1..100
    if topic.isSome: softassert topic.get.len in 0..4096

    if default_reaction_emoji.isSome:
        let dre = default_reaction_emoji.get
        if dre.emoji_name.isNone and dre.emoji_id.isNone:
            payload["default_reaction_emoji"] = newJNull()
        else:
            payload["default_reaction_emoji"] = %dre

    payload.loadOpt(name, position, topic, nsfw, rate_limit_per_user,
        bitrate, user_limit, permission_overwrites, parent_id, flags,
        default_forum_layout, default_sort_order,
        default_thread_rate_limit_per_user, available_tags,
        video_quality_mode, rtc_region)

    result = (await api.request(
        "PATCH",
        endpointChannels(channel_id),
        $payload,
        audit_reason = reason
    )).newGuildChannel

proc createGuildChannel*(api: RestApi, guild_id, name: string; kind = 0;
            parent_id, topic, rtc_region = none string; nsfw = none bool;
            position, video_quality_mode = none int;
            default_sort_order, default_forum_layout = none int;
            default_thread_rate_limit_per_user = none int;
            available_tags = none seq[ForumTag];
            default_reaction_emoji = none DefaultForumReaction;
            rate_limit_per_user = none range[0..21600];
            bitrate = none range[8000..128000]; user_limit = none range[0..99];
            permission_overwrites = none seq[Overwrite];
            reason = ""): Future[GuildChannel] {.async.} =
    ## Creates a channel.
    softassert name.len in 1..100
    if topic.isSome:
        if kind notin @[int ctGuildForum, int ctGuildMedia]:
            softassert topic.get.len in 0..1024
        else:
            softassert topic.get.len in 0..4096

    let payload = %*{"name": name, "type": kind}

    payload.loadOpt(position, topic, nsfw, rate_limit_per_user,
                    bitrate, user_limit, parent_id, permission_overwrites,
                    available_tags, default_reaction_emoji, video_quality_mode,
                    default_sort_order, default_forum_layout,
                    default_thread_rate_limit_per_user, rtc_region)

    result = (await api.request(
        "POST",
        endpointGuildChannels(guild_id),
        $payload,
        audit_reason = reason
    )).newGuildChannel
    result.guild_id = guild_id

proc deleteChannel*(api: RestApi, channel_id: string; reason = "") {.async.} =
    ## Deletes or closes a channel.
    discard await api.request(
        "DELETE",
        endpointChannels(channel_id),
        audit_reason = reason
    )

proc editGuildChannelPermissions*(api: RestApi,
        channel_id, overwrite_id: string;
        kind: OverwriteType;
        allow, deny = none set[PermissionFlags];
        reason = "") {.async.} =
    ## Modify the channel's permissions. This is known as the channel's permission overwrite.
    ##
    ## - `overwrite_id` -> Can be user id or role id.
    ## - `allow` is the allowed permissions and `deny` is denied permissions.
    let payload = %*{"type": ord kind}
    if allow.isSome: payload["allow"] = %($allow.get.toBits)
    if deny.isSome: payload["deny"] = %($deny.get.toBits)

    discard await api.request(
        "PUT",
        endpointChannelOverwrites(channel_id, overwrite_id),
        $payload,
        audit_reason = reason
    )

proc createChannelInvite*(api: RestApi, channel_id: string;
        max_age = 86400; max_uses = 0;
        temporary, unique = false; target_user = none string;
        target_user_id, target_application_id = none string;
        target_type = none InviteTargetType;
        reason = ""): Future[Invite] {.async.} =
    ## Creates an instant channel invite.
    let payload = %*{
        "max_age": max_age,
        "max_uses": max_uses,
        "temporary": temporary,
        "unique": unique
    }
    if target_type.isSome:
        payload["target_type"] = %int target_type.get

    payload.loadOpt(target_user,
        target_user_id, target_application_id)

    result = (await api.request(
        "POST",
        endpointChannelInvites(channel_id),
        $payload,
        audit_reason = reason
    )).newInvite

proc deleteGuildChannelPermission*(api: RestApi;
            channel_id, overwrite_id: string;
            reason = "") {.async.} =
    ## Deletes a guild channel overwrite.
    ## - `overwrite_id` -> Can be user id or role id.
    discard await api.request(
        "DELETE",
        endpointChannelOverwrites(channel_id, overwrite_id),
        audit_reason = reason
    )

proc deleteInvite*(api: RestApi, code: string; reason = "") {.async.} =
    ## Deletes a guild invite.
    discard await api.request(
        "DELETE",
        endpointInvites(code),
        audit_reason = reason
    )

proc getChannelInvites*(api: RestApi,
        channel_id: string): Future[seq[Invite]] {.async.} =
    ## Gets a list of a channel's invites.
    result = (await api.request(
        "GET",
        endpointChannelInvites(channel_id)
    )).elems.map(newInvite)

proc getChannel*(api: RestApi;
        channel_id: string
): Future[(Option[GuildChannel], Option[DMChannel])] {.async.} =
    ## Gets channel by ID.
    ## 
    ## Another thing to keep in mind is that it returns a tuple of each
    ## possible channel as an option.
    ## 
    ## Example:
    ## - `channel` Is the result tuple, returned after `await`ing getChannel.
    ## - If you want to get guild channel, then do `channel[0]`
    ## - OR if you want DM channel then do `channel[1]`
    let data = (await api.request(
        "GET",
        endpointChannels(channel_id)
    ))
    if data["type"].getInt == int ctDirect:
        result = (none GuildChannel, some newDMChannel(data))
    else:
        result = (some newGuildChannel(data), none DMChannel)

proc getGuildChannels*(api: RestApi,
        guild_id: string): Future[seq[GuildChannel]] {.async.} =
    ## Gets a list of a guild's channels
    result = (await api.request(
        "GET",
        endpointGuildChannels(guild_id)
    )).elems.map(proc (x: JsonNode): GuildChannel =
                    x["guild_id"] = %*guild_id
                    x.newGuildChannel)

proc editGuildChannelPositions*(api: RestApi, guild_id, channel_id: string;
        position = none int; parent_id = none string; lock_permissions = false;
        reason = "") {.async.} =
    ## Edits a guild channel's position.
    let payload = newJArray()
    payload.add %*{
        "id": channel_id,
        "position": %position,
        "lock_permissions": lock_permissions
    }
    payload.loadOpt(parent_id)
    discard await api.request(
        "PATCH",
        endpointGuildChannels(guild_id),
        $payload,
        audit_reason = reason
    )

proc getChannelWebhooks*(api: RestApi,
        channel_id: string): Future[seq[Webhook]] {.async.} =
    ## Gets a list of a channel's webhooks.
    result = (await api.request(
        "GET",
        endpointChannelWebhooks(channel_id)
    )).elems.map(newWebhook)

proc createWebhook*(api: RestApi, channel_id, name: string;
        avatar = none string; reason = ""): Future[Webhook] {.async.} =
    ## Creates a webhook.
    ## (webhook names cannot be: 'clyde', and they range 1-80)
    result = (await api.request(
        "POST",
        endpointChannelWebhooks(channel_id),
        $(%*{
            "name": name,
            "avatar": avatar
        }),
        audit_reason = reason
    )).newWebhook

proc getWebhook*(api: RestApi, webhook_id: string): Future[Webhook] {.async.} =
    ## Gets a webhook.
    result = (await api.request("GET", endpointWebhooks(webhook_id))).newWebhook

proc deleteWebhook*(api: RestApi, webhook_id: string; reason = "") {.async.} =
    ## Deletes a webhook.
    discard await api.request(
        "DELETE",
        endpointWebhooks(webhook_id),
        audit_reason = reason
    )

proc editWebhook*(api: RestApi, webhook_id: string;
        name, avatar, channel_id = none string; reason = "") {.async.} =
    ## Modifies a webhook.
    let payload = newJObject()

    payload.loadOpt(name, avatar, channel_id)

    discard await api.request("PATCH",
        endpointWebhooks(webhook_id),
        $payload,
        audit_reason = reason
    )

proc startThreadWithoutMessage*(api: RestApi,
    channel_id, name: string;
    auto_archive_duration: range[60..10080];
    kind = none ChannelType; invitable = none bool;
    reason = ""
): Future[GuildChannel] {.async.} =
    ## Starts private thread.
    ## - `auto_archive_duration` Duration in mins. Can set to: 60 1440 4320 10080
    softassert name.len in 1..100
    let payload = %*{
        "name": name,
        "auto_archive_duration": auto_archive_duration
    }

    if kind.isSome:
        softassert(
            int(kind.get) in 10..12,
            "Please choose a valid thread channel type."
        )
        payload["type"] = %(int kind.get)
    payload.loadOpt(invitable)

    result = (await api.request(
        "POST",
        endpointChannelThreads(channel_id),
        $payload,
        audit_reason = reason
    )).newGuildChannel

proc listArchivedThreads*(api: RestApi;
    joined: bool; typ, channel_id: string;
    before = none string; limit = none int
): Future[tuple[
    threads: seq[GuildChannel],
    members: seq[ThreadMember],
    has_more: bool
]] {.async.} =
    ## List public or private archived threads, either joined or not.
    ## - `typ` "public" or "private"
    ## - `joined` list joined private or public archived threads
    var url = endpointChannelThreadsArchived(channel_id, typ)
    if joined:
        url = endpointChannelUsersThreadsArchived(channel_id, typ)

    if before.isSome:
        url &= "?before=" & before.get
        if limit.isSome:
            url &= "&limit=" & $limit.get
    elif limit.isSome:
        url &= "?limit=" & $limit.get

    let data = await api.request("GET", url)

    result = ($data).fromJson(tuple[
        threads: seq[GuildChannel],
        members: seq[ThreadMember],
        has_more: bool
    ])

proc createStageInstance*(api: RestApi; channel_id, topic: string;
    privacy_level = int plGuildOnly; reason = ""
): Future[StageInstance] {.async.} =
    ## Create a stage instance.
    ## Requires the current user to be a moderator of the stage channel.
    softassert topic.len in 1..120
    let payload = %*{
        "channel_id": channel_id,
        "topic": topic,
        "privacy_level": privacy_level
    }
    result = (await api.request(
        "POST",
        endpointStageInstances(),
        $payload,
        audit_reason = reason
    )).newStageInstance

proc getStageInstance*(api: RestApi;
        channel_id: string): Future[StageInstance] {.async.} =
    ## Get a stage instance.
    result = (await api.request(
        "GET",
        endpointStageInstances(channel_id)
    )).newStageInstance

proc editStageInstance*(api: RestApi; channel_id, topic: string;
    privacy_level = none int; reason = ""
): Future[StageInstance] {.async.} =
    ## Modify a stage instance.
    ## Requires the current user to be a moderator of the stage channel. 
    softassert topic.len in 1..120
    let payload = %*{"topic": topic}
    payload.loadOpt(privacy_level)
    result = (await api.request(
        "POST",
        endpointStageInstances(channel_id),
        $payload,
        audit_reason = reason
    )).newStageInstance

proc deleteStageInstance*(api: RestApi;
    channel_id: string, reason = "") {.async.} =
    ## Delete the stage instance.
    discard await api.request(
        "DELETE",
        endpointStageInstances(channel_id),
        audit_reason = reason
    )

proc followAnnouncementChannel*(api: RestApi;
    channel_id, webhook_channel_id: string; reason = "") {.async.} =
    ## Follow announcement channel.
    discard await api.request(
        "POST",
        endpointChannels(channel_id) & "/followers",
        $(%*{
            "webhook_channel_id": webhook_channel_id
        }),
        audit_reason = reason
    )

proc sendSoundboardSound*(api: RestApi;
        channel_id, sound_id: string;
        source_guild_id = none(string)) {.async.} =
    ## Sends soundboard sound when joined in voice channel.
    var payload = %*{"sound_id": sound_id}
    payload.loadOpt(source_guild_id)
    discard await api.request(
        "POST",
        endpointChannels(channel_id) & "/send-soundboard-sound",
        $payload
    )
