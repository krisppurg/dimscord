import asyncdispatch, options, json
import ../restapi/[requester]
import ../objects, ../constants

template beginPrune*(g: Guild;
        days: range[1..30] = 7;
        include_roles: seq[string] = @[];
        compute_prune_count = true): Future[void] =
    ## Begins a guild prune.
    getClient.api.beginGuildPrune(g.id, days, include_roles, compute_prune_count)

template getPruneCount*(g: Guild, days: int): Future[int] =
    ## Gets the prune count.
    getClient.api.getGuildPruneCount(g.id, days)

template edit*(g: Guild, lvl: MFALevel): Future[MFALevel] =
    ## Modify Guild MFA Level, requiring guild ownership.
    getClient.api.editGuildMFALevel(g.id, lvl)

template delete*(g: Guild): Future[void] =
    ## Deletes a guild. Requires guild ownership.
    getClient.api.deleteGuild(g.id)

template edit*(g: Guild;
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
): Future[Guild] =
    ## Modifies a guild.
    ## Icon needs to be a base64 image.
    ## (See: https://nim-lang.org/docs/base64.html)
    ## 
    ## 
    ## Read more at: 
    ## https://discord.com/developers/docs/resources/guild#modify-guild
    getClient.api.editGuild(    
        g.id, name, description, region, afk_channel_id, icon,
        discovery_splash, owner_id, splash, banner,
        system_channel_id, rules_channel_id,
        preferred_locale, public_updates_channel_id,
        verification_level, default_message_notifications,
        system_channel_flags,
        explicit_content_filter, afk_timeout,
        features, premium_progress_bar_enabled
    )

template getAuditLogs*(g: Guild; 
        user_id, before = "", action_type = -1;
        limit: range[1..100] = 50
): Future[AuditLog] =
    ## Get guild audit logs. The maximum limit is 100.
    getClient.api.getGuildAuditLogs(g.id, user_id, before, action_type, limit)

template deleteRole*(g: Guild, r: Role): Future[void] =
   ## Deletes a guild role.
   getClient.api.deleteGuildRole(g.id, r.id)

template editRole*(g: Guild, r: Role;
        name = none string;
        icon, unicode_emoji = none string;
        permissions = none PermObj; color = none int;
        hoist, mentionable = none bool;
        reason = ""
): Future[Role] =
    ## Modifies a guild role.
    getClient.api.editGuildRole(
        g.id, r.id,
        name, icon, unicode_emoji,
        permissions, color,
        hoist, mentionable,
        reason
    )

template getInvites*(g: Guild): Future[seq[InviteMetadata]] =
    ## Gets guild invites.
    getClient.api.getGuildInvites(g.id)

template getVanity*(g: Guild): Future[tuple[code: Option[string], uses: int]] =
    ## Get the guild vanity url. Requires the MANAGE_GUILD permission. 
    ## `code` will be null if a vanity url for the guild is not set.
    getClient.api.getGuildVanityUrl(g.id)

