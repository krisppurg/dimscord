import asyncdispatch, json, options
import ../objects, ../constants, ../helpers
import sequtils, strutils, jsony
import requester

proc beginGuildPrune*(api: RestApi, guild_id: string;
        days: range[1..30] = 7;
        include_roles: seq[string] = @[];
        compute_prune_count = true) {.async.} =
    ## Begins a guild prune.
    let payload = %*{
        "days": days,
        "compute_prune_count": compute_prune_count
    }
    if include_roles.len > 0:
        payload["include_roles"] = %include_roles

    discard await api.request(
        "POST",
        endpointGuildPrune(guild_id),
        $payload
    )

proc getGuildPruneCount*(api: RestApi, guild_id: string,
        days: int): Future[int] {.async.} =
    ## Gets the prune count.
    result = (await api.request(
        "GET",
        endpointGuildPrune(guild_id) & "?days=" & $days
    ))["pruned"].getInt

proc editGuildMFALevel*(api: RestApi;
        guild_id: string, level: MFALevel;
        reason = ""): Future[MFALevel] {.async.} =
    ## Modify Guild MFA Level, requiring guild ownership.
    result = MFALevel (await api.request(
        "POST",
        endpointGuildMFA(guild_id),
        $(%*{
            "level": %level
        }),
        reason
    )).getInt

proc deleteGuild*(api: RestApi, guild_id: string) {.async.} =
    ## Deletes a guild.
    discard await api.request("DELETE", endpointGuilds(guild_id))

proc editGuild*(api: RestApi, guild_id: string;
    name, description, region, afk_channel_id, icon = none string;
    discovery_splash, owner_id, splash, banner = none string;
    system_channel_id, rules_channel_id = none string;
    preferred_locale, public_updates_channel_id = none string;
    verification_level, default_message_notifications = none int;
    system_channel_flags = none int;
    explicit_content_filter, afk_timeout = none int;
    features: seq[string] = @[];
    premium_progress_bar_enabled = none bool;
    reason = ""
): Future[Guild] {.async.} =
    ## Modifies a guild.
    ## Icon needs to be a base64 image.
    ## (See: https://nim-lang.org/docs/base64.html)
    ## 
    ## 
    ## Read more at: 
    ## https://discord.com/developers/docs/resources/guild#modify-guild

    let payload = newJObject()

    payload.loadOpt(name, description, region, verification_level, afk_timeout,
        default_message_notifications, icon, explicit_content_filter,
        afk_channel_id, discovery_splash, owner_id, splash, banner,
        system_channel_id, rules_channel_id, public_updates_channel_id,
        preferred_locale, system_channel_flags, premium_progress_bar_enabled)

    payload.loadNullableOptInt(verification_level,
        default_message_notifications,
        explicit_content_filter, afk_timeout)

    payload.loadNullableOptStr(icon, description, region, splash,
        discovery_splash, banner, system_channel_id, rules_channel_id,
        public_updates_channel_id, preferred_locale)

    if features.len > 0:
        payload["features"] = %[]
        for f in features:
            payload["features"].add(%f)

    result = (await api.request(
        "PATCH",
        endpointGuilds(guild_id),
        $payload,
        audit_reason = reason
    )).newGuild

proc createGuild*(api: RestApi, name, region = none string;
        icon, afk_channel_id, system_channel_id = none string;
        verification_level, default_message_notifications = none int;
        afk_timeout, explicit_content_filter = none int;
        system_channel_flags = none int; roles = none seq[Role];
        channels = none seq[objects.Channel]): Future[Guild] {.async.} =
    ## Create a guild.
    ## Please read these notes:
    ## https://discord.com/developers/docs/resources/guild#create-guild
    let payload = newJObject()

    if roles.isSome:
        assert roles.get.len <= 250
    if channels.isSome:
        assert channels.get.len <= 500

    payload.loadOpt(name, region, verification_level, afk_timeout,
        default_message_notifications, icon, explicit_content_filter,
        afk_channel_id, system_channel_id)

    payload.loadNullableOptInt(verification_level,
        default_message_notifications,
        explicit_content_filter, afk_timeout,
        system_channel_flags
    )

    payload.loadNullableOptStr(icon, region, afk_channel_id, system_channel_id)

    if channels.isSome:
        payload["channels"] = %[]
        for c in channels.get:
            let channel = %*{
                "name": c.name,
                "type": c.kind
            }
            if c.kind == int ctGuildParent:
                channel["id"] = %c.id
                channel["parent_id"] = %c.parent_id

            payload["channels"].add(channel)

    if roles.isSome:
        payload["roles"] = %[]
        for r in roles.get:
            payload["roles"].add(%r)

    result = (await api.request(
        "POST",
        endpointGuilds(),
        $payload
    )).newGuild

