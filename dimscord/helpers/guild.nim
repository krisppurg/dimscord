import asyncdispatch, options, json
import ../objects, ../constants

template beginPrune*(g: Guild;
        days: range[1..30] = 7;
        include_roles: seq[string] = @[];
        compute_prune_count = true): Future[void] =
    ## Begins a guild prune.
    getClient.api.beginGuildPrune(g.id, days, include_roles, compute_prune_count)

template getPruneCount*(g: Guild;
        days: int, include_roles: seq[string] = @[]): Future[int] =
    ## Gets the prune count.
    getClient.api.getGuildPruneCount(g.id, days, include_roles)

template editMFA*(g: Guild; lvl: MFALevel; reason = ""): Future[MFALevel] =
    ## Modify Guild MFA Level, requiring guild ownership.
    getClient.api.editGuildMFALevel(g.id, lvl, reason)

template delete*(g: Guild): Future[void] =
    ## Deletes a guild. Requires guild ownership.
    getClient.api.deleteGuild(g.id)

template edit*(g: Guild;
        name, description, region, afk_channel_id, icon = none string;
        discovery_splash, owner_id, splash, banner = none string;
        system_channel_id, rules_channel_id = none string;
        safety_alerts_channel_id = none string;
        preferred_locale, public_updates_channel_id = none string;
        verification_level, default_message_notifications = none int;
        system_channel_flags = none int;
        explicit_content_filter, afk_timeout = none int;
        features = none seq[string];
        premium_progress_bar_enabled = none bool;
        reason = ""
): Future[Guild] =
    ## Modifies a guild.
    ## Icon needs to be a base64 image.
    ## (See: https://nim-lang.org/docs/base64.html)
    ##
    ##
    ## Read more at:
    ## https://discord.com/developers/docs/resources/guild#modify-guild
    getClient.api.editGuild(g.id, name, description, region, afk_channel_id, icon,
        discovery_splash, owner_id, splash, banner,
        system_channel_id, rules_channel_id,
        safety_alerts_channel_id,
        preferred_locale, public_updates_channel_id,
        verification_level, default_message_notifications,
        system_channel_flags,
        explicit_content_filter, afk_timeout,
        features,
        premium_progress_bar_enabled,
        reason
    )

template getAuditLogs*(g: Guild;
        user_id, before = ""; action_type = -1;
        limit: range[1..100] = 50
): Future[AuditLog] =
    ## Get guild audit logs. The maximum limit is 100.
    getClient.api.getGuildAuditLogs(g.id, user_id, before, action_type, limit)

template createRole*(g: Guild,
        name: string = "new role";
        unicode_emoji, icon = none string;
        hoist, mentionable: bool = false;
        permissions: set[PermissionFlags] = {};
        role_colors = none RoleColors;
        color = 0; reason = ""): Future[Role] =
    ## Creates role.
    getClient.api.createGuildRole(g.id,
        name, unicode_emoji, icon,
        hoist, mentionable, permissions,
        role_colors, color, reason)

template deleteRole*(g: Guild; r: Role): Future[void] =
    ## Deletes a guild role.
    getClient.api.deleteGuildRole(g.id, r.id)

template editRole*(g: Guild; r: Role;
        name = none string;
        permissions = none set[PermissionFlags];
        icon, unicode_emoji = none string;
        colors = none RoleColors;
        color = none int;
        hoist, mentionable = none bool;
        reason = ""
): Future[Role] =
    ## Modifies a guild role.
    getClient.api.editGuildRole(g.id, r.id,
        name, permissions, icon, unicode_emoji,
        colors, color, hoist, mentionable)

template getInvites*(g: Guild): Future[seq[InviteMetadata]] =
    ## Gets guild invites.
    getClient.api.getGuildInvites(g.id)

template getVanity*(g: Guild): Future[tuple[code: Option[string]; uses: int]] =
    ## Get the guild vanity url. Requires the MANAGE_GUILD permission.
    ## `code` will be null if a vanity url for the guild is not set.
    getClient.api.getGuildVanityUrl(g.id)

template editMember*(g: Guild; m: Member;
        nick, channel_id, communication_disabled_until = none string;
        roles = none seq[string];
        mute, deaf = none bool;
        reason = ""
): Future[void] =
    ## Modifies a guild member
    ## Note:
    ## - `communication_disabled_until` - ISO8601 timestamp :: [<=28 days]
    getClient.api.editGuildMember(
        g.id, m.user.id, nick, channel_id, communication_disabled_until,
        roles, mute, deaf, reason
    )

template removeMember*(g: Guild; m: Member; reason = ""): Future[void] =
    ## Removes a guild member.
    getClient.api.removeGuildMember(g.id, m.user.id, reason)

template getBan*(g: Guild; m: Member | string): Future[GuildBan] =
    ## Gets guild ban.
    getClient.api.getGuildBan(g.id, (when m is Member: m.user.id else: m))

template getBans*(g: Guild): Future[seq[GuildBan]] =
    ## Gets all the guild bans.
    getClient.api.getGuildBans(g.id)

template ban*(g: Guild; m: Member; delete_message_secs = 0;
        reason = ""): Future[void] =
    ## Creates a guild ban.
    getClient.api.createGuildBan(g.id, m.user.id, delete_message_secs, reason)

template bulkBan*(g: Guild;
        user_ids: seq[string];
        delete_message_seconds = 0;
        reason = ""): Future[tuple[banned_users, failed_users: seq[string]]] =
    ## Creates a guild bulk ban.
    getClient.api.bulkGuildBan(g.id, user_ids, delete_message_seconds, reason)

