import asyncdispatch, json, options, jsony, httpclient
import ../objects, ../constants
import tables, sequtils, strutils, os, mimetypes
import requester

proc getInvite*(api: RestApi, code: string;
        with_counts, with_expiration = false;
        auth = false; guild_scheduled_event_id = none string;
): Future[Invite] {.async.} =
    ## Gets a discord invite, it can be a vanity code.
    ##
    ## - `auth` Whether you should get the invite while authenticated.
    var queryparams = "?with_counts="&($with_counts) &
        "&with_expiration="&($with_counts)
    if guild_scheduled_event_id.isSome:
        queryparams&="&guild_scheduled_event_id="&($guild_scheduled_event_id.get)
    result = (await api.request(
        "GET",
        endpointInvites(code) & queryparams,
        auth = auth
    )).newInvite

proc getGuildMember*(api: RestApi,
        guild_id, user_id: string): Future[Member] {.async.} =
    ## Gets a guild member.
    result = (await api.request(
        "GET",
        endpointGuildMembers(guild_id, user_id)
    )).newMember

proc getGuildMembers*(api: RestApi, guild_id: string;
        limit: range[1..1000] = 1, after = "0"): Future[seq[Member]] {.async.} =
    ## Gets a list of a guild's members.
    result = ((await api.request(
        "GET",
        endpointGuildMembers(guild_id) & "?limit=" & $limit & "&after=" & after
    ))).elems.map(newMember)

proc editCurrentMember*(api: RestApi, guild_id: string;
        nick = none string; reason = "") {.async.} =
    ## Modify current member.
    ## `nick` - some "" to reset nick.
    let payload = newJObject()
    payload.loadNullableOptStr(nick)
    discard await api.request(
        "PATCH",
        endpointGuildMembers(guild_id, "@me"),
        $payload,
        audit_reason = reason
    )

proc setGuildNick*(api: RestApi, guild_id: string;
        nick, reason = "") {.async.} =
    ## Sets the current user's guild nickname, defaults to "" if no nick is set.
    await api.editCurrentMember(guild_id, nick = some nick, reason)

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

proc getCurrentGuildMember*(api: RestApi;
        guild_id: string): Future[Member] {.async.} =
    ## Get guild member as the current user aka you.
    result = (await api.request(
        "GET",
        endpointUserGuildMember(guild_id)
    )).newMember

proc createUserDm*(api: RestApi, user_id: string): Future[DMChannel]{.async.} =
    ## Create user dm.
    result = (await api.request("POST", endpointUserChannels(), $(%*{
        "recipient_id": user_id
    }))).newDMChannel

proc getCurrentUser*(api: RestApi): Future[User] {.async.} =
    ## Gets the current user.
    result = (await api.request("GET", endpointUsers())).newUser

proc getGatewayBot*(api: RestApi): Future[GatewayBot] {.async.} =
    ## Get gateway bot with authentication.
    result = (await api.request("GET", "gateway/bot")).`$`.fromJson(GatewayBot)

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

proc getCurrentApplication*(api: RestApi): Future[Application] {.async.} =
    ## Gets the current application for the current user (bot user).
    result = (await api.request(
        "GET",
        endpointOAuth2Application()
    )).newApplication

