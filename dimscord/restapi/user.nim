import asyncdispatch, json, options
import ../objects, ../constants
import tables, sequtils, strutils
import requester

proc getGuildMember*(api: RestApi,
        guild_id, user_id: string): Future[Member] {.async.} =
    ## Gets a guild member.
    result = (await api.request(
        "GET",
        endpointGuildMembers(guild_id, user_id)
    )).newMember

proc getGuildMembers*(api: RestApi, guild_id: string;
        limit = 1, after = "0"): Future[seq[Member]] {.async.} =
    ## Gets a list of a guild's members.
    result = ((await api.request(
        "GET",
        endpointGuildMembers(guild_id) & "?limit=" & $limit & "&after=" & after
    ))).elems.map(newMember)

proc setGuildNick*(api: RestApi, guild_id: string;
        nick, reason = "") {.async.} =
    ## Sets the current user's guild nickname, defaults to "" if no nick is set.
    discard await api.request(
        "PATCH",
        endpointGuildMembersNick(guild_id, "@me"),
        $(%*{
            "nick": nick
        }),
        audit_reason = reason
    )

proc addGuildMemberRole*(api: RestApi, guild_id, user_id, role_id: string;
        reason = "") {.async.} =
    ## Assigns a member's role.
    discard await api.request(
        "PUT",
        endpointGuildMembersRole(guild_id, user_id, role_id),
        audit_reason = reason
    )

proc removeGuildMemberRole*(api: RestApi, guild_id, user_id, role_id: string;
        reason = "") {.async.} =
    ## Removes a member's role.
    discard await api.request(
        "DELETE",
        endpointGuildMembersRole(guild_id, user_id, role_id),
        audit_reason = reason
    )

proc getUser*(api: RestApi, user_id: string): Future[User] {.async.} =
    ## Gets a user.
    result = (await api.request("GET", endpointUsers(user_id))).newUser

proc leaveGuild*(api: RestApi, guild_id: string) {.async.} =
    ## Leaves a guild.
    discard await api.request("DELETE", endpointUserGuilds(guild_id))

proc createUserDm*(api: RestApi, user_id: string): Future[DMChannel] {.async.} =
    ## Create user dm.
    result = (await api.request("POST", endpointUserChannels(), $(%*{
        "recipient_id": user_id
    }))).newDMChannel


proc getCurrentUser*(api: RestApi): Future[User] {.async.} =
    ## Gets the current user.
    result = (await api.request("GET", endpointUsers())).newUser

proc getGatewayBot*(api: RestApi): Future[GatewayBot] {.async.} =
    ## Get gateway bot with authentication.
    result = (await api.request("GET", "gateway/bot")).to(GatewayBot)

proc getGateway*(api: RestApi): Future[string] {.async.} =
    ## Get Discord gateway URL.
    result = (await api.request("GET", "gateway"))["url"].str

proc editCurrentUser*(api: RestApi,
        username, avatar = none string): Future[User] {.async.} =
    ## Modifies the bot's username or avatar.
    let payload = newJObject()

    payload.loadOpt(username, avatar)
    payload.loadNullableOptStr(avatar)

    result = (await api.request("PATCH", endpointUsers(), $payload)).newUser

proc createGroupDm*(api: RestApi,
        access_tokens: seq[string];
        nicks: Table[string, string]): Future[DMChannel] {.async.} =
    ## Creates a Group DM Channel.
    ## - `nicks` Example: `{"2123450": "MrDude"}.toTable`
    result = (await api.request(
        "POST",
        endpointUserChannels(),
        $(%*{
            "access_tokens": %access_tokens,
            "nicks": %nicks
        })
    )).newDMChannel

proc getCurrentApplication*(api: RestApi): Future[OAuth2Application] {.async.} =
    ## Gets the current application for the current user (bot user).
    result = (await api.request(
        "GET",
        endpointOAuth2Application()
    )).newOAuth2Application

proc registerApplicationCommand*(api: RestApi; application_id: string;
        guild_id = ""; name, description: string;
        options: seq[ApplicationCommandOption] = @[]
): Future[ApplicationCommand] {.async.} =
    ## Create a global or guild only slash command.
    ## 
    ## - `guild_id` - Optional
    ## - `name` - Character length (3 - 32)
    ## - `descripton` - Character length (1 - 100)
    ## 
    ## **NOTE:** Creating a command with the same name
    ## as an existing command for your application will
    ## overwrite the old command.
    let payload = %*{"name": name, "description": description}
    if options.len > 0: payload["options"] = %(options.map(
        proc (x: ApplicationCommandOption): JsonNode =
            %%*x
    ))
    result = (await api.request(
        "POST",
        (if guild_id != "":
            endpointGuildCommands(application_id, guild_id)
        else:
            endpointGlobalCommands(application_id)),
        $payload
    )).newApplicationCommand


proc getApplicationCommands*(
        api: RestApi, application_id: string; guild_id = ""
): Future[seq[ApplicationCommand]] {.async.} =
    ## Get slash commands for a specific application, `guild_id` is optional.
    result = (await api.request(
        "GET",
        (if guild_id != "":
            endpointGuildCommands(application_id, guild_id)
        else:
            endpointGlobalCommands(application_id)),
    )).elems.map(newApplicationCommand)

proc editApplicationCommand*(api: RestApi, application_id, command_id: string;
        guild_id = ""; name, description: string;
        options: seq[ApplicationCommandOption] = @[]
): Future[ApplicationCommand] {.async.} =
    ## Modify slash command for a specific application.
    ##
    ## - `guild_id` - Optional
    ## - `name` - Character length (3 - 32)
    ## - `descripton` - Character length (1 - 100)
    let payload = %*{"name": name, "description": description}
    if options.len > 0: payload["options"] = %(options.map(
        proc (x: ApplicationCommandOption): JsonNode =
            %%*x
    ))
    result = (await api.request(
        "PATCH",
        (if guild_id != "":
            endpointGuildCommands(application_id, guild_id, command_id)
        else:
            endpointGlobalCommands(application_id, command_id)),
        $payload
    )).newApplicationCommand

proc deleteApplicationCommand*(
        api: RestApi, application_id, command_id: string;
        guild_id = "") {.async.} =
    ## Delete slash command for a specific application, `guild_id` is optional.
    discard await api.request(
        "GET",
        (if guild_id != "":
            endpointGuildCommands(application_id, guild_id, command_id)
        else:
            endpointGlobalCommands(application_id, command_id))
    )

proc createInteractionResponse*(api: RestApi,
        interaction_id, interaction_token: string;
        response: InteractionResponse) {.async.} =
    ## Create an interaction response.
    ## `response.kind` is required.
    discard await api.request(
        "POST",
        endpointInteractionsCallback(interaction_id, interaction_token),
        $(%*{
            "type": int response.kind,
            "data": %response.data
        })
    )