proc getGuild*(api: RestApi, guild_id: string;
        with_counts = false): Future[Guild] {.async.} =
    ## Gets a guild.
    result = (await api.request(
        "GET",
        endpointGuilds(guild_id) & "?with_counts=" & $with_counts
    )).newGuild

proc getGuildAuditLogs*(api: RestApi, guild_id: string;
        user_id, before = "";
        action_type = -1;
        limit: range[1..100] = 50): Future[AuditLog] {.async.} =
    ## Get guild audit logs. The maximum limit is 100.
    var url = endpointGuildAuditLogs(guild_id) & "?"

    if user_id != "":
        url &= "user_id=" & user_id & "&"
    if before != "":
        url &= "before=" & before & "&"
    if action_type != -1:
        url &= "action_type=" & $action_type & "&"
    if limit <= 100:
        url &= "limit=" & $limit

    result = (await api.request("GET", url)).newAuditLog

proc getGuildRoles*(api: RestApi,
        guild_id: string): Future[seq[Role]] {.async.} =
    ## Gets the guild's roles.
    result = (await api.request(
        "GET",
        endpointGuildRoles(guild_id)
    )).elems.map(newRole)

proc createGuildRole*(api: RestApi, guild_id: string;
        name = "new role";
        unicode_emoji, icon = none string;
        hoist, mentionable = false;
        permissions: PermObj;
        color = 0; reason = ""): Future[Role] {.async.} =
    ## Creates a guild role.
    result = (await api.request("POST", endpointGuildRoles(guild_id), $(%*{
        "name": name, "unicode_emoji": unicode_emoji,
        "icon": icon, "permissions": %($perms(permissions)),
        "color": color, "hoist": hoist,
        "mentionable": mentionable
    }), audit_reason = reason)).newRole

proc deleteGuildRole*(api: RestApi, guild_id, role_id: string;
    reason = "") {.async.} =
    ## Deletes a guild role.
    discard await api.request(
        "DELETE",
        endpointGuildRoles(guild_id, role_id),
        audit_reason = reason
    )

proc editGuildRole*(api: RestApi, guild_id, role_id: string;
            name = none string;
            icon, unicode_emoji = none string;
            permissions = none PermObj; color = none int;
            hoist, mentionable = none bool;
            reason = ""): Future[Role] {.async.} =
    ## Modifies a guild role.
    let payload = newJObject()

    payload.loadOpt(name, color, hoist, mentionable)

    payload.loadNullableOptStr(name, icon, unicode_emoji)
    payload.loadNullableOptInt(color)

    if permissions.isSome:
        payload["permissions"] = %($perms(get permissions))

    result = (await api.request(
        "PATCH",
        endpointGuildRoles(guild_id, role_id),
        $payload,
        audit_reason = reason
    )).newRole

proc editGuildRolePositions*(api: RestApi, guild_id: string;
        positions: seq[tuple[id: string, position: Option[int]]];
        reason = ""): Future[seq[Role]] {.async.} =
    ## Edits guild role positions.
    var params = newJArray()
    for pos in positions:
        params.add(%*{"id": pos.id, "position": %pos.position})
    result = (await api.request(
        "PATCH",
        endpointGuildRoles(guild_id),
        $params,
        audit_reason = reason
    )).elems.map(newRole)

proc editGuildRolePosition*(api: RestApi, guild_id, role_id: string;
        position = none int; reason = ""): Future[seq[Role]] {.async.} =
    ## Edits guild role position.
    ## Same as editGuildRolePositions but for one role.
    result = (await api.request("PATCH", endpointGuildRoles(guild_id), $(%*[{
        "id": role_id,
        "position": %position
    }]), audit_reason = reason)).elems.map(newRole)

proc getGuildInvites*(api: RestApi,
        guild_id: string): Future[seq[InviteMetadata]] {.async.} =
    ## Gets guild invites.
    result = (await api.request(
        "GET",
        endpointGuildInvites(guild_id)
    )).elems.map(newInviteMetadata)

proc getGuildVanityUrl*(api: RestApi,
        guild_id: string): Future[tuple[code: Option[string],
                                        uses: int]] {.async.} =
    ## Gets the guild vanity url.
    result = (await api.request(
        "GET",
        endpointGuildVanity(guild_id)
    )).`$`.fromJson(tuple[code: Option[string], uses: int])

