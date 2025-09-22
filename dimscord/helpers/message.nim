import asyncdispatch, options, json
import ../objects, ../constants

template send*(ch: SomeChannel;
    content = "", tts = false;
    nonce: Option[string] or Option[int] = none(int);
    flags: set[MessageFlags] = {};
    files: seq[DiscordFile] = @[];
    embeds: seq[Embed] = @[];
    attachments: seq[Attachment] = @[];
    allowed_mentions = none AllowedMentions;
    message_reference = none MessageReference;
    components = newSeq[MessageComponent]();
    sticker_ids = newSeq[string]();
    poll = none PollRequest;
    enforce_nonce = none bool): Future[Message] =
    ## Sends a Discord message.
    ## - `nonce` This can be used for optimistic message sending
    getClient.api.sendMessage(
        ch.id, content, tts,
        nonce, flags, files, embeds,
        attachments, allowed_mentions, message_reference,
        components, sticker_ids, poll, enforce_nonce
    )

template reply*(m: Message, content = "";
        embeds: seq[Embed] = @[];
        attachments: seq[Attachment] = @[];
        components: seq[MessageComponent] = @[];
        files: seq[DiscordFile] = @[];
        flags: set[MessageFlags] = {};
        stickers: seq[string] = @[];
        allowed_mentions: Option[AllowedMentions] = none(AllowedMentions);
        nonce: Option[string] or Option[int] = none(int);
        mention = false; failifnotexists = false; tts = false): Future[Message] =
    ## Replies to a Message.
    ## - set `mention` to `true` in order to mention the replied message in Discord.
    ## - `failifnotexists` can be used to set the corresponding field on the message reference
    ##   if your `MessageReference` type exposes e.g. `fail_if_not_exists`. See the commented
    ##   example below.

    let refr = if mention: some(m.reference)
      else:
        none(MessageReference)
    getClient.api.sendMessage(
        m.channel_id, content, tts, nonce,
        flags, files, embeds, attachments,
        allowed_mentions, refr, components,
        stickers
    )

template edit*(m: Message;
        content = "";
        embeds: seq[Embed] = @[];
        attachments: seq[Attachment] = @[];
        components: seq[MessageComponent] = @[];
        files: seq[DiscordFile] = @[];
        tts = false;
        flags: set[MessageFlags] = {}): Future[Message]  =
    ## Edits a Message.
    getClient.api.editMessage(
        m.channel_id, m.id,
        content, tts, flags,
        files, embeds, attachments,
        components
    )

template delete*(m: Message; reason = ""): Future[void] =
    ## Deletes a discord Message.
    getClient.api.deleteMessage(m.channel_id, m.id, reason)

template delete*(msgs: seq[Message]; reason = ""): Future[void] =
    ## Bulk deletes messages.
    ## Note: the length of `msg` MUST superior to 0 and inferior to 101.
    getClient.api.bulkDeleteMessages(msgs[0].channel_id, msgs)

template getMessages*(ch: SomeChannel;
        around = "", before = "", after = "";
        limit: range[1..100] = 50): Future[seq[Message]] =
    ## Gets channel messages.
    getClient.api.getChannelMessages(
        ch.id, around, before, after, limit
    )

template getMessage*(ch: SomeChannel;
        message_id: string): Future[Message] =
    ## Get a channel message.
    getClient.api.getChannelMessage(ch.id, message_id)

template react*(m: Message, emoji: string): Future[void] =
    ## Add a reaction to a Message
    ##
    ## - `emoji` Example: '👀', '💩', `likethis:123456789012345678`
    getClient.api.addMessageReaction(m.channel_id, m.id, emoji)

template removeReaction*(m: Message, emoji: string;
        user_id = "@me"): Future[void] =
    ## Removes the user's or the bot's message reaction to a Discord message.
    getClient.api.deleteMessageReaction(m.channel_id, m.id, emoji, user_id)

template removeReactionEmoji*(m: Message, emoji: string): Future[void] =
    ## Remove all the reactions of a given emoji.
    getClient.api.deleteMessageReactionEmoji(m.channel_id, m.id, emoji)

template getReactions*(m: Message, emoji: string;
        kind: ReactionType = ReactionType.rtNormal;
        after = "";
        limit: range[1..100] = 25
): Future[seq[User]] =
    ## Get all user message reactions on the emoji provided.
    getClient.api.getMessageReactions(
        m.channel_id, m.id, emoji,
        ReactionType.rtNormal, after, limit
    )

template clearReactions*(m: Message): Future[void] =
    ## Remove all the reactions of a given message.
    getClient.api.deleteAllMessageReactions(m.channel_id, m.id)

template getThreadMember*(ch: GuildChannel;
        user: User | string; with_member = true): Future[ThreadMember] =
    ## Get a thread member.
    getClient.api.getThreadMember(ch.id, (when user is User: user.id else: user), with_member)

template getThreadMembers*(ch: GuildChannel, with_member = true): Future[seq[ThreadMember]] =
    ## List thread members.
    ## Note: This endpoint requires the `GUILD_MEMBERS` Privileged Intent
    ## if not enabled on your application.
    # assert giGuildMembers in getClient.intents
    getClient.api.getThreadMembers(ch.id, with_member)

template removeFromThread*(ch: GuildChannel, member: Member | User | string;
        reason = ""): Future[void] =
    ## Removes a member from a thread.
    getClient.api.removeThreadMember(
        ch.id,
        (
        when member is Member:
            member.user.id
        elif member is User:
            member.id
        else:
            member
        ),
        reason
    )

template addThreadMember*(ch: GuildChannel;
        member: Member | User | string;
        reason = ""): Future[void] =
    ## Adds a member to a thread.
    getClient.api.addThreadMember(
        ch.id,
        (
        when member is Member:
            member.user.id
        elif member is User:
            member.id
        else:
            member
        ),
        reason
    )

template leaveThread*(ch: GuildChannel): Future[void] =
    ## Leave thread.
    getClient.api.leaveThread(ch.id)

template joinThread*(ch: GuildChannel): Future[void] =
    ## Join thread.
    getClient.api.joinThread(ch.id)

template startThread*(m: Message, name: string;
    auto_archive_duration: range[60..10080], reason = ""
): Future[GuildChannel] =
    ## Starts a public thread.
    ## - `auto_archive_duration` Duration in mins. Can set to: 60 1440 4320 10080
    getClient.api.startThreadWithMessage(
        m.channel_id, m.id, name,
        auto_archive_duration, reason
    )

template endPoll*(m: Message, name: string;
    auto_archive_duration: range[60..10080], reason = ""
): Future[void] =
    ## Ends poll.
    getClient.api.endPoll(m.channel_id, m.id)

template getPollAnswerVoters*(m: Message;
    answer_id: string;
    after = none string; limit: range[1..100] = 25
): Future[seq[User]] =
    ## Ends poll.
    getClient.api.getPollAnswerVoters(m.channel_id, m.id, answer_id, after, limit)
