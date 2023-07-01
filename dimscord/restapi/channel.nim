import asyncdispatch, json, options, jsony
import ../objects, ../constants, ../helpers
import tables, sequtils
import uri, macros, requester

proc triggerTypingIndicator*(api: RestApi, channel_id: string) {.async.} =
    ## Starts typing in a specific Discord channel.
    discard await api.request("POST", endpointTriggerTyping(channel_id))

proc addChannelMessagePin*(api: RestApi,
        channel_id, message_id: string; reason = "") {.async.} =
    ## Add pinned message.
    discard await api.request(
        "PUT",
        endpointChannelPins(channel_id, message_id),
        audit_reason = reason
    )

proc deleteChannelMessagePin*(api: RestApi,
        channel_id, message_id: string; reason = "") {.async.} =
    ## Remove pinned message.
    discard await api.request(
        "DELETE",
        endpointChannelPins(channel_id, message_id),
        audit_reason = reason
    )

proc getChannelPins*(api: RestApi,
        channel_id: string): Future[seq[Message]] {.async.} =
    ## Get channel pins.
    result = (await api.request(
        "GET",
        endpointChannelPins(channel_id)
    )).elems.map(newMessage)

proc editGuildChannel*(api: RestApi, channel_id: string;
            name, parent_id, topic = none string;
            rate_limit_per_user = none range[0..21600];
            bitrate = none range[8000..128000]; user_limit = none range[0..99];
            position = none int; permission_overwrites = none seq[Overwrite];
            nsfw = none bool; reason = ""): Future[GuildChannel] {.async.} =
    ## Modify a guild channel.
    let payload = newJObject()

    if name.isSome:
        assert name.get.len >= 2 and name.get.len <= 100
    if topic.isSome:
        assert topic.get.len <= 1024

    payload.loadOpt(name, position, topic, nsfw, rate_limit_per_user,
        bitrate, user_limit, permission_overwrites, parent_id)

    payload.loadNullableOptStr(topic, parent_id)
    payload.loadNullableOptInt(position, rate_limit_per_user, bitrate,
        user_limit)

    result = (await api.request(
        "PATCH",
        endpointChannels(channel_id),
        $payload,
        audit_reason = reason
    )).newGuildChannel

proc createGuildChannel*(api: RestApi, guild_id, name: string; kind = 0;
            parent_id, topic = none string; nsfw = none bool;
            rate_limit_per_user, bitrate, position, user_limit = none int;
            permission_overwrites = none seq[Overwrite];
            reason = ""): Future[GuildChannel] {.async.} =
    ## Creates a channel.
    assert name.len in 1..100
    if topic.isSome:
        assert topic.get.len in 0..1024

    let payload = %*{"name": name, "type": kind}

    payload.loadOpt(position, topic, nsfw, rate_limit_per_user,
                    bitrate, user_limit, parent_id, permission_overwrites)

    result = (await api.request(
        "POST",
        endpointGuildChannels(guild_id),
        $payload,
        audit_reason = reason
    )).newGuildChannel

proc deleteChannel*(api: RestApi, channel_id: string; reason = "") {.async.} =
    ## Deletes or closes a channel.
    discard await api.request(
        "DELETE",
        endpointChannels(channel_id),
        audit_reason = reason
    )

proc editGuildChannelPermissions*(api: RestApi,
        channel_id, perm_id, kind: string or int;
        perms: PermObj; reason = "") {.async.} =
    ## Modify the channel's permissions.
    ## 
    ## - `kind` Must be "role" or "member", or 0 or 1 if v8.
    let payload = newJObject()

    when kind is int:
        payload["type"] = %(if kind == 0: "role" else: "member") 

    when kind is string:
        payload["type"] = %(if kind == "role": 0 else: 1)

    if perms.allowed.len > 0:
        payload["allow"] = %($cast[int](perms.allowed))
    if perms.denied.len > 0:
        payload["deny"] = %($cast[int](perms.denied))

    discard await api.request(
        "PUT",
        endpointChannelOverwrites(channel_id, perm_id),
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

proc deleteGuildChannelPermission*(api: RestApi, channel_id, overwrite: string;
        reason = "") {.async.} =
    ## Deletes a guild channel overwrite.
    discard await api.request(
        "DELETE",
        endpointChannelOverwrites(channel_id, overwrite),
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
    )).elems.map(newGuildChannel)