proc editGuildMember*(api: RestApi, guild_id, user_id: string;
        nick, channel_id, communication_disabled_until = none string;
        roles = none seq[string];
        mute, deaf = none bool;
        reason = "") {.async.} =
    ## Modifies a guild member
    ## Note:
    ## - `communication_disabled_until` - ISO8601 timestamp :: [<=28 days]
    let payload = newJObject()

    payload.loadOpt(nick, roles, mute, deaf,
        channel_id, communication_disabled_until)
    payload.loadNullableOptStr(channel_id)

    discard await api.request(
        "PATCH",
        endpointGuildMembers(guild_id, user_id),
        $payload,
        audit_reason = reason
    )

proc removeGuildMember*(api: RestApi, guild_id, user_id: string;
        reason = "") {.async.} =
    ## Removes a guild member.
    discard await api.request(
        "DELETE",
        endpointGuildMembers(guild_id, user_id),
        audit_reason = reason
    )

proc getGuildBan*(api: RestApi,
        guild_id, user_id: string): Future[GuildBan] {.async.} =
    ## Gets guild ban.
    result = (await api.request(
        "GET",
        endpointGuildBans(guild_id, user_id)
    )).newGuildBan

proc getGuildBans*(api: RestApi,
        guild_id: string): Future[seq[GuildBan]] {.async.} =
    ## Gets all the guild bans.
    result = (await api.request(
        "GET",
        endpointGuildBans(guild_id)
    )).elems.map(newGuildBan)

proc bulkGuildBan*(api: RestApi, guild_id: string;
        user_ids: seq[string];
        delete_message_seconds = 0;
        reason = ""
): Future[tuple[banned_users, failed_users: seq[string]]] {.async.} =
    ## Creates a guild ban.
    assert user_ids.len <= 200

    discard await api.request(
        "POST", endpointGuildBanBulk(guild_id),
        $(%*{
            "user_ids": %user_ids,
            "delete_message_seconds": delete_message_seconds
        }), audit_reason = reason)

proc createGuildBan*(api: RestApi, guild_id, user_id: string;
        deletemsgdays: range[0..7] = 0; reason = "") {.async.} =
    ## Creates a guild ban.
    discard await api.request(
        "PUT", endpointGuildBans(guild_id, user_id),
        $(%*{
            "delete_message_days": deletemsgdays,
            "reason": reason
        }), audit_reason = reason)

proc removeGuildBan*(api: RestApi,
        guild_id, user_id: string; reason = "") {.async.} =
    ## Removes a guild ban.
    discard await api.request(
        "DELETE",
        endpointGuildBans(guild_id, user_id),
        audit_reason = reason
    )

proc getGuildIntegrations*(api: RestApi,
        guild_id: string): Future[seq[Integration]] {.async.} =
    ## Gets a list of guild integrations.
    result = (await api.request(
        "GET",
        endpointGuildIntegrations(guild_id)
    )).elems.map(newIntegration)

proc getGuildWebhooks*(api: RestApi,
        guild_id: string): Future[seq[Webhook]] {.async.} =
    ## Gets a list of a channel's webhooks.
    result = (await api.request(
        "GET",
        endpointGuildWebhooks(guild_id)
    )).elems.map(newWebhook)

proc syncGuildIntegration*(api: RestApi, guild_id, integ_id: string) {.async.} =
    ## Syncs a guild integration.
    discard await api.request(
        "POST",
        endpointGuildIntegrationsSync(guild_id, integ_id)
    )

proc editGuildIntegration*(api: RestApi, guild_id, integ_id: string;
        expire_behavior, expire_grace_period = none int;
        enable_emoticons = none bool; reason = "") {.async.} =
    ## Edits a guild integration.
    let payload = newJObject()

    payload.loadOpt(expire_behavior, expire_grace_period, enable_emoticons)
    payload.loadNullableOptInt(expire_behavior, expire_grace_period)

    discard await api.request(
        "PATCH",
        endpointGuildIntegrationsSync(guild_id, integ_id),
        $payload,
        audit_reason = reason
    )

proc deleteGuildIntegration*(api: RestApi, integ_id: string;
        reason = "") {.async.} =
    ## Deletes a guild integration.
    discard await api.request(
        "DELETE",
        endpointGuildIntegrations(integ_id),
        audit_reason = reason
    )

proc getGuildWidget*(api: RestApi,
        guild_id: string): Future[GuildWidgetJson] {.async.} =
    ## Gets a guild widget.
    result = (await api.request(
        "GET",
        endpointGuildWidget(guild_id)
    )).`$`.fromJson(GuildWidgetJson)

