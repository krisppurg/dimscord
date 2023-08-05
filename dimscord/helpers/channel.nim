template pin*(m: Message, reason = ""): Future[void] =
    ## Add pinned message.
    getClient.api.addChannelMessagePin(m.channel_id, m.id, reason)
        
template unpin*(m: Message, reason = ""): Future[void]  =
    ## Remove pinned message.
    getClient.api.deleteChannelMessagePin(m.channel_id, m.id, reason)

template pins*(ch: GuildChannel): Future[seq[Message]] =
    ## Get channel pins.
    ## Note: Due to a limitation of Discord API, `Message` objects do not contain complete `Reaction` data 
    getClient.api.getChannelPins(ch.id)

template edit*(ch: GuildChannel;
    name, parent_id, topic = none string;
    rate_limit_per_user = none range[0..21600];
    bitrate = none range[8000..128000]; user_limit = none range[0..99];
    position = none int; permission_overwrites = none seq[Overwrite];
    nsfw = none bool; reason = ""
): Future[GuildChannel] =
    ## Modify a guild channel.
    getClient.api.editGuildChannel(
        ch.id, name, parent_id, 
        topic, rate_limit_per_user, bitrate, 
        user_limit, position, permission_overwrites, 
        nsfw, reason
    )

template create*(g: Guild, what: typedesc[GuildChannel];
            name: string; kind = 0;
            parent_id, topic = none string; nsfw = none bool;
            rate_limit_per_user, bitrate, position, user_limit = none int;
            permission_overwrites = none seq[Overwrite];
            reason = ""
): Future[GuildChannel]  =
    ## Creates a channel.
    getClient.api.createGuildChannel(
        g.id, name, kind, parent_id, topic, nsfw,
        rate_limit_per_user, bitrate, position, 
        user_limit, permission_overwrites, reason
    )

template delete*(ch: GuildChannel, reason = ""): Future[void] =
    ## Deletes or closes a channel
    getClient.api.deleteChannel(ch.id, reason)

template create*(ch: GuildChannel, what: typedesc[Invite];
    max_age = 86400; max_uses = 0;
    temporary, unique = false; target_user = none string;
    target_user_id, target_application_id = none string;
    target_type = none InviteTargetType;
    reason = ""
): Future[Invite] =
    ## Creates an instant channel invite.
    getClient.api.createChannelInvite(
        ch.id, max_age, max_uses,
        temporary, unique, target_user,
        target_user_id, target_application_id,
        target_type, reason
    )

template delete*(inv: Invite, reason = ""): Future[void] =
    ## Delete a guild invite.
    getClient.api.deleteInvite(inv.code, reason)

template invites*(ch: GuildChannel): Future[seq[Invite]] =
    ## Gets a list of a channel's invites.
    getClient.api.getChannelInvites(ch.id)

template channel*(g: Guild, channel_id: string): Future[GuildChannel] =
    ## Gets guild channel by ID.
    getClient.api.getChannel(channel_id)

template dms*(s: Shard, channel_id: string): Future[DMChannel] =
    ## Gets dm channel by ID
    let chan = getClient.api.getChannel(channel_id)
    if chan[1].isSome:
        get chan[1]

    case result.kind
    of ctDirect, ctGroupDM:
        discard
    else: 
        raise newException(CatchableError, "Channel type is not a dm")

template webhooks*(ch: GuildChannel): Future[seq[Webhook]] =
    ## Gets a list of a channel's webhooks.
    getClient.api.getChannelWebhooks(ch.id)

template delete*(w: Webhook, reason = ""): Future[void] =
    ## Deletes a webhook.
    getClient.api.deleteWebhook(w.id, reason)

template edit*(w: Webhook, name = w.name, avatar = w.avatar, reason = ""): Future[void] =
    let chan = w.channel_id
    if chan.isSome:
        getClient.api.editWebhook(w.id, name, avatar, w.channel_id, reason)
    else:
        raise newException(CatchableError, "Webhook is not in a channel")

template newThread*(ch: GuildChannel;
    name: string;
    auto_archive_duration = 60;
    kind = ctGuildPrivateThread;
    invitable = none bool;
    reason = ""
): Future[GuildChannel] =
    ## Starts a new thread.
    getClient.api.startThreadWithoutMessage(ch.id, name, auto_archive_duration, some kind, invitable, reason)

template create*(ch: GuildChannel, what: typedesc[StageInstance];
        topic: string, reason = "";
        privacy = int plGuildOnly
): Future[StageInstance] =
    ## Create a stage instance.
    getClient.api.createStageInstance(ch.id, topic, privacy, reason)

template edit*(si: StageInstance, topic = si.topic, privacy = int(si.privacy_level), reason = ""): Future[StageInstance] =
    ## Modify a stage instance.
    getClient.api.editStageInstance(si.channel_id, topic, some privacy, reason)

template delete*(si: StageInstance, reason = ""): Future[void] =
    ## Delete the stage instance.
    getClient.api.deleteStageInstance(si.channel_id, reason)