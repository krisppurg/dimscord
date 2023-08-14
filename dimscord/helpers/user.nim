template getMember*(g: Guild, user_id: string): Future[Member] =
    ## Gets a guild member.
    getClient.api.getGuildMember(g.id, user_id)

template getMembers*(g: Guild;
        limit: range[1..1000] = 1, after = "0"): Future[seq[Member]] =
    ## Gets a seq of a guild's members.
    getClient.api.getGuildMembers(g.id, limit, after)

template setNickname*(g: Guild, nick: string, reason = ""): Future[void] =
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

template getSelf*(g: Guild): Future[Member] =
    ## Get guild member as the current user aka you.
    getClient.api.getCurrentGuildMember(g.id)

template getCommands*(app: Application;
        guild_id = "";
        with_localizations = false
): Future[seq[ApplicationCommand]] =
    ## Get slash commands for a specific Application, `guild_id` is optional.
    getClient.api.getApplicationCommands(
        app.id, guild_id, with_localizations
    )

template getCommand*(app: Application; 
        guild_id = "";
        command_id: string;
): Future[ApplicationCommand] =
    ## Get a single slash command for a specific Application, `guild_id` is optional.
    getClient.api.getApplicationCommand(
        app.id, g.id, command_id
    )

template registerCommand*(app: Application;
        name, description: string;
        name_localizations,description_localizations = none Table[string,string];
        kind = atSlash; guild_id = ""; dm_permission = true;
        default_member_permissions = none PermissionFlags;
        options: seq[ApplicationCommandOption] = @[]
): Future[ApplicationCommand] =
    ## Create a guild slash command.
    ##
    ## - `guild_id` Optional
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

template bulkRegisterCommands*(app: Application;
        commands: seq[ApplicationCommand];
        guild_id = ""
): Future[seq[ApplicationCommand]] =
    ## Overwrites existing commands slash command that were registered in guild.
    ## This means that only the commands you send in this request will be available in a specific guild
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
        ephemeral = false
): Future[void] =
    ## Respond to an Interaction.
    ## - Do NOT use this if you used `defer` or if you already sent a `reply`. 
    ## - This is a "response" to an Interaction. Use `followup`, `createFollowupMessage` or `edit` if you already responded.
    ## - Set `ephemeral` to true to send ephemeral responses.

    let flag = if ephemeral: {mfEphemeral} else: {}

    getClient.api.interactionResponseMessage(
        application_id,
        token,
        irtChannelMessageWithSource,
        InteractionApplicationCommandCallbackData(
            flags: flag,
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
    getClient.api.interactionResponseMessage(
        i.application_id, i.token,
        kind = irtUpdateMessage,
        response = InteractionCallbackDataMessage(
            content: content,
            embeds: embeds,
            attachments: attachments,
            components: components
        )
    )

template followup*(i: Interaction;
        content = "";
        embeds: seq[Embed] = @[];
        components: seq[MessageComponent] = @[];
        attachments: seq[Attachment] = @[];
        files: seq[DiscordFile] = @[];
        allowed_mentions = none AllowedMentions;
        tts = false;
        ephemeral = false): Future[Message] =
    ## Follow-up to an Interaction.
    ## - Use this function when sending messages to acknowledged Interactions.

    getClient.api.createFollowupMessage(
        i.application_id, i.token,
        content, tts,
        files, attachments,
        embeds, allowed_mentions,
        components,
        flags = (if ephemeral: some mfEphemeral.ord else: none int)
    )
    
template edit*(i: Interaction, message_id = "@original";
        content = none string;
        embeds = newSeq[Embed]();
        allowed_mentions = none AllowedMentions;
        attachments = newSeq[Attachment]();
        files = newSeq[DiscordFile]();
        components = newSeq[MessageComponent]()
): Future[Message] =
    ## Edit an interaction response.
    ## You can actually use this to modify original interaction or followup message.
    ##
    ## - `message_id` can be `@original`
    getClient.api.editWebhookMessage(
        i.application_id, i.token, message_id,
        content, i.channel_id,
        embeds, allowed_mentions,
        attachments, files,
        components
    )

template getResponse*(i: Interaction, message_id="@original"): Future[Message] =
    ## Get the response (Message) to an Interaction
    getClient.api.getWebhookMessage(i.application_id, i.token, message_id)

template delete*(i: Interaction, message_id = "@original"): Future[void] =
    ## Deletes an Interaction Response or Followup Message
    getClient.api.deleteInteractionResponse(i.application_id, i.token, message_id)

template deferResponse*(i: Interaction;
        ephemeral, hide = false): Future[void] =
    ## Defers the response/update to an Interaction.
    ## - You must use `followup()` or `edit()` after calling `defer()`.
    ## - Set `ephemeral` to `true` to make the Interaction ephemeral.
    ## - Set `hide` to `true` to hide the "X is thinking..." state of the bot.
    getClient.api.createInteractionResponse(
        i.id, 
        i.token, 
        InteractionResponse(
            kind: (if hide: irtDeferredUpdateMessage 
                  else: irtDeferredChannelMessageWithSource),
            data: some InteractionCallbackDataMessage(
                flags: if ephemeral: {mfEphemeral} else: {}
            )
        )
    )

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