proc editGuildWidget*(api: RestApi, guild_id: string,
        enabled = none bool;
        channel_id = none string;
        reason = ""): Future[tuple[enabled: bool,
                                    channel_id: Option[string]]] {.async.} =
    ## Modifies a guild widget.
    let payload = newJObject()

    payload.loadOpt(enabled, channel_id)
    payload.loadNullableOptStr(channel_id)

    result = (await api.request(
        "PATCH",
        endpointGuildWidget(guild_id),
        $payload,
        reason
    )).`$`.fromJson(tuple[enabled: bool, channel_id: Option[string]])

proc getGuildPreview*(api: RestApi,
        guild_id: string): Future[GuildPreview] {.async.} =
    ## Gets guild preview.
    result = (await api.request(
        "GET",
        endpointGuildPreview(guild_id)
    )).newGuildPreview

proc searchGuildMembers*(api: RestApi;
    guild_id, query: string;
    limit: range[1..1000] = 1): Future[seq[Member]] {.async.} =
    ## Search for guild members.
    result = (await api.request("GET",
        endpointGuildMembersSearch(guild_id)&"?query="&query&"&limit="&($limit),
    )).getElems.map(proc (x: JsonNode): Member =
                        x["guild_id"] = %*guild_id
                        x.newMember)

proc addGuildMember*(api: RestApi, guild_id, user_id, access_token: string;
        nick = none string;
        roles = none seq[string];
        mute, deaf = none bool;
        reason = ""):  Future[tuple[member: Member,
                                    exists: bool]] {.async.} =
    ## Adds a guild member.
    ## If member is in the guild, then exists will be true.
    let payload = %*{"access_token": access_token}

    payload.loadOpt(nick, roles, mute, deaf)

    let member = await api.request("PUT",
        endpointGuildMembers(guild_id, user_id),
        audit_reason = reason
    )

    if member.kind == JNull:
        result = (Member(user: User(id: user_id), guild_id: guild_id), true)
    else:
        result = (newMember(member), false)

proc createGuildEmoji*(api: RestApi,
        guild_id, name, image: string;
        roles: seq[string] = @[];
        reason = ""): Future[Emoji] {.async.} =
    ## Creates a guild emoji.
    ## The image needs to be a base64 string.
    ## (See: https://nim-lang.org/docs/base64.html)

    result = (await api.request("POST", endpointGuildEmojis(guild_id), $(%*{
        "name": name,
        "image": image,
        "roles": roles
    }), audit_reason = reason)).newEmoji

proc editGuildEmoji*(api: RestApi, guild_id, emoji_id: string;
        name = none string;
        roles = none seq[string];
        reason = ""): Future[Emoji] {.async.} =
    ## Modifies a guild emoji.
    let payload = newJObject()

    payload.loadOpt(name)

    if roles.isSome and roles.get.len == 0:
        payload["roles"] = newJNull()
    elif roles.isSome and roles.get.len > 0:
        payload["roles"] = %roles

    result = (await api.request("PATCH",
        endpointGuildEmojis(guild_id, emoji_id),
        $payload,
        audit_reason = reason
    )).newEmoji

proc deleteGuildEmoji*(api: RestApi, guild_id, emoji_id: string;
        reason = "") {.async.} =
    ## Deletes a guild emoji.
    discard await api.request("DELETE",
        endpointGuildEmojis(guild_id, emoji_id),
        audit_reason = reason
    )

proc getGuildEmojis*(
    api: RestApi, guild_id: string
): Future[seq[Emoji]] {.async.} =
    result = (await api.request("GET",
        endpointGuildEmojis(guild_id)
    )).elems.map(newEmoji)

proc getGuildEmoji*(
    api: RestApi, guild_id: string, emoji_id: string
): Future[Emoji] {.async.} =
    result = (await api.request("GET",
        endpointGuildEmojis(guild_id, emoji_id)
    )).newEmoji

proc getGuildVoiceRegions*(api: RestApi,
        guild_id: string): Future[seq[VoiceRegion]] {.async.} =
    ## Gets a guild's voice regions.
    result = (await api.request(
        "GET",
        endpointGuildRegions(guild_id)
    )).elems.mapIt(($it).fromJson(VoiceRegion))

proc getVoiceRegions*(api: RestApi): Future[seq[VoiceRegion]] {.async.} =
    ## Get voice regions
    result = (await api.request(
        "GET",
        endpointVoiceRegions()
    )).elems.mapIt(($it).fromJson(VoiceRegion))

