template get*(g: Guild, what: typedesc[Member], user_id: string): Future[Member] =
    ## Gets a guild member.
    getClient.api.getGuildMember(g.id, user_id)

template get*(g: Guild, what: typedesc[seq[Member]];
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
