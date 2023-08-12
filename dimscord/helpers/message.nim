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
        tag = false;
        tts = false): Future[Message] =
    ## Replies to a Message.
    ## (?) - set `tag` to `true` in order to tag the replied message in Discord.
    getClient.api.sendMessage(
        m.channel_id,
        content, tts, none(int),
        files, embeds, attachments,
        allowed_mentions, 
        (if tag == true: some m.reference),
        components, stickers
    )

template edit*(m: Message;
        content = "";
        embeds: seq[Embed] = @[];
        attachments: seq[Attachment] = @[];
        components: seq[MessageComponent] = @[];
        files: seq[DiscordFile] = @[];
        tts = false;
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

template delete*(m: Message | seq[Message] | seq[string], reason = ""): Future[void] =
    ## Deletes one or multiple Message(s).
    when m is Message:
        getClient.api.deleteMessage(m.channel_id, m.id, reason)
    elif m is seq[string]:
        getClient.api.bulkDeleteMessages(m[0].channel_id, m, reason)     
    elif m is seq[Message]:
        getClient.api.bulkDeleteMessages(
            m[0].channel_id, 
            (collect(newSeqOfCap m.len): 
                for msg in m.items: msg.id),
            reason
        )

template get*(ch: GuildChannel, what: typedesc[seq[Message]];
        around, before, after = "";
        limit: range[1..100] = 50): Future[seq[Message]] =
    ## Gets channel messages.
    getClient.api.getChannelMessages(
        ch.id, around, before, after, limit
    )

template get*(ch: GuildChannel, what: typedesc[Message];
        message_id: string): Future[Message] =
    ## Get a channel message.
    getClient.api.getChannelMessage(ch.id, message_id)

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

template followup*(i: Interaction;
        content = "";
        embeds: seq[Embed] = @[];
        components: seq[MessageComponent] = @[];
        attachments: seq[Attachment] = @[];
        files: seq[DiscordFile] = @[];
        ephemeral = false): Future[Message] =
    ## Follow-up to an Interaction.
    ## - Use this function when sending messages to acknowledged Interactions.

    getClient.api.createFollowupMessage(
        application_id = i.application_id,
        interaction_token = i.token,
        content = content,
        attachments = attachments,
        embeds = embeds,
        components = components,
        files = files,
        flags = (if ephemeral: some (1 shl 6) else: none int)
    )

template edit*(i: Interaction, message_id = "@original";
        content = none string;
        embeds = newSeq[Embed]();
        allowed_mentions = none AllowedMentions;
        attachments = newSeq[Attachment]();
        files = newSeq[DiscordFile]();
        components = newSeq[MessageComponent]()
): Future[Message] =
    ## Edit an interaction response
    ## You can actually use this to modify original interaction or followup message.
    ##
    ## - `message_id` can be `@original`
    getClient.api.editWebhookMessage(
        i.id, i.token, message_id,
        content = content,
        embeds = embeds,
        allowed_mentions = allowed_mentions,
        attachments = attachments,
        files = files,
        components = components,
    )

template reply*(i: Interaction;
        content = "";
        embeds: seq[Embed] = @[];
        components: seq[MessageComponent] = @[];
        attachments: seq[Attachment] = @[];             
        ephemeral = false
): Future[void] =
    ## Respond to an Interaction.
    ## - Do NOT use this if you used `defer` or if you already sent a `reply`. 
    ## - This is a "response" to an Interaction. Use `followup`, `createFollowupMessage` or `edit` if you already responded.
    ## - Set `ephemeral` to true to send ephemeral responses.
    
    getClient.api.interactionResponseMessage(
        application_id,
        token,
        irtChannelMessageWithSource,
        InteractionApplicationCommandCallbackData(
            flags: if ephemeral == true: {mfEphemeral},
            content: content,
            components: components,
            attachments: attachments,
            embeds: embeds
        )
    )

template update*(i: Interaction;
        content = "";
        embeds: seq[Embed] = @[];
        attachments: seq[Attachment] = @[];
        components: seq[MessageComponent] = @[];
        flags: set[MessageFlags] = {};
        tts: Option[bool] = none bool
): Future[void] =
    ## For Components only: edits the message the component is attached to.
    ## - This acknowledges an Interaction.
    
    # assert i.kind == itMessageComponent
    let resp = InteractionApplicationCommandCallbackData(
        content: content,
        embeds: embeds,
        attachments: attachments,
        components: components,
        flags: flags,
        tts: tts
    )

    getClient.api.interactionResponseMessage(
        i.application_id, i.token,
        kind = irtUpdateMessage,
        response = resp
    )

template get*(i: Interaction, what: typedesc[Message], message_id = "@original"): Future[Message] =
    ## Get the response (Message) to an Interaction
    getClient.api.getWebhookMessage(i.application_id, i.token, message_id)

template delete*(i: Interaction, message_id = "@original"): Future[void] =
    ## Deletes an Interaction Response or Followup Message
    getClient.api.deleteInteractionResponse(i.application_id, i.token, message_id)

template `defer`*(i: Interaction;
        ephemeral = false;
        hide = false): Future[void] =
    ## Defers the response/update to an Interaction.
    ## - You must use `followup()` or `edit()` after calling `defer()`.
    ## - Set `ephemeral` to `true` to make the Interaction ephemeral.
    ## - Set `hide` to `true` to hide the "thinking" state of the bot.

    let response = 
        InteractionResponse(
            kind: 
                if hide == true: 
                    irtDeferredUpdateMessage 
                else:
                    irtDeferredChannelMessageWithSource
            ,
            data: some InteractionApplicationCommandCallbackData(
                flags: if ephemeral == true: { mfEphemeral }
            )
        )

    getClient.api.createInteractionResponse(i.id, i.token, response)

template suggest*(i: Interaction;
        choices: seq[ApplicationCommandOptionChoice]
): Future[void] =
    ## Create an interaction response which is an autocomplete response.
    getClient.api.interactionResponseAutocomplete(i.id, i.token, InteractionCallbackDataAutocomplete(choices: choices))

template sendModal*(i: Interaction;
        response: InteractionCallbackDataModal
): Future[void] =
    ## Create an interaction response which is a modal.
    getClient.api.interactionResponseModal(i.id, i.token, response)

template get*(what: typedesc[Sticker], sticker_id: string): Future[Sticker] =
    getClient.api.getSticker(sticker_id)

template get*(what: typedesc[StickerPack]): Future[seq[StickerPack]] =
    getClient.api.getNitroStickerPacks()

template get*(ch: GuildChannel, what: typedesc[ThreadMember];
        user: User | string): Future[ThreadMember] =
    ## Get a thread member.
    getClient.api.getThreadMember(
        when user is User: user.id else: user
    )

template get*(ch: GuildChannel, what: typedesc[seq[ThreadMember]]): Future[seq[ThreadMember]] =
    ## List thread members.
    ## Note: This endpoint requires the `GUILD_MEMBERS` Privileged Intent 
    ## if not enabled on your application.
    # assert giGuildMembers in getClient.intents
    getClient.api.getThreadMembers(ch.id)

template remove*(ch: GuildChannel, member: Member | User | string;
        reason = ""): Future[void] =
    ## Removes a member from a thread.
    assert ch.kind in {ctGuildPublicThread, ctGuildPrivateThread}
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

template add*(ch: GuildChannel, member: Member | User | string;
        reason = ""): Future[void] =
    ## Adds a member to a thread.
    assert ch.kind in {ctGuildPublicThread, ctGuildPrivateThread}
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