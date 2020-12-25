import asyncdispatch, json, options
import ../objects, ../constants, ../helpers
import sequtils, strutils
import requester

proc beginGuildPrune*(api: RestApi, guild_id: string;
        days = 7;
        compute_prune_count = true;
        reason = "") {.async.} =
    ## Begins a guild prune.
    let url = endpointGuildPrune(guild_id) & "?days=" & $days &
        "&compute_prune_count=" & $compute_prune_count
    discard await api.request("POST", url, audit_reason = reason)

proc getGuildPruneCount*(api: RestApi, guild_id: string,
        days: int): Future[int] {.async.} =
    ## Gets the prune count.
    result = (await api.request(
        "GET",
        endpointGuildPrune(guild_id) & "?days=" & $days
    ))["pruned"].getInt

proc deleteGuild*(api: RestApi, guild_id: string) {.async.} =
    ## Deletes a guild.
    discard await api.request("DELETE", endpointGuilds(guild_id))

proc editGuild*(api: RestApi, guild_id: string;
        name, region, afk_channel_id, icon = none string;
        discovery_splash, owner_id, splash, banner = none string;
        system_channel_id, rules_channel_id = none string;
        preferred_locale, public_updates_channel_id = none string;
        verification_level, default_message_notifications = none int;
        explicit_content_filter, afk_timeout = none int;
        reason = ""): Future[Guild] {.async.} =
    ## Edits a guild.
    ## Icon needs to be a base64 image.
    ## (See: https://nim-lang.org/docs/base64.html)

    let payload = newJObject()

    payload.loadOpt(name, region, verification_level, afk_timeout,
        default_message_notifications, icon, explicit_content_filter,
        afk_channel_id, discovery_splash, owner_id, splash, banner,
        system_channel_id, rules_channel_id, public_updates_channel_id,
        preferred_locale)

    payload.loadNullableOptInt(verification_level,
        default_message_notifications,
        explicit_content_filter, afk_timeout)

    payload.loadNullableOptStr(icon, region, splash, discovery_splash, banner,
        system_channel_id, rules_channel_id, public_updates_channel_id,
        preferred_locale)

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
        roles = none seq[Role];
        channels = none seq[Channel]): Future[Guild] {.async.} =
    ## Create a guild.
    ## Please read these notes: https://discord.com/developers/docs/resources/guild#create-guild
    let payload = newJObject()

    payload.loadOpt(name, region, verification_level, afk_timeout,
        default_message_notifications, icon, explicit_content_filter,
        afk_channel_id, system_channel_id, roles, channels)

    payload.loadNullableOptInt(verification_level,
        default_message_notifications,
        explicit_content_filter, afk_timeout)

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
        for r, i in roles.get:
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
        limit = 50): Future[AuditLog] {.async.} =
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
    ## Gets a guild's roles.
    result = (await api.request(
        "GET",
        endpointGuildRoles(guild_id)
    )).elems.map(newRole)

proc createGuildRole*(api: RestApi, guild_id: string;
        name = "new role";
        hoist, mentionable = false;
        permissions: PermObj;
        color = 0; reason = ""): Future[Role] {.async.} =
    ## Creates a guild role.
    result = (await api.request("PUT", endpointGuildRoles(guild_id), $(%*{
        "name": name,
        "permissions": %(permissions.perms),
        "color": color,
        "hoist": hoist,
        "mentionable": mentionable
    }), audit_reason = reason)).newRole

proc deleteGuildRole*(api: RestApi, guild_id, role_id: string) {.async.} =
    ## Deletes a guild role.
    discard await api.request("DELETE", endpointGuildRoles(guild_id, role_id))

proc editGuildRole*(api: RestApi, guild_id, role_id: string;
            name = none string;
            permissions = none PermObj; color = none int;
            hoist, mentionable = none bool;
            reason = ""): Future[Role] {.async.} =
    ## Modifies a guild role.
    let payload = newJObject()

    payload.loadOpt(name, color, hoist, mentionable)

    payload.loadNullableOptStr(name)
    payload.loadNullableOptInt(color)

    if permissions.isSome:
        payload["permissions"] = %(perms(get permissions))

    result = (await api.request(
        "PATCH",
        endpointGuildRoles(guild_id, role_id),
        $payload,
        audit_reason = reason
    )).newRole

