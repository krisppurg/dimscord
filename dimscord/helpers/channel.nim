import asyncdispatch, options, json
import ../objects, ../constants

template pin*(m: Message, reason = ""): Future[void] =
    ## Add pinned message.
    getClient.api.addChannelMessagePin(m.channel_id, m.id, reason)

template unpin*(m: Message, reason = ""): Future[void] =
    ## Remove pinned message.
    getClient.api.deleteChannelMessagePin(m.channel_id, m.id, reason)

template getPins*(ch: SomeChannel): Future[seq[Message]] =
    ## Get channel pins.
    getClient.api.getChannelPins(ch.id)

template edit*(ch: GuildChannel;
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
    nsfw = none bool; reason = ""
): Future[GuildChannel] =
    ## Modify a guild channel.
    getClient.api.editGuildChannel(
        ch.id, name, parent_id, topic, rtc_region,
        default_auto_archive_duration, video_quality_mode, flags, available_tags,
        default_reaction_emoji, default_sort_order, default_forum_layout,
        rate_limit_per_user, default_thread_rate_limit_per_user,
        bitrate, user_limit, position, permission_overwrites,
        nsfw, reason
    )

template createChannel*(g: Guild;
    name: string; kind = 0;
    parent_id, topic, rtc_region = none string; nsfw = none bool;
    position, video_quality_mode = none int;
    default_sort_order, default_forum_layout = none int;
    default_thread_rate_limit_per_user = none int;
    available_tags = none seq[ForumTag];
    default_reaction_emoji = none DefaultForumReaction;
    rate_limit_per_user = none range[0..21600];
    bitrate = none range[8000..128000]; user_limit = none range[0..99];
    permission_overwrites = none seq[Overwrite];
    reason = ""
): Future[GuildChannel]  =
    ## Creates a channel.
    getClient.api.createGuildChannel(
        g.id, name, kind, parent_id, topic,
        rtc_region, nsfw, position, video_quality_mode,
        default_sort_order, default_forum_layout,
        default_thread_rate_limit_per_user,
        available_tags, default_reaction_emoji,
        rate_limit_per_user, bitrate, user_limit,
        permission_overwrites, reason
    )

template deleteChannel*(ch: SomeChannel, reason = ""): Future[void] =
    ## Deletes or closes a channel
    getClient.api.deleteChannel(ch.id, reason)

template createInvite*(ch: GuildChannel;
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

template getInvites*(ch: GuildChannel): Future[seq[Invite]] =
    ## Gets a list of a channel's invites.
    getClient.api.getChannelInvites(ch.id)

template getWebhooks*(ch: GuildChannel): Future[seq[Webhook]] =
    ## Gets a list of a channel's webhooks.
    getClient.api.getChannelWebhooks(ch.id)

template delete*(w: Webhook, reason = ""): Future[void] =
    ## Deletes a webhook.
    getClient.api.deleteWebhook(w.id, reason)

template edit*(w: Webhook,
        name, avatar, channel_id = none string;
        reason = ""): Future[void] =
    getClient.api.editWebhook(w.id, name, avatar, channel_id, reason)

template newThread*(ch: GuildChannel;
    name: string;
    auto_archive_duration = 60;
    kind = ctGuildPrivateThread;
    invitable = none bool;
    reason = ""
): Future[GuildChannel] =
    ## Starts a new thread without any message.
    getClient.api.startThreadWithoutMessage(
        ch.id, name, auto_archive_duration, some kind, invitable, reason)

template createStageInstance*(ch: GuildChannel;
        topic: string, reason = "";
        privacy = int plGuildOnly
): Future[StageInstance] =
    ## Create a stage instance.
    getClient.api.createStageInstance(ch.id, topic, privacy, reason)

template editStageInstance*(si: StageInstance | string,
        topic: string;
        privacy = none int; reason = ""): Future[StageInstance] =
    ## Modify a stage instance.
    let st = when si is StageInstance: si.channel_id else: si
    getClient.api.editStageInstance(st, topic, privacy, reason)

template deleteStageInstance*(si: StageInstance | string,
        reason = ""): Future[void] =
    ## Delete the stage instance.
    let st = when si is StageInstance: si.channel_id else: si
    getClient.api.deleteStageInstance(st, reason)