template removeBan*(g: Guild; u: User | string; reason = ""): Future[void] =
    ## Removes a guild ban.
    getClient.api.removeGuildBan(g.id, (when u is User: u.id else: u), reason)

template getIntegrations*(g: Guild): Future[seq[Integration]] =
    ## Gets a list of guild integrations.
    getClient.api.getGuildIntegrations(g.id)

template getWebhooks*(g: Guild): Future[seq[Webhook]] =
    ## Gets a list of a channel's webhooks.
    getClient.api.getGuildWebhooks(g.id)

template deleteIntegration*(integ: Integration; reason = ""): Future[void] =
    ## Deletes a guild integration.
    getClient.api.deleteGuildIntegration(integ.id, reason)

template preview*(g: Guild): Future[GuildPreview] =
    ## Gets guild preview.
    getClient.api.getGuildPreview(g.id)

template searchMembers*(g: Guild; query = "";
        limit: range[1..1000] = 1): Future[seq[Member]] =
    ## Search for guild members.
    getClient.api.searchGuildMembers(g.id, query, limit)

template editEmoji*(g: Guild; e: Emoji; name = none string;
        roles = none seq[string];
        reason = ""
): Future[Emoji] =
    ## Modifies a guild emoji.
    assert e.id.isSome, "Cannot edit Emoji: the emoji might not be custom"
    getClient.api.editGuildEmoji(g.id, e.id.unsafeGet(), name, roles, reason)

template deleteEmoji*(g: Guild; e: Emoji; reason = ""): Future[void] =
    ## Deletes a guild emoji.
    assert e.id.isSome, "Cannot delete Emoji: the emoji might not be custom"
    getClient.api.deleteGuildEmoji(g.id, e.id.unsafeGet(), reason)

template getRegions*(g: Guild): Future[seq[VoiceRegion]] =
    ## Gets a guild's voice regions.
    getClient.api.getGuildVoiceRegions(g.id)

template editSticker*(g: Guild; s: Sticker;
        name, desc, tags = none string;
        reason = ""
): Future[Sticker] =
    ## Modify a guild sticker.
    getClient.api.editGuildSticker(g.id, s.id, name, desc, tags, reason)

template deleteSticker*(g: Guild; sk: Sticker; reason = ""): Future[Sticker] =
    ## Deletes a guild sticker.
    getClient.api.deleteGuildSticker(sk.guild_id.get, sk.id,
            reason) # TODO: assert sk.guild_id.isSome, "Cannot delete Sticker: the bot is probably not in the sticker's owning guild."

template getScheduledEvent*(g: Guild;
        event_id: string; with_user_count = false
): Future[GuildScheduledEvent] =
    ## Get a scheduled event in a guild.
    getClient.api.getScheduledEvent(g.id, event_id, with_user_count)

template getScheduledEvents*(g: Guild): Future[seq[GuildScheduledEvent]] =
    ## Get all scheduled events in a guild.
    getClient.api.getScheduledEvents(g.id)

template editEvent*(gse: GuildScheduledEvent;
        name, start_time, image = none string;
        channel_id, end_time, description = none string;
        privacy_level = none GuildScheduledEventPrivacyLevel;
        entity_type = none EntityType;
        entity_metadata = none EntityMetadata;
        status = none GuildScheduledEventStatus;
        recurrence_rule = none RecurrenceRule;
        reason = ""
): Future[GuildScheduledEvent] =
    ## Update a scheduled event in a guild.
    ## Read more: https://discord.com/developers/docs/resources/guild-scheduled-event#modify-guild-scheduled-event-json-params
    getClient.api.editScheduledEvent(
        gse.guild_id, gse.id, name,
        start_time, image, channel_id, end_time,
        description, privacy_level,
        entity_type, entity_metadata,
        status, recurrence_rule,
        reason,
    )

template delete*(gse: GuildScheduledEvent; reason = ""): Future[void] =
    ## Delete a scheduled event in guild.
    getClient.api.deleteScheduledEvent(gse.guild_id, gse.id, reason)

template getEventUsers*(gse: GuildScheduledEvent;
        limit = 100; with_member = false;
        before, after = ""
): Future[seq[GuildScheduledEventUser]] =
    ## Gets the users and/or members that were subscribed to the scheduled event.
    getClient.api.getScheduledEventUsers(
      gse.guild_id, gse.id, limit, with_member, before, after
    )

template getRules*(g: Guild): Future[seq[AutoModerationRule]] =
    ## Get a Guild's current AutoMod Rules
    getClient.api.getAutoModerationRules(g.id)

template getRule*(g: Guild; rule_id: string): Future[AutoModerationRule] =
    ## Get a Guild's specific AutoMod Rule
    getClient.api.getAutoModerationRule(g.id, rule_id)

template deleteRule*(g: Guild; amr: AutoModerationRule): Future[void] =
    ## deletes automod rule
    getClient.api.deleteAutoModerationRule(g.id, amr.id)

template editRule*(g: Guild; amr: AutoModerationRule;
    event_type = none int; name = none string;
    trigger_type = none ModerationTriggerType;
    trigger_metadata = none TriggerMetadata;
    actions = none seq[ModerationAction]; enabled = none bool;
    exempt_roles, exempt_channels = none seq[string];
    reason = "";
): Future[AutoModerationRule] =
    ## Edits an automod rule.
    ## `event_type` is gonna be 1 for SEND_MESSAGE
    getClient.api.editAutoModerationRule(
        g.id, amr.id, event_type,
        name, trigger_type,
        trigger_metadata, actions,
        enabled, exempt_roles, exempt_channels,
        reason
    )