proc registerApplicationCommand*(api: RestApi; application_id: string;
        name, description: string;
        name_localizations,description_localizations=none Table[string,string];
        kind = atSlash; guild_id = ""; dm_permission = true;
        default_member_permissions = none PermissionFlags;
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
    assert name.len >= 3 and name.len <= 32
    var payload = %*{"name": name,
                     "dm_permission": dm_permission,
                     "type": ord kind}

    if default_member_permissions.isSome:
        payload["default_member_permissions"] = %(
            $cast[int](default_member_permissions.get)
        )

    payload.loadOpt(name_localizations, description_localizations)
    if kind notin {atUser, atMessage}:
        assert description.len >= 1 and description.len <= 100
        payload["description"] = %description
    else:
        assert description == "", "Context menu commands cannot have description"

    if options.len > 0: payload["options"] = %options.mapIt(%%*it)
    var endpoint = endpointGlobalCommands(application_id)
    if guild_id != "":
        endpoint = endpointGuildCommands(application_id, guild_id)

    result = (await api.request(
        "POST",
        endpoint,
        $payload
    )).newApplicationCommand

proc getApplicationCommands*(
        api: RestApi, application_id: string; guild_id = "";
        with_localizations = false
): Future[seq[ApplicationCommand]] {.async.} =
    ## Get slash commands for a specific application, `guild_id` is optional.
    var endpoint = endpointGlobalCommands(application_id)
    if guild_id != "":
        endpoint = endpointGuildCommands(application_id, guild_id)

    result = (await api.request("GET",
        endpoint&"?with_localizations="&($with_localizations)
    )).elems.map(newApplicationCommand)

proc getApplicationCommand*(
        api: RestApi, application_id: string; guild_id = "",
        command_id: string
): Future[ApplicationCommand] {.async.} =
    ## Get slash command for a specific application, `guild_id` is optional.
    var endpoint = endpointGlobalCommands(application_id, command_id)
    if guild_id != "":
        endpoint = endpointGuildCommands(application_id, guild_id, command_id)

    result = (await api.request(
        "GET",
        endpoint
    )).newApplicationCommand

proc bulkOverwriteApplicationCommands*(api: RestApi;
        application_id: string;
        commands: seq[ApplicationCommand];
        guild_id = ""
): Future[seq[ApplicationCommand]] {.async.} =
    ## Overwrites existing commands slash command that were registered in guild or application.
    ## This means that only the commands you send in this request will be available globally or in a specific guild
    ## - `guild_id` is optional.
    let payload = %(commands.map(`%%*`))
    var endpoint = endpointGlobalCommands(application_id)
    if guild_id != "":
        endpoint = endpointGuildCommands(application_id, guild_id)

    result = (await api.request(
        "PUT",
        endpoint,
        $payload
    )).elems.map(newApplicationCommand)

proc editApplicationCommand*(api: RestApi; application_id, command_id: string;
        guild_id, name, description = "";
        name_localizations,description_localizations = none Table[string,string];
        default_member_permissions = none PermissionFlags;
        options: seq[ApplicationCommandOption] = @[]
): Future[ApplicationCommand] {.async.} =
    ## Modify slash command for a specific application.
    ##
    ## - `guild_id` - Optional
    ## - `name` - Optional Character length (3 - 32)
    ## - `descripton` - Optional Character length (1 - 100)
    var payload = %*{}
    var endpoint = endpointGlobalCommands(application_id, command_id)

    if guild_id != "":
        endpoint = endpointGuildCommands(application_id, guild_id, command_id)
    if name != "":
        assert name.len in 3..32
        payload["name"] = %name
    if description != "":
        assert description.len in 1..100
        payload["description"] = %description
    if options.len > 0: payload["options"] = %(options.map(`%%*`))

    payload.loadOpt(name_localizations, description_localizations)

    if default_member_permissions.isSome:
        payload["default_member_permissions"] = %(
            $cast[int](default_member_permissions.get)
        )

    result = (await api.request(
        "PATCH",
        endpoint,
        $payload
    )).newApplicationCommand

proc deleteApplicationCommand*(
        api: RestApi, application_id, command_id: string;
        guild_id = "") {.async.} =
    ## Delete slash command for a specific application, `guild_id` is optional.
    var endpoint = endpointGlobalCommands(application_id, command_id)
    if guild_id != "":
        endpoint = endpointGuildCommands(application_id, guild_id, command_id)
    discard await api.request(
        "DELETE",
        endpoint
    )

proc `%`(o: set[UserFlags]): JsonNode =
    %cast[int](o)

proc createInteractionResponse*(api: RestApi,
        interaction_id, interaction_token: string;
        response: InteractionResponse) {.async.} =
    ## Create an interaction response.
    ## `response.kind` is required.
    var data = newJObject()
    case response.kind:
    of irtPong,
       irtChannelMessageWithSource,
       irtDeferredChannelMessageWithSource,
       irtDeferredUpdateMessage,
       irtUpdateMessage:
        if response.data.isSome:
            data = %*(response.data.get)
            if response.data.get.flags.len!=0:
                data["flags"] = %response.data.get.flags
    of irtAutoCompleteResult:
        let choices = %response.choices.map(
            proc (x: ApplicationCommandOptionChoice): JsonNode =
                result = %*{"name": x.name}
                if x.value[0].isSome:
                    result["value"] = %x.value[0]
                if x.value[1].isSome:
                    result["value"] = %x.value[1]
        )
        data["choices"] = %*choices
    of irtInvalid:
        raise newException(ValueError, "Invalid interaction respons type")
    of irtModal:
        data["custom_id"] = %*response.custom_id
        data["title"] = %*response.title

        if response.components.len > 0:
            data["components"] = newJArray()
            for component in response.components:
                data["components"] &= %%*component

    discard await api.request(
        "POST",
        endpointInteractionsCallback(interaction_id, interaction_token),
        $(%*{
            "type": int response.kind,
            "data": %data
        })
    )

proc interactionResponseMessage*(api: RestApi,
        interaction_id, interaction_token: string;
        kind: InteractionResponseType,
        response: InteractionCallbackDataMessage) {.async.} =
    ## Create an interaction response.
    ## `response.kind` is required.
    var data = newJObject()
    case kind:
    of irtPong,
       irtChannelMessageWithSource,
       irtDeferredChannelMessageWithSource,
       irtDeferredUpdateMessage,
       irtUpdateMessage:
        data = %*(response)
        if response.flags.len!=0:
            data["flags"] = %response.flags
    else:
        raise newException(ValueError,
            "Invalid reponse kind for a message-based interaction response"
        )

    if response.attachments.len > 0:
        var mpd = newMultipartData()
        data["attachments"] = %[]
        for i, a in response.attachments:
            data["attachments"].add %a
            var
                contenttype = ""
                body = a.file
                name = "files[" & $i & "]"

            if a.filename == "":
                raise newException(
                    Exception,
                    "Attachment name needs to be provided."
                )

            let att = splitFile(a.filename)

            if att.ext != "":
                let ext = att.ext[1..high(att.ext)]
                contenttype = newMimetypes().getMimetype(ext)

            if body == "":
                body = readFile(a.filename)

            mpd.add(name, body, a.filename,
                contenttype, useStream = false)

        let pl = %*{
            "type": int kind,
            "data": %data
        }

        mpd.add("payload_json", $pl, contentType = "application/json")
        discard await api.request(
            "POST",
            endpointInteractionsCallback(interaction_id, interaction_token),
            $pl,
            mp = mpd
        )
        return 
    discard await api.request(
        "POST",
        endpointInteractionsCallback(interaction_id, interaction_token),
        $(%*{
            "type": int kind,
            "data": %data
        })
    )

proc interactionResponseAutocomplete*(api: RestApi,
        interaction_id, interaction_token: string;
        response: InteractionCallbackDataAutocomplete) {.async.} =
    ## Create an interaction response which is an autocomplete response.
    var data = newJObject()
    let choices = %response.choices.map(
        proc (x: ApplicationCommandOptionChoice): JsonNode =
            result = %*{"name": x.name}
            if x.value[0].isSome:
                result["value"] = %x.value[0]
            if x.value[1].isSome:
                result["value"] = %x.value[1]
    )
    data["choices"] = %*choices

    discard await api.request(
        "POST",
        endpointInteractionsCallback(interaction_id, interaction_token),
        $(%*{
            "type": int irtAutoCompleteResult,
            "data": %data
        })
    )

proc interactionResponseModal*(api: RestApi,
        interaction_id, interaction_token: string;
        response: InteractionCallbackDataModal) {.async.} =
    ## Create an interaction response which is a modal.
    var data = %*{
        "custom_id": response.custom_id,
        "title": response.title,
    }

    if response.components.len > 0:
        data["components"] = newJArray()
        for component in response.components:
            data["components"] &= %%*component

    discard await api.request(
        "POST",
        endpointInteractionsCallback(interaction_id, interaction_token),
        $(%*{
            "type": int irtModal,
            "data": %data
        })
    )
