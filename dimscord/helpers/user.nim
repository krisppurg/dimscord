template get*(g: Guild, what: typedesc[Member], user_id: string): Future[Member] =
    ## Gets a guild member.
    getClient.api.getGuildMember(g.id, user_id)

template get*(g: Guild, what: typedesc[seq[Member]];
        limit: range[1..1000] = 1, after = "0"): Future[seq[Member]] =
    ## Gets a seq of a guild's members.
    getClient.api.getGuildMembers(g.id, limit, after)

template nickname*(g: Guild, nick: string, reason = ""): Future[void] =
    ## Sets the current user's guild nickname
    ## - Set `nick` to "" to reset nickname.
    getClient.api.setGuildNick(g.id, nick, reason)

# requires PR to add `guild_id` field
# template add*(mb: Member, r: Role | string, reason = ""): Future[void] =
#     ## Assigns a member's role.
#     let id: string = when r is Role: r.id else: r
#     getClient.api.addGuildMemberRole(mb.guild_id, mb.user.id, id, reason)

# requires PR to add `guild_id` field
# template remove*(mb: Member, r: Role, reason = ""): Future[void] =
#     ## Removes a member's role.
#     getClient.api.removeGuildMemberRole(mb.guild_id, mb.user.id, r.id, reason)

template leave*(g: Guild): Future[void] =
    ## Leaves a guild.
    getClient.api.leaveGuild(g.id)

template bot*(g: Guild): Future[Member] =
    ## Get guild member as the current user aka you.
    getClient.api.getCurrentGuildMember(g.id)


template get*(app: Application, what: typedesc[seq[ApplicationCommand]];
        with_localizations = false;
        guild_id = ""
): Future[seq[ApplicationCommand]] =
    ## Get slash commands for a specific Application, `guild_id` is optional.
    getClient.api.getApplicationCommands(
        app.id, guild_id, with_localizations
    )

template get*(app: Application, what: typedesc[ApplicationCommand]; 
        command_id: string,
        guild_id = ""
): Future[ApplicationCommand] =
    ## Get a single slash command for a specific Application, `guild_id` is optional.
    getClient.api.getApplicationCommand(
        app.id, guild_id, command_id
    )

template register*(app: Application;
        name, description: string;
        name_localizations, description_localizations = none Table[string, string];
        kind = atSlash; guild_id = ""; dm_permission = true;
        default_member_permissions = none PermissionFlags;
        options: seq[ApplicationCommandOption] = @[]
): Future[ApplicationCommand] =
    ## Create a global or guild only slash command.
    ##
    ## - `guild_id` - Optional
    ## - `name` - Character length (3 - 32)
    ## - `descripton` - Character length (1 - 100)
    ##
    ## **NOTE:** Creating a command with the same name
    ## as an existing command for your application will
    ## overwrite the old command.
    getClient.api.registerApplicationCommand(
        app.id, name, description,
        name_localizations, description_localizations, 
        kind, guild_id, dm_permission,
        default_member_permissions, options
    )

template bulkRegister*(app: Application;
        commands: seq[ApplicationCommand];
        guild_id = ""
): Future[seq[ApplicationCommand]] =
    ## Overwrites existing commands slash command that were registered in guild or application.
    ## This means that only the commands you send in this request will be available globally or in a specific guild
    ## - `guild_id` is optional.
    getClient.api.bulkOverwriteApplicationCommands(
        app.id, commands, guild_id
    )

template edit*(apc: ApplicationCommand;
        name, desc = "";
        name_localizations,description_localizations = none Table[string,string];
        default_member_permissions = none PermissionFlags;
        options: seq[ApplicationCommandOption] = @[]
): Future[ApplicationCommand] =
    ## Modify slash command for a specific application.
    ## - `guild_id` - Optional
    ## - `name` - Optional Character length (3 - 32)
    ## - `descripton` - Optional Character length (1 - 100)
    getClient.api.editApplicationCommand(
        apc.application_id, apc.id, apc.guild_id.get,
        name, desc, name_localizations, description_localizations,
        default_member_permissions, options
    )

template delete*(apc: ApplicationCommand, guild_id = ""): Future[void] =
    ## Delete slash command for a specific application, `guild_id` is optional.
    getClient.api.deleteApplicationCommand(apc.application_id, apc.id, guild_id)

template reply*(i: Interaction;
        content = "";
        embeds: seq[Embed] = @[];
        components: seq[MessageComponent] = @[];
        attachments: seq[Attachment] = @[];             
        ephemeral = static(false), delete_after = static(none float) 
): Future[void] =
    ## Respond to an Interaction.
    ## - Do NOT use this if you used `defer` or if you already sent a `reply`. 
    ## - This is a "response" to an Interaction. Use `followup`, `createFollowupMessage` or `edit` if you already responded.
    ## - Set `ephemeral` to true to send ephemeral responses.

    let flag = if ephemeral == true: { mfEphemeral } else: { }

    getClient.api.interactionResponseMessage(
        application_id,
        token,
        irtChannelMessageWithSource,
        InteractionApplicationCommandCallbackData(
            flags: when ephemeral == true: {mfEphemeral},
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
        components: seq[MessageComponent] = @[]
): Future[void] =
    ## Updates the message on which an Interaction was received on.
    ## - This acknowledges an Interaction.

    let resp = InteractionApplicationCommandCallbackData(
        content: content,
        embeds: embeds,
        attachments: attachments,
        components: components
    )

    getClient.api.interactionResponseMessage(
        i.application_id, i.token,
        kind = irtUpdateMessage,
        response = resp
    )

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
        flags = (when ephemeral: some (1 shl 6) else: none int)
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

template get*(i: Interaction, what: typedesc[Message], message_id = "@original"): Future[Message] =
    ## Get the response (Message) to an Interaction
    getClient.api.getWebhookMessage(i.application_id, i.token, message_id)

template delete*(i: Interaction, message_id = "@original"): Future[void] =
    ## Deletes an Interaction Response or Followup Message
    getClient.api.deleteInteractionResponse(i.application_id, i.token, message_id)

template `defer`*(i: Interaction;
        ephemeral: static[bool] = false;
        hide: static[bool] = false): Future[void] =
    ## Defers the response/update to an Interaction.
    ## - You must use `followup()` or `edit()` after calling `defer()`.
    ## - Set `ephemeral` to `true` to make the Interaction ephemeral.
    ## - Set `hide` to `true` to hide the "thinking" state of the bot.

    let response = static:
        InteractionResponse(
            kind: 
                when hide == true: 
                    irtDeferredUpdateMessage 
                else:
                    irtDeferredChannelMessageWithSource
            ,
            data: some InteractionApplicationCommandCallbackData(
                flags: when ephemeral == true: { mfEphemeral }
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