proc createGuildFromTemplate*(api: RestApi;
        code: string): Future[Guild] {.async.} =
    ## Create a guild from a template, this endpoint is used for bots
    ## that are in >10 guilds
    result = (await api.request(
        "POST", endpointGuildTemplates(tid=code)
    )).newGuild

proc getGuildTemplate*(api: RestApi;
        code: string): Future[GuildTemplate] {.async.} =
    ## Get guild template from its code.
    result = (await api.request(
        "GET", endpointGuildTemplates(tid=code)
    )).newGuildTemplate

proc createGuildTemplate*(api: RestApi;
        guild_id, name: string;
        description = none string): Future[GuildTemplate] {.async.} =
    ## Create a guild template
    result = (await api.request(
        "POST", endpointGuildTemplates(gid=guild_id)
    )).newGuildTemplate

proc syncGuildTemplate*(api: RestApi;
        guild_id, code: string): Future[GuildTemplate] {.async.} =
    ## Sync guild template.
    result = (await api.request(
        "PUT", endpointGuildTemplates(gid=guild_id,tid=code)
    )).newGuildTemplate

proc editGuildTemplate*(api: RestApi;
        guild_id, code: string;
        name, description = none string): Future[GuildTemplate] {.async.} =
    ## Modify a guild template.
    let payload = newJObject()
    payload.loadNullableOptStr(description)
    if name.isSome: payload["name"] = %name
    result = (await api.request(
        "PATCH", endpointGuildTemplates(gid=guild_id,tid=code)
    )).newGuildTemplate

proc deleteGuildTemplate*(api: RestApi;
        guild_id, code: string): Future[GuildTemplate] {.async.} =
    ## Delete guild template.
    result = (await api.request(
        "DELETE", endpointGuildTemplates(gid=guild_id,tid=code)
    )).newGuildTemplate

proc editUserVoiceState*(api: RestApi,
    guild_id, user_id: string;
    channel_id, request_to_speak_timestamp = none string;
    suppress = none bool;
    reason = "") {.async.} =
    ## Modify user or current user voice state, read more at:
    ## https://discord.com/developers/docs/resources/guild#update-current-user-voice-state
    ## or 
    ## https://discord.com/developers/docs/resources/guild#update-user-voice-state-caveats
    ## - `user_id` You can set "@me", as the bot. 
    if user_id != "@me":
        assert request_to_speak_timestamp.isNone

    let payload = %*{"channel_id":channel_id}
    payload.loadNullableOptStr(channel_id, request_to_speak_timestamp)
    payload.loadOpt(suppress)

    discard await api.request(
        "PATCH", endpointGuildVoiceStatesUser(guild_id, user_id),
        $payload,
        reason
    )

proc editCurrentUserVoiceState*(api: RestApi;
    guild_id, channel_id: string;
    request_to_speak_timestamp = none string;
    suppress = none bool;
    reason = "") {.async.} =
    ## Modify current user voice state
    await api.editUserVoiceState(
        guild_id = guild_id, user_id = "@me",
        channel_id = some channel_id, suppress = suppress,
        request_to_speak_timestamp = request_to_speak_timestamp,
        reason = reason
    )

proc editGuildWelcomeScreen*(api: RestApi, guild_id: string;
    enabled = none bool;
    welcome_channels = none seq[WelcomeChannel];
    description = none string; reason = ""
): Future[tuple[
            description: Option[string],
            welcome_channels: seq[WelcomeChannel]
    ]] {.async.} =
    let payload = newJObject()
    payload.loadOpt(enabled)
    payload.loadNullableOptStr(description)

    if welcome_channels.isSome and welcome_channels.get.len == 0:
        payload["welcome_channels"] = newJNull()

    return (await api.request(
        "PATCH", endpointGuildWelcomeScreen(guild_id),
        $payload,
        reason
    )).`$`.fromJson(tuple[
            description: Option[string],
            welcome_channels: seq[WelcomeChannel]
        ])

proc getGuildWelcomeScreen*(
    api: RestApi, guild_id: string
): Future[tuple[
            description: Option[string],
            welcome_channels: seq[WelcomeChannel]
        ]] {.async.} =
    result = (await api.request(
        "GET", endpointGuildWelcomeScreen(guild_id)
    )).`$`.fromjson(tuple[
            description: Option[string],
            welcome_channels: seq[WelcomeChannel]
        ])

