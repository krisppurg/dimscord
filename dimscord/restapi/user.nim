import asyncdispatch, json, options, httpclient
import ../objects, ../constants
import tables, sequtils, strutils
import requester

proc getInvite*(api: RestApi, code: string;
        with_counts, with_expiration = false;
        auth = false; guild_scheduled_event_id = none string;
): Future[Invite] {.async.} =
    ## Gets a discord invite, it can be a vanity code.
    ##
    ## - `auth` Whether you should get the invite while authenticated.
    var queryparams = "?with_counts="&($with_counts) &
        "&with_expiration="&($with_expiration)
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
    result.guild_id = guild_id

proc getGuildMembers*(api: RestApi, guild_id: string;
        limit: range[1..1000] = 1, after = "0"): Future[seq[Member]] {.async.} =
    ## Gets a list of a guild's members.
    result = ((await api.request(
        "GET",
        endpointGuildMembers(guild_id) & "?limit=" & $limit & "&after=" & after
    ))).elems.map(proc (x: JsonNode): Member =
                    x["guild_id"] = %*guild_id
                    x.newMember)

proc editCurrentMember*(api: RestApi, guild_id: string;
        nick = none string; reason = "") {.async.} =
    ## Modify current member.
    ## `nick` - some "" to reset nick.
    let payload = newJObject()
    payload.loadOpt(nick)
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
    result.guild_id=guild_id

proc getCurrentUserGuilds*(api: RestApi;
        before, after = none string; with_counts = false;
        limit: range[1..200] = 200): Future[seq[Guild]] {.async.} =
    ## Gets current user guilds.
    var endpoint = endpointUserGuilds()&"?limit="&($limit)
    if before.isSome:
        endpoint &= "&before=" & before.get
    if after.isSome:
        endpoint &= "&after=" & after.get

    result = (await api.request(
        "GET",
        endpoint&"&with_counts="&($with_counts)
    )).getElems.map newGuild

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

proc editCurrentApplication*(api: RestApi;
        custom_install_url, description, icon = none string;
        role_connections_verification_url = none string;
        install_params = none ApplicationInstallParams;
        flags = none set[PermissionFlags];
        cover_image, interactions_endpoint_url = none string;
        tags = none seq[string];
        integration_types_config = none Table[ApplicationIntegrationType,
            ApplicationIntegrationTypeConfig];
        ): Future[Application] {.async.} =
    ## Edits the current application for the current user (bot user).
    let payload = %*{}
    payload.loadOpt(custom_install_url, description, icon,
        role_connections_verification_url,
        install_params, cover_image, interactions_endpoint_url)

    if tags.isSome:
        payload["tags"] = %* some tags.get.mapIt(%*it)
    if integration_types_config.isSome:
        for k in integration_types_config.get.keys:
            payload["integration_types_config"][$(int k)]=
                %* integration_types_config.get[k]
    if flags.isSome:
        payload["flags"] = %*($cast[BiggestInt](get flags))

    result = (await api.request(
        "PATCH",
        endpointOAuth2Application(),
        $payload
    )).newApplication

