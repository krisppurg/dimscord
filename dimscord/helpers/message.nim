template send*(ch: GuildChannel;
    content = "", tts = false;
    nonce: Option[string] or Option[int] = none(int);
    files: seq[DiscordFile] = @[];
    embeds: seq[Embed] = @[];
    attachments: seq[Attachment] = @[];
    allowed_mentions = none AllowedMentions;
    message_reference = none MessageReference;
    components = newSeq[MessageComponent]();
    sticker_ids = newSeq[string]()): Future[Message] =
    ## Sends a Discord message.
    ## - `nonce` This can be used for optimistic message sending
    getClient.api.sendMessage(
            ch.id, content, tts,
            nonce, files, embeds,
            attachments, allowed_mentions, message_reference,
            components, sticker_ids
        )

template reply*(m: Message, content = "";
        embeds: seq[Embed] = @[];
        attachments: seq[Attachment] = @[];
        components: seq[MessageComponent] = @[];
        files: seq[DiscordFile] = @[];
        stickers: seq[string] = @[];
        allowed_mentions = none AllowedMentions;
        tag: static[bool] = false;
        tts: static[bool] = false): Future[Message] =
    ## Replies to a Message.
    ## (?) - set `tag` to `true` in order to tag the replied message in Discord.
 
    getClient.api.sendMessage(
        m.channel_id,
        content, tts, none(int),
        files, embeds, attachments,
        allowed_mentions, 
        when tag == true: some(MessageReference(message_id: some m.id, failIfNotExists: some false)) else: none(MessageReference), 
        components, stickers
    )

template edit*(m: Message;
        content = "";
        embeds: seq[Embed] = @[];
        attachments: seq[Attachment] = @[];
        components: seq[MessageComponent] = @[];
        files: seq[DiscordFile] = @[];
        tts: bool = false;
        flags = none int
        ): Future[Message]  =
    ## Edits a Message.
    ## - Using `edit` for ephemeral messages results in an "Unknown Message" error !

    getClient.api.editMessage(
        m.channel_id, m.id,
        content, tts, flags,
        files, embeds, attachments,
        components
    )

template delete*(m: Message, reason = ""): Future[void] =
    ## Deletes a Message.
    getClient.api.deleteMessage(m.channel_id, m.id, reason)

template react*(m: Message, emoji: string): Future[void] =
    ## Add a reaction to a Message
    ##
    ## - `emoji` Example: '👀', '💩', `likethis:123456789012345678`
    getClient.api.addMessageReaction(m.channel_id, m.id, emoji)

template removeReaction*(m: Message, emoji: string, user_id = "@me"): Future[void] =
    ## Removes the user's or the bot's message reaction to a Discord message.
    getClient.api.deleteMessageReaction(m.channel_id, m.id, emoji, user_id)

template clear*(m: Message, emoji: string): Future[void] =
    ## Remove all the reactions of a given emoji.
    getClient.api.deleteMessageReactionEmoji(m.channel_id, m.id, emoji)

template getReactions*(m: Message, emoji: string;
        before, after = "";
        limit: range[1..100] = 25
): Future[seq[User]] =
    ## Get all user message reactions on the emoji provided.
    getClient.api.getMessageReactions(
        m.channel_id, m.id, emoji,
        before, after, limit
    )
template clearAll*(m: Message): Future[void] =
    ## Remove all the reactions of a given message.
    getClient.api.deleteAllMessageReactions(m.channel_id, m.id)

template leaveThread*(ch: GuildChannel): Future[void] =
    ## Leave thread.
    if ch.kind == ctGuildPublicThread or (ch.kind == ctGuildPrivateThread):
        getClient.api.leaveThread(ch.id)
    else:
        raise newException(CatchableError, "Channel is not a thread !")

template joinThread*(ch: GuildChannel): Future[void] =
    ## Join thread.
    if ch.kind == ctGuildPublicThread or (ch.kind == ctGuildPrivateThread):
        getClient.api.joinThread(ch.id)
    else:
        raise newException(CatchableError, "Channel is not a thread !")

template startThread*(m: Message, name: string;
    auto_archive_duration: range[60..10080], reason = ""
): Future[GuildChannel] =
    ## Starts a public thread.
    ## - `auto_archive_duration` Duration in mins. Can set to: 60 1440 4320 10080
    getClient.api.startThreadWithMessage(
        m.channel_id, m.id, name,
        auto_archive_duration, reason
    )