proc getGuildApplicationCommandsPermissions*(
    api: RestApi, application_id, guild_id: string
): Future[seq[GuildApplicationCommandPermissions]] {.async.} =
    ## Fetches command permissions for all commands for your application in a guild
    let endpoint = endpointGuildCommandPermission(application_id, guild_id)
    result = (await api.request("GET", endpoint))
                .getElems.map newGuildApplicationCommandPermissions

proc editGuildApplicationCommandPermissions*(
    api: RestApi, application_id, guild_id, command_id: string,
    permissions: seq[ApplicationCommandPermission]
): Future[GuildApplicationCommandPermissions] {.async.} =
    ## Edits command permissions for a specific command for your application in a guild.
    ## You can only add up to 10 permission overwrites for a command
    let endpoint = endpointGuildCommandPermission(
        application_id, guild_id, command_id
    )
    let payload = %* {"permissions": %*permissions}
    result = (await api.request(
        "PUT",
        endpoint,
        pl = $payload
    )).newGuildApplicationCommandPermissions

proc getGuildApplicationCommandPermissions*(
    api: RestApi, application_id, guild_id, command_id: string
): Future[GuildApplicationCommandPermissions] {.async.} =
    ## Fetches command permissions for a specific command for your application in a guild
    let endpoint = endpointGuildCommandPermission(
        application_id, guild_id, command_id
    )
    result = (await api.request("GET", endpoint))
        .newGuildApplicationCommandPermissions

proc bulkEditApplicationCommandPermissions*(
    api: RestApi, application_id, guild_id: string,
    permissions: seq[GuildApplicationCommandPermissions]
): Future[seq[GuildApplicationCommandPermissions]] {.async.} =
    ## Batch edits permissions for all commands in a guild
    ## You can only add up to 10 permission overwrites for a command.
    let endpoint = endpointGuildCommandPermission(application_id, guild_id)
    let payload = %*permissions
    result = (await api.request(
        "PUT",
        endpoint,
        pl = $payload
    )).getElems.map newGuildApplicationCommandPermissions

proc getGuildStickers*(
    api: RestApi, guild_id: string
): Future[seq[Sticker]] {.async.} =
    ## List guild stickers. 
    result = (await api.request(
        "GET",
        endpointGuildStickers(guild_id)
    )).elems.map(newSticker)

proc getGuildSticker*(
    api: RestApi, guild_id, sticker_id: string
): Future[Sticker] {.async.} =
    ## Gets a guild sticker.
    result = (await api.request(
        "GET",
        endpointGuildStickers(guild_id, sticker_id)
    )).newSticker

proc createGuildSticker*(api: RestApi, guild_id: string;
    name, tags, file: string;
    description, reason = ""
): Future[Sticker] {.async.} =
    ## Create a guild sticker. Max `file` size 512KB.
    assert file.len <= (512_000), "Max file size 512KB"
    assert name.len in 2..30 and tags.len in 2..200
    if description != "": assert description.len in 2..100

    let payload = %*{
        "name": name,
        "description": description,
        "tags": tags,
        "file": file
    }

    result = (await api.request(
        "POST",
        endpointGuildStickers(guild_id),
        $payload,
        reason
    )).newSticker

proc editGuildSticker*(api: RestApi, guild_id, sticker_id: string;
        name, description, tags = none string;
        reason = ""
): Future[Sticker] {.async.} =
    ## Modify a guild sticker.
    let payload = newJObject()
    if name.isSome:
        assert name.get.len in 2..30
    if tags.isSome:
        assert tags.get.len in 2..200
    if description.isSome:
        assert description.get.len in 2..100
    payload.loadNullableOptStr(name, description, tags)
    result = (await api.request(
        "PATCH",
        endpointGuildStickers(guild_id, sticker_id),
        $payload,
        reason
    )).newSticker

proc deleteGuildSticker*(
    api: RestApi, guild_id, sticker_id: string;
    reason = ""
): Future[Sticker] {.async.} =
    ## Deletes a guild sticker.
    result = (await api.request(
        "DELETE",
        endpointGuildStickers(guild_id, sticker_id),
        audit_reason = reason
    )).newSticker

proc listActiveGuildThreads*(
    api: RestApi,
    channel_id: string
): Future[tuple[
    threads: seq[GuildChannel],
    members: seq[ThreadMember]
]] {.async.} =
    ## Returns all active threads in the guild.
    let data = await api.request("GET",endpointGuildThreadsActive(channel_id))

    result = (
        threads: data["threads"].elems.map(newGuildChannel),
        members: data["members"].elems.mapIt(($it).fromJson(ThreadMember))
    )