proc editGuildChannelPositions*(api: RestApi, guild_id, channel_id: string;
        position = none int; parent_id = none string; lock_permissions = false;
        reason = "") {.async.} =
    ## Edits a guild channel's position.
    let payload = newJArray()
    payload.add %*{
        "id": channel_id,
        "position": %position,
        "parent_id": %parent_id,
        "lock_permissions": lock_permissions
    }
    payload.loadNullableOptStr(parent_id)
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
    payload.loadNullableOptStr(avatar)

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
    assert name.len in 1..100
    let payload = %*{
        "name": name,
        "auto_archive_duration": auto_archive_duration
    }

    if kind.isSome:
        assert(
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
    assert topic.len in 1..120
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
    assert topic.len in 1..120
    let payload = %*{"topic": topic}
    payload.loadNullableOptInt(privacy_level)
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

proc pin*(m: Message, reason = "") {.async.} =
    ## Add pinned message.
    await getClient().api.addChannelMessagePin(m.channel_id, m.id, reason)

proc unpin*(m: Message, reason = "") {.async.} =
    ## Remove pinned message.
    await getClient().api.deleteChannelMessagePin(m.channel_id, m.id, reason)

proc pins*(ch: GuildChannel): Future[seq[Message]] {.async.} =
    ## Get channel pins.
    ## Note: Due to a limitation of Discord API, `Message` objects do not contain complete `Reaction` data 
    result = await getClient().api.getChannelPins(ch.id)

proc edit*(ch: GuildChannel;
            name, parent_id, topic = none string;
            rate_limit_per_user = none range[0..21600];
            bitrate = none range[8000..128000]; user_limit = none range[0..99];
            position = none int; permission_overwrites = none seq[Overwrite];
            nsfw = none bool; reason = ""): Future[GuildChannel] {.async.} =
    ## Modify a guild channel.
    result = await getClient().api.editGuildChannel(
        ch.id, name, parent_id, 
        topic, rate_limit_per_user, bitrate, 
        user_limit, position, permission_overwrites, 
        nsfw, reason
    )

proc delete*(ch: GuildChannel, reason = "") {.async.} =
    ## Deletes or closes a channel/thread
    await getClient().api.deleteChannel(ch.id, reason)

proc newInvite*(ch: GuildChannel;
        max_age = 86400; max_uses = 0;
        temporary, unique = false; target_user = none string;
        target_user_id, target_application_id = none string;
        target_type = none InviteTargetType;
        reason = ""
): Future[Invite] {.async.} =
    ## Creates an instant channel invite.
    result = await getClient().api.createChannelInvite(
        ch.id, max_age, max_uses,
        temporary, unique, target_user,
        target_user_id, target_application_id,
        target_type, reason
    )

proc delete*(inv: Invite, reason = "") {.async.} =
    ## Delete a guild invite.
    await getClient().api.deleteInvite(inv.code, reason)

proc invites*(ch: GuildChannel): Future[seq[Invite]] {.async.} =
    ## Gets a list of a channel's invites.
    result = await getClient().api.getChannelInvites(ch.id)

proc channel*(g: Guild, channel_id: string): Future[GuildChannel] {.async.} =
    ## Gets guild channel by ID.

    let chan = await getClient().api.getChannel(channel_id)

    if chan[0].isSome:
        result = get chan[0]

    case result.kind
    of ctGuildPrivateThread, ctGuildPublicThread:
        raise newException(CatchableError, "Channel type is not a text channel")
    else: 
        discard

proc thread*(g: Guild, thread_id: string): Future[GuildChannel] {.async.} =
    ## Gets guild thread by ID.
    
    let thr = await getClient().api.getChannel(thread_id)
    
    if thr[0].isSome:
        result = get thr[0]

    case result.kind
    of ctGuildPrivateThread, ctGuildPublicThread:
        discard
    else: 
        raise newException(CatchableError, "Channel type is not a public/private thread")

proc dms*(s: Shard, channel_id: string): Future[DMChannel] {.async.} =
    ## Gets dm channel by ID

    let chan = await getClient().api.getChannel(channel_id)
    if chan[1].isSome:
        result = get chan[1]
    
    case result.kind
    of ctDirect, ctGroupDM:
        discard
    else: 
        raise newException(CatchableError, "Channel type is not a dm")

proc webhooks*(ch: GuildChannel): Future[seq[Webhook]] {.async.} =
    ## Gets a list of a channel's webhooks.
    result = await getClient().api.getChannelWebhooks(ch.id)

proc delete*(w: Webhook, reason = "") {.async.} =
    ## Deletes a webhook.
    await getClient().api.deleteWebhook(w.id, reason)

proc edit*(w: Webhook, name = w.name, avatar = w.avatar, reason = "") {.async.} =
    let chan = w.channel_id
    if chan.isSome:
        await getClient().api.editWebhook(w.id, name, avatar, w.channel_id, reason)
    else:
        raise newException(CatchableError, "Webhook is not in a channel")

proc newThread*(ch: GuildChannel;
    name: string;
    auto_archive_duration = 60;
    kind = ctGuildPrivateThread;
    invitable = none bool;
    reason = ""
): Future[GuildChannel] {.async.} =
    ## Starts a new thread.

    result = await getClient().api.startThreadWithoutMessage(ch.id, name, auto_archive_duration, some kind, invitable, reason)

proc createStage*(ch: GuildChannel, topic: string, reason = "", privacy = int plGuildOnly): Future[StageInstance] {.async.} =
    ## Create a stage instance.
    ## 
    result = await getClient().api.createStageInstance(ch.id, topic, privacy, reason)

proc edit*(si: StageInstance, topic = si.topic, privacy = int(si.privacy_level), reason = ""): Future[StageInstance] {.async.} =
    ## Modify a stage instance.
    result = await getClient().api.editStageInstance(si.channel_id, topic, some privacy, reason)

proc delete*(si: StageInstance, reason = "") {.async.} =
    ## Delete the stage instance.
    await getClient().api.deleteStageInstance(si.channel_id, reason)