proc registerApplicationCommand*(api: RestApi; application_id: string;
        name: string; description, guild_id = "";
        name_localizations,description_localizations=none Table[string,string];
        kind = atSlash; nsfw = false;
        default_member_permissions = none set[PermissionFlags];
        options: seq[ApplicationCommandOption] = @[];
        integration_types = none seq[ApplicationIntegrationType];
        contexts = none seq[InteractionContextType];
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
    softAssert name.len in 1..32
    var payload = %*{"name": name,
                     "type": %(ord kind)}

    if default_member_permissions.isSome:
        payload["default_member_permissions"] = %(
            $cast[int](default_member_permissions.get)
        )

    payload.loadOpt(name_localizations, description_localizations)

    if kind notin {atUser, atMessage}:
        softAssert description.len in 1..100
        payload["description"] = %description
    else:
        softAssert description == "", "Context menu commands cannot have description"

    if options.len > 0: payload["options"] = %options.mapIt(%%*it)

    if integration_types.isSome:
        payload["integration_types"] = %integration_types.get.mapit(%(ord it))
    if contexts.isSome:
        payload["contexts"] = %contexts.get.mapit(%(ord it))

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
        default_member_permissions = none set[PermissionFlags];
        nsfw = false;
        options: seq[ApplicationCommandOption] = @[];
        contexts = none seq[InteractionContextType];
        integration_types = none seq[ApplicationIntegrationType];
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
        softAssert name.len in 1..32
        payload["name"] = %name

    if description != "":
        softAssert description.len in 1..100
        payload["description"] = %description
    if options.len > 0: payload["options"] = %(options.map(`%%*`))

    payload.loadOpt(name_localizations, description_localizations)

    if integration_types.isSome:
        payload["integration_types"] = %integration_types.get.mapit(%(ord it))
    if contexts.isSome:
        payload["contexts"] = %contexts.get.mapit(%(ord it))

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

proc `%`*(o: set[UserFlags]): JsonNode =
    %cast[int](o)

proc interactionResponseMessage*(api: RestApi,
        interaction_id, interaction_token: string;
        kind: InteractionResponseType,
        response: InteractionCallbackDataMessage) {.async.} =
    ## Create an interaction response.
    ## - `response.kind` is required.
    ## 
    ## Example:
    ## ```nim
    ## await discord.api.interactionResponseMessage(
    ##      interaction_id, interaction_token,
    ##      kind = ..., # you can choose whichever
    ##      response = InteractionCallbackDataMessage(
    ##          flags: {mfIsEphemeral, mfIsComponentsV2},
    ##          content: "What's up bro",
    ##          components: @[...],
    ##          ...
    ##     )
    ## )
    ## ```
    var payload = %*{"type":int kind, "data": newJObject()}
    var mpd: MultipartData = nil
    if response != nil:
        case kind:
        of irtPong,
            irtChannelMessageWithSource,
            irtDeferredChannelMessageWithSource,
            irtDeferredUpdateMessage,
            irtUpdateMessage:
            payload["data"] = %*(response)
            if response.flags.len!=0:
                payload["data"]["flags"] = %response.flags
        else:
            raise newException(RequesterError,
                "Invalid reponse kind for a message-based interaction response"
            )

        if response.attachments.len > 0:
            mpd.append(response.attachments, payload, true)

    discard await api.request(
        "POST",
        endpointInteractionsCallback(interaction_id, interaction_token),
        $payload,
        mp = mpd
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

proc createInteractionResponse*(api: RestApi,
        interaction_id, interaction_token: string;
        response: InteractionResponse) {.async.} =
    ## Creates a generic interaction response.
    ## Can be used for anything related to interaction responses.
    ## `response.kind` is required.
    ## 
    ## Look at:
    ## * [interactionResponseMessage] for replies to interactions
    ## * [interactionResponseAutocomplete] for autocomplete
    ## * [interactionResponseModal] for modals
    ## * As well as the objects mentioned such as `InteractionResponse`.
    var data = newJObject()
    case response.kind:
    of irtPong,
       irtChannelMessageWithSource,
       irtDeferredChannelMessageWithSource,
       irtDeferredUpdateMessage,
       irtUpdateMessage:
        await api.interactionResponseMessage(
            interaction_id, interaction_token,
            response.kind, (if response.data.isSome:response.data.get else: nil)
        )
    of irtAutoCompleteResult:
        await api.interactionResponseAutocomplete(interaction_id,
            interaction_token,InteractionCallbackDataAutocomplete(
                choices: response.choices
            ))
    of irtInvalid:
        raise newException(ValueError, "Invalid interaction response type")
    of irtModal:
        await api.interactionResponseModal(interaction_id,
            interaction_token, InteractionCallbackDataModal(
                custom_id: response.custom_id,
                title: response.title,
                components: response.components
            ))

proc getApplicationRoleConnectionMetadataRecords*(
    api: RestApi; application_id: string
): Future[seq[ApplicationRoleConnectionMetadata]] {.async.} =
    result = (await api.request(
        "GET",
        endpointApplicationRoleConnectionMetadata(application_id)
    )).getElems.mapIt it.`$`.fromJson(ApplicationRoleConnectionMetadata)

proc updateApplicationRoleConnectionMetadataRecords*(
    api: RestApi; application_id: string
): Future[seq[ApplicationRoleConnectionMetadata]] {.async.} =
    result = (await api.request(
        "PUT",
        endpointApplicationRoleConnectionMetadata(application_id)
    )).getElems.mapIt it.`$`.fromJson(ApplicationRoleConnectionMetadata)

proc getUserApplicationRoleConnection*(
    api: RestApi; application_id: string
): Future[ApplicationRoleConnection] {.async.} =
    result = (await api.request(
        "GET",
        endpointUserApplicationRoleConnection(application_id)
    )).`$`.fromJson(ApplicationRoleConnection)

proc updateUserApplicationRoleConnection*(api: RestApi,
    application_id: string;
    platform_name, platform_username = none string;
    metadata = none Table[string, string]
): Future[ApplicationRoleConnection] {.async.} =
    var payload = %*{}
    payload.loadOpt(platform_name, platform_username)

    if metadata.isSome: payload["metadata"] = %metadata.get

    result = (await api.request(
        "PUT",
        endpointUserApplicationRoleConnection(application_id),
        $payload
    )).`$`.fromJson(ApplicationRoleConnection)

proc getEntitlements*(api: RestApi, application_id: string;
    user_id, before, after, guild_id = none string;
    sku_ids = none seq[string];
    limit: range[1..100] = 100;
    exclude_ended = false
): Future[seq[Entitlement]] {.async.} =
    ## Returns all entitlements for a given app, active and expired.
    var endpoint = endpointEntitlements(application_id) & "?limit=" & $limit

    if before.isSome: endpoint &= "&before="&before.get
    if after.isSome: endpoint &= "&after="&after.get
    if user_id.isSome: endpoint &= "&user_id="&user_id.get
    if guild_id.isSome: endpoint &= "&guild_id="&guild_id.get
    if sku_ids.isSome: endpoint &= "&sku_ids="&sku_ids.get.join(",")
    if exclude_ended: endpoint &= "&exclude_ended=" & $exclude_ended

    result = (await api.request(
        "GET",
        endpoint
    )).getElems.mapIt(it.`$`.fromJson(Entitlement))

proc consumeEntitlement*(api: RestApi,
    application_id, entitlement_id: string) {.async.} =
    ## For One-Time Purchase consumable SKUs, marks a given entitlement for the user as consumed.
    discard await api.request(
        "POST",
        endpointEntitlementConsume(application_id, entitlement_id)
    )

proc deleteEntitlement*(api: RestApi,
    application_id, entitlement_id: string) {.async.} =
    ## Deletes a currently-active test entitlement.
    ## Discord will act as though that user or guild no longer has entitlement to your premium offering.
    discard await api.request(
        "DELETE",
        endpointEntitlements(application_id, entitlement_id)
    )

proc createTestEntitlement*(api: RestApi,
    application_id: string;
    sku_id, owner_id: string; owner_type: range[1..2]) {.async.} =
    ## Creates a test entitlement to a given SKU for a given guild or user.
    ## Discord will act as though that user or guild has entitlement to your premium offering.
    ## * `owner_type` - `1` for a guild subscription, `2` for a user subscription.

    discard await api.request(
        "POST",
        endpointEntitlements(application_id),
        $(%*{
            "sku_id": sku_id,
            "owner_id": owner_id,
            "owner_type": owner_type
        })
    )

proc getApplicationEmojis*(api: RestApi,
        application_id: string): Future[seq[Emoji]] {.async.} =
    ## lists emojis made by a bot user application,
    result = (await api.request(
        "GET",
        endpointApplicationEmojis(application_id)
    ))["items"].getElems.map(newEmoji)

proc createApplicationEmoji*(api: RestApi;
        application_id: string,
        name, image: string): Future[Emoji] {.async.} =
    ## Creates an application emoji.
    result = (await api.request(
        "POST",
        endpointApplicationEmojis(application_id),
        $(%*{
            "name": name,
            "image": image
        })
    )).newEmoji

proc editApplicationEmoji*(api: RestApi;
        application_id: string,
        name: string): Future[Emoji] {.async.} =
    ## Edits an application emoji.
    result = (await api.request(
        "PATCH",
        endpointApplicationEmojis(application_id),
        $(%*{
            "name": name
        })
    )).newEmoji

proc deleteApplicationEmoji*(api: RestApi;
        application_id: string
): Future[Emoji] {.async.} =
    ## Deletes an application emoji.
    discard await api.request(
        "DELETE",
        endpointApplicationEmojis(application_id),
    )

proc listSKUs*(api:RestApi, application_id:string): Future[seq[Sku]] {.async.} =
    ## Lists out SKUs for a given application.
    result = (await api.request(
        "GET",
        endpointListSkus(application_id)
    )).getElems.mapIt(it.`$`.fromJson(Sku))

proc listSkuSubscriptions*(api:RestApi, sku_id:string;
        before, after, user_id = none(string);
        limit = 50
        ): Future[seq[Subscription]] {.async.} =
    ## Lists out SKUs for a given application.
    var endpoint = endpointSkuSubscriptions(sku_id) & "?limit=" & $limit
    if before.isSome: endpoint &= "&before=" & before.get 
    if after.isSome: endpoint &= "&after=" & after.get 
    if user_id.isSome: endpoint &= "&user_id=" & user_id.get 
    result = (await api.request(
        "GET",
        endpoint
    )).getElems.mapIt(it.`$`.fromJson(Subscription))

proc getSkuSubscription*(api:RestApi;
        sku_id, subscription_id: string): Future[Subscription] {.async.} =
    ## Lists out SKUs for a given application.
    result = (await api.request(
        "GET",
        endpointSkuSubscriptions(sku_id, subscription_id)
    )).`$`.fromJson(Subscription)

proc defaultSoundboardSounds*(api:RestApi): Future[seq[SoundboardSound]] {.async.} =
    result = (await api.request(
        "GET",
        "soundboard-default-sounds"
    )).`$`.fromJson(seq[SoundboardSound])