proc getScheduledEvent*(api: RestApi;
        guild_id, event_id: string;
        with_user_count = false): Future[GuildScheduledEvent] {.async.} =
    ## Get a scheduled event in a guild.
    result = (await api.request(
        "GET",
        endpointGuildScheduledEvents(guild_id, event_id) &
        "?with_user_count="&($with_user_count)
    )).`$`.fromJson(GuildScheduledEvent)

proc getScheduledEvents*(api: RestApi;
        guild_id: string): Future[seq[GuildScheduledEvent]] {.async.} =
    ## Get all scheduled events in a guild.
    result = (await api.request(
        "GET",
        endpointGuildScheduledEvents(guild_id)
    )).elems.mapIt(it.`$`.fromJson(GuildScheduledEvent))

proc createScheduledEvent*(api: RestApi; guild_id: string;
        name, scheduled_start_time: string;
        channel_id, scheduled_end_time, description = none string;
        image = none string;
        privacy_level: GuildScheduledEventPrivacyLevel;
        entity_type: EntityType;
        entity_metadata = none EntityMetadata;
        recurrence_rule = none RecurrenceRule;
        reason = ""
): Future[GuildScheduledEvent] {.async.} =
    ## Create a scheduled event in a guild.
    assert name.len in 1..100
    if description.isSome: assert description.get.len in 1..1000
    let payload = %*{
       "name": name,
       "scheduled_start_time": scheduled_start_time,
       "entity_type": int entity_type,
       "privacy_level": int privacy_level
    }
    payload.loadOpt(channel_id, scheduled_end_time, description, image)

    if entity_metadata.isSome:
        assert get(entity_metadata).location.get.len in 1..100
        payload["entity_metadata"] = %*{
            "location": entity_metadata.get.location.get
        }
    if recurrence_rule.isSome:
        payload["recurrence_rule"] = %recurrence_rule.get
    
    result = (await api.request(
        "POST",
        endpointGuildScheduledEvents(guild_id),
        $payload,
        reason
    )).`$`.fromJson(GuildScheduledEvent)

proc editScheduledEvent*(api: RestApi; guild_id, event_id: string;
        name, scheduled_start_time, image = none string;
        channel_id, scheduled_end_time, description = none string;
        privacy_level = none GuildScheduledEventPrivacyLevel;
        entity_type = none EntityType;
        entity_metadata = none EntityMetadata;
        status = none GuildScheduledEventStatus;
        recurrence_rule = none RecurrenceRule;
        reason = ""
): Future[GuildScheduledEvent] {.async.} =
    ## Update a scheduled event in a guild.
    ## Read more: https://discord.com/developers/docs/resources/guild-scheduled-event#modify-guild-scheduled-event-json-params
    if name.isSome: assert name.get.len in 1..100
    if description.isSome: assert description.get.len in 1..1000

    let payload = newJObject()
    payload.loadNullableOptStr(channel_id, image)
    payload.loadOpt(scheduled_end_time, scheduled_start_time,
        description, entity_type, status, privacy_level, recurrence_rule)

    if entity_type.isSome and entity_type.get == etExternal:
        assert channel_id.get == ""
        assert entity_metadata.isSome and entity_metadata.get.location.isSome
        assert scheduled_end_time.isSome

    if entity_metadata.isSome:
        assert get(entity_metadata).location.get.len in 1..100
        payload["entity_metadata"] = %*{
            "location": entity_metadata.get.location.get
        }

    result = (await api.request(
        "PATCH",
        endpointGuildScheduledEvents(guild_id, event_id),
        $payload,
        audit_reason = reason
    )).`$`.fromJson(GuildScheduledEvent)

proc deleteScheduledEvent*(api: RestApi,
        guild_id, event_id: string;
        reason = "") {.async.} =
    ## Delete a scheduled event in guild.
    discard await api.request(
        "DELETE",
        endpointGuildScheduledEvents(guild_id, event_id),
        audit_reason = reason
    )

proc getScheduledEventUsers*(api: RestApi,
        guild_id, event_id: string;
        limit = 100; with_member = false;
        before, after = ""): Future[seq[GuildScheduledEventUser]] {.async.} =
    ## Gets the users that were subscribed to the scheduled events in the guild.
    var endpoint = endpointGuildScheduledEventUsers(guild_id, event_id) &
        "?limit="&($limit)&"&with_member="&($with_member)

    if before != "":
        endpoint &= "&before="&before
    if after != "":
        endpoint &= "&after="&after

    result = (await api.request(
        "GET",
        endpoint
    )).elems.mapIt(it.`$`.fromJson(GuildScheduledEventUser))