template editMember*(g: Guild, m: Member;
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

template removeMember*(g: Guild, m: Member, reason = ""): Future[void] =
    ## Removes a guild member.
    getClient.api.removeGuildMember(g.id, m.user.id, reason)

template getBan*(g: Guild, user_id: string): Future[GuildBan] =
    ## Gets guild ban.
    getClient.api.getGuildBan(g.id, mb.user.id)

template getBans*(g: Guild): Future[seq[GuildBan]] =
    ## Gets all the guild bans.
    getClient.api.getGuildBans(g.id)

template ban*(g: Guild, m: Member, deletemsgdays: range[0..7] = 0;
        reason = ""): Future[void] =
    ## Creates a guild ban.
    getClient.api.createGuildBan(g.id, m.user.id, deletemsgdays, reason)

template removeBan*(g: Guild, mb: Member, reason = ""): Future[void] =
    ## Removes a guild ban.
    getClient.api.removeGuildBan(mb.guild_id, mb.user.id, reason)

template getIntegrations*(g: Guild): Future[seq[Integration]] =
    ## Gets a list of guild integrations.
    getClient.api.getGuildIntegrations(g.id)

template getWebhooks*(g: Guild): Future[seq[Webhook]] =
    ## Gets a list of a channel's webhooks.
    getClient.api.getGuildWebhooks(g.id)

template deleteIntegration*(integ: Integration, reason = ""): Future[void] =
    ## Deletes a guild integration.
    getClient.api.deleteGuildIntegration(integ.id, reason)

template preview*(g: Guild): Future[GuildPreview] =
    ## Gets guild preview.
    getClient.api.getGuildPreview(g.id)

template searchMembers*(g: Guild, query = "";
        limit: range[1..1000] = 1): Future[seq[Member]] =
    ## Search for guild members.
    getClient.api.searchGuildMembers(g.id, query, limit)

template editEmoji*(g: Guild, e: Emoji, name = none string;
        roles = none seq[string];
        reason = ""
): Future[Emoji] =
    ## Modifies a guild emoji.
    getClient.api.editGuildEmoji(g.id, e.id, name, roles, reason)

template deleteEmoji*(g: Guild, e: Emoji, reason = ""): Future[void] =
    ## Deletes a guild emoji.
    getClient.api.deleteGuildEmoji(g.id, e.id, reason)

template getRegions*(g: Guild): Future[seq[VoiceRegion]] =
    ## Gets a guild's voice regions.
    getClient.api.getGuildVoiceRegions(g.id)

template editSticker*(g: Guild, s: Sticker;
        name, desc, tags = none string;
        reason = ""
): Future[Sticker] =
    ## Modify a guild sticker.
    getClient.api.editGuildSticker(g.id, s.id, name, desc, tags, reason)

template deleteSticker*(g: Guild, sk: Sticker, reason = ""): Future[Sticker] =
    ## Deletes a guild sticker.
    getClient.api.deleteGuildSticker(sk.guild_id.get, sk.id, reason)

template getScheduledEvent*(g: Guild;
        event_id: string, with_user_count = false
): Future[GuildScheduledEvent] =
    ## Get a scheduled event in a guild.
    getClient.api.getScheduledEvent(g.id, event_id, with_user_count)

template getScheduledEvents*(g: Guild): Future[seq[GuildScheduledEvent]] =
    ## Get all scheduled events in a guild.
    getClient.api.getScheduledEvents(g.id)

template edit*(gse: GuildScheduledEvent;
        name, start_time, image = none string;
        channel_id, end_time, desc = none string;
        privacy_level = none GuildScheduledEventPrivacyLevel;
        entity_type = none EntityType;
        entity_metadata = none EntityMetadata;
        status = none GuildScheduledEventStatus;
        reason = ""
): Future[GuildScheduledEvent] =
    ## Update a scheduled event in a guild.
    ## Read more: https://discord.com/developers/docs/resources/guild-scheduled-event#modify-guild-scheduled-event-json-params
    getClient.api.editScheduledEvent(
        gse.guild_id, gse.id, name,
        start_time, image,
        channel_id, end_time, desc,
        privacy_level, entity_type,
        entity_metadata, status,
        reason
    )

template delete*(gse: GuildScheduledEvent, reason = ""): Future[void] =
   ## Delete a scheduled event in guild.
   getClient.api.deleteScheduledEvent(gse.guild_id, gse.id, reason)

template getEventUsers*(gse: GuildScheduledEvent;
        limit = 100, with_member = false;
        before, after = ""
): Future[seq[GuildScheduledEventUser]] =
    ## Gets the users and/or members that were subscribed to the scheduled event.
    getClient.api.getScheduledEventUsers(
        gse.guild_id, gse.id,
        limit, with_member, before, after
    )

template getRules*(g: Guild): Future[seq[AutoModerationRule]] =
    ## Get a Guild's current AutoMod Rules
    getClient.api.getAutoModerationRules(g.id)

template getRule*(g: Guild, rule_id: string): Future[AutoModerationRule] =
    ## Get a Guild's specific AutoMod Rule
    getClient.api.getAutoModerationRule(g.id, rule_id)

template deleteRule*(amr: AutoModerationRule): Future[void] =
    ## deletes automod rule
    getClient.api.deleteAutoModerationRule(amr.guild_id, amr.id)

template editRule*(g: Guild, amr: AutoModerationRule;
    event_type = none int, name = none string; 
    trigger_type = none ModerationTriggerType;
    trigger_metadata = none tuple[
        keyword_filter: seq[string],
        presets: seq[int]
    ];
    actions = none seq[ModerationAction]; enabled = none bool;
    exempt_roles, exempt_channels = none seq[string];
    reason = ""
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