proc editGuildRolePosition*(api: RestApi, guild_id, role_id: string;
        position = none int; reason = ""): Future[seq[Role]] {.async.} =
    ## Edits guild role position.
    result = (await api.request("PATCH", endpointGuildRoles(guild_id), $(%*{
        "id": role_id,
        "position": %position
    }), audit_reason = reason)).elems.map(newRole)

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
    )).to(tuple[code: Option[string], uses: int])

proc editGuildMember*(api: RestApi, guild_id, user_id: string;
        nick, channel_id = none string;
        roles = none seq[string];
        mute, deaf = none bool; reason = "") {.async.} =
    ## Modifies a guild member
    let payload = newJObject()

    payload.loadOpt(nick, roles, mute, deaf, channel_id)
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

proc createGuildBan*(api: RestApi, guild_id, user_id: string;
        deletemsgdays = 0; reason = "") {.async.} =
    ## Creates a guild ban.
    let payload = %*{
        "reason": reason
    }
    when defined(discordv8):
        payload["delete-message-days"] = %deletemsgdays

    discard await api.request(
        "PUT",
        endpointGuildBans(guild_id, user_id),
        $payload,
        audit_reason = reason
    )

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
    )).elems.map(
        proc (x: JsonNode): Integration =
            x.to(Integration)
    )

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
    )).to(GuildWidgetJson)

proc editGuildWidget*(api: RestApi, guild_id: string,
        enabled = none bool;
        channel_id = none string): Future[tuple[enabled: bool,
                                        channel_id: Option[string]]] {.async.} =
    ## Modifies a guild widget.
    let payload = newJObject()

    payload.loadOpt(enabled, channel_id)
    payload.loadNullableOptStr(channel_id)

    result = (await api.request(
        "PATCH",
        endpointGuildWidget(guild_id),
        $payload
    )).to(tuple[enabled: bool, channel_id: Option[string]])

proc getGuildPreview*(api: RestApi,
        guild_id: string): Future[GuildPreview] {.async.} =
    ## Gets guild preview.
    result = (await api.request(
        "GET",
        endpointGuildPreview(guild_id)
    )).to(GuildPreview)

proc addGuildMember*(api: RestApi, guild_id, user_id, access_token: string;
        nick = none string;
        roles = none seq[string];
        mute, deaf = none bool;
        reason = ""): Future[tuple[member: Member,
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
        result = (Member(), true)
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
    payload.loadNullableOptStr(name)

    if roles.isSome and roles.get.len < 0:
        payload["roles"] = newJNull()

    result = (await api.request("PATCH",
        endpointGuildEmojis(guild_id, emoji_id),
        $(%*{
            "name": name,
            "roles": roles
        }),
        audit_reason = reason
    )).newEmoji

proc deleteGuildEmoji*(api: RestApi, guild_id, emoji_id: string;
        reason = "") {.async.} =
    ## Deletes a guild emoji.
    discard await api.request("DELETE",
        endpointGuildEmojis(guild_id, emoji_id),
        audit_reason = reason
    )


proc getGuildVoiceRegions*(api: RestApi,
        guild_id: string): Future[seq[VoiceRegion]] {.async.} =
    ## Gets a guild's voice regions.
    result = (await api.request(
        "GET",
        endpointGuildRegions(guild_id)
    )).elems.map(
        proc (x: JsonNode): VoiceRegion =
            x.to(VoiceRegion)
    )

proc getVoiceRegions*(api: RestApi): Future[seq[VoiceRegion]] {.async.} =
    ## Get voice regions
    result = (await api.request(
        "GET",
        endpointVoiceRegions()
    )).elems.map(
        proc (x: JsonNode): VoiceRegion =
            x.to(VoiceRegion)
    )

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