proc renameHook(v: var ModerationAction, fieldName: var string) {.used.} = # just putting that here because im cool and lazy
    if fieldName == "type":
        fieldName = "kind"

proc getAutoModerationRules*(api: RestApi;
    guild_id: string
): Future[seq[AutoModerationRule]] {.async.} =
    result = (await api.request(
        "GET",
        endpointGuildAutoModerationRules(guild_id)
    )).elems.mapIt(it.`$`.fromJson(AutoModerationRule))

proc getAutoModerationRule*(api: RestApi;
    guild_id, rule_id: string
): Future[AutoModerationRule] {.async.} =
    result = (await api.request(
        "GET",
        endpointGuildAutoModerationRules(guild_id, rule_id)
    )).`$`.fromJson(AutoModerationRule)

proc deleteAutoModerationRule*(api: RestApi;
    guild_id, rule_id: string;
    reason = ""
) {.async.} =
    discard await api.request(
        "DELETE",
        endpointGuildAutoModerationRules(guild_id, rule_id),
        audit_reason = reason
    )

proc createAutoModerationRule*(api: RestApi;
    guild_id, name: string; event_type: int;
    trigger_type: ModerationTriggerType;
    trigger_metadata = none TriggerMetadata;
    actions: seq[ModerationAction] = @[]; enabled = false;
    exempt_roles, exempt_channels: seq[string] = @[];
    reason = ""
): Future[AutoModerationRule] {.async.} =
    ## `event_type` is gonna be 1 for SEND_MESSAGE
    assert exempt_roles.len in 0..20
    assert exempt_channels.len in 0..50

    let payload = %*{
        "name": name,
        "event_type": event_type,
        "trigger_type": %*trigger_type,
        "enabled": enabled
    }
    payload.loadOpt(trigger_metadata)

    if actions.len > 0:
        payload["actions"] = %*actions
        for act in payload["actions"].getElems:
            act.delete("kind")
            act["type"] = %act.kind

    if exempt_roles.len > 0: payload["exempt_roles"] = %exempt_roles
    if exempt_channels.len > 0: payload["exempt_channels"] = %exempt_channels

    result = (await api.request(
        "POST", endpointGuildAutoModerationRules(guild_id),
        $payload, audit_reason = reason
    )).`$`.fromJson(AutoModerationRule)

proc editAutoModerationRule*(api: RestApi,
    guild_id, rule_id: string; event_type = none int;
    name = none string; trigger_type = none ModerationTriggerType;
    trigger_metadata = none TriggerMetadata;
    actions = none seq[ModerationAction]; enabled = none bool;
    exempt_roles, exempt_channels = none seq[string];
    reason = ""
): Future[AutoModerationRule] {.async.} =
    ## `event_type` is gonna be 1 for SEND_MESSAGE
    if exempt_roles.isSome: assert exempt_roles.get.len in 0..20
    if exempt_channels.isSome: assert exempt_channels.get.len in 0..50
    let payload = newJObject()

    payload.loadOpt(name, enabled, event_type, trigger_type, trigger_metadata)#

    if actions.isSome:
        payload["actions"] = %*actions.get
        for act in payload["actions"].getElems:
            act.delete("kind")
            act["type"] = %act.kind

    if exempt_roles.isSome: payload["exempt_roles"] = %exempt_roles.get
    if exempt_channels.isSome: payload["exempt_channels"] = %exempt_channels.get

    result = (await api.request(
        "PATCH", endpointGuildAutoModerationRules(guild_id, rule_id),
        $payload, audit_reason = reason
    )).`$`.fromJson(AutoModerationRule)

proc getGuildOnboarding*(api: RestApi;
        guild_id: string): Future[GuildOnboarding] {.async.} =
    ## Gets guild onboarding.
    result = (await api.request(
        "GET",
        endpointGuildOnboarding(guild_id)
    )).`$`.fromJson GuildOnboarding

proc editGuildOnboarding*(api: RestApi, guild_id: string;
        prompts = none seq[GuildOnboardingPrompt];
        default_channel_ids = none seq[string];
        enabled = none bool; mode = none GuildOnboardingMode;
        reason = ""): Future[GuildOnboarding] {.async.} =
    ## Modify guild onboarding.
    let payload = newJObject()
    payload.loadOpt(enabled, prompts, default_channel_ids)
    if mode.isSome: payload["mode"] = %*(int mode.get)

    result = (await api.request(
        "PATCH",
        endpointGuildOnboarding(guild_id),
        $payload,
        audit_reason = reason
    )).`$`.fromJson GuildOnboarding