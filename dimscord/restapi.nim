import httpclient, mimetypes, asyncdispatch, json, options, objects, constants
import tables, regex, times, os, sequtils, strutils, strformat
import uri, macros, random, misc
randomize()

type
    RestError* = object of CatchableError
    DiscordFile* = ref object
        ## A Discord file.
        name*, body*: string
    AllowedMentions* = object
        ## An object of allowed mentions.
        ## For parse: The values should be "roles", "users", "everyone"
        parse*, roles*, users*: seq[string]
var
    fatalErr = true
    ratelimited, global = false
    global_retry_after = 0.0
    invalid_requests, expiry = 0'i64

proc parseRoute(endpoint, meth: string): string =
    let majorParams = @["channels", "guilds", "webhooks"]
    let params = endpoint.findAndCaptureAll(re"([a-z-]+)")
    var route = endpoint.split("?", 2)[0]

    for param in params:
        if param in majorParams:
            if param == "webhooks":
                route = route.replace(
                    re"webhooks\/[0-9]{17,19}\/.*",
                    "webhooks/:id/:token"
                )

            route = route.replace(re"\/(?:[0-9]{17,19})", "/:id")
        elif param == "reactions":
            route = route.replace(re"reactions\/[^/]+", "reactions/:id")

    if route.endsWith("messages/:id") and meth == "DELETE":
        return meth & route

    result = route

proc delayRoutes(api: RestApi; global = false; route = "") {.async.} =
    var rl: tuple[retry_after: float, ratelimited: bool]

    if global:
        rl = (global_retry_after, ratelimited)
    elif route != "":
        rl = (api.endpoints[route].retry_after,
            api.endpoints[route].ratelimited)

    if rl.ratelimited:
        log "Delaying " & (if global: "all" else: "HTTP") &
            " requests in (" & $(int(rl.retry_after * 1000) + 250) &
            "ms) [" & (if global: "global" else: route) & "]"

        await sleepAsync int(rl.retry_after * 1000) + 250

        if not global:
            api.endpoints[route].ratelimited = false
        else:
            ratelimited = false

proc clean(errors: JsonNode, extra = ""): seq[string] =
    var ext = extra

    case errors.kind:
        of JArray:
            var err: seq[string] = @[]

            for e in errors.elems:
                err.add("\n    - " & ext & ": " & e["message"].str)
            result = result.concat(err)
        of JObject:
            for err in errors.pairs:
                return clean(err.val, (if ext == "":
                        err.key & "." & err.key else: ext & "." & err.key))
        else:
            discard

proc getErrorDetails(data: JsonNode): string =
    result = "[Discord Exception]:: " &
        data["message"].str & " (" & $data["code"].getInt & ")"

    if "errors" in data:
        result &= "\n" & clean(data["errors"]).join("\n")

proc request(api: RestApi, meth, endpoint: string;
            pl, reason = ""; mp: MultipartData = nil;
            auth = true): Future[JsonNode] {.async.} =
    if api.token == "Bot  ":
        raise newException(Exception, "The token you specified was empty.")
    let route = endpoint.parseRoute(meth)

    if route notin api.endpoints:
        api.endpoints.add(route, Ratelimit())

    var
        data: JsonNode
        error = ""

    let r = api.endpoints[route]
    while r.processing:
        if getTime().toUnix() >= expiry and expiry != 0: # if there is a hang up we do not want to wait forever.
            r.processing = false
            expiry = 0
        await sleepAsync 750

    proc doreq() {.async.} =
        if invalid_requests >= 1500:
            let msg = "You are sending too many invalid requests."
            raise newException(RestError, msg)

        if global:
            await api.delayRoutes(global)
        else:
            await api.delayRoutes(false, route)

        let
            client = newAsyncHttpClient(libAgent)
            url = restBase & "v" & $api.rest_ver & "/" & endpoint

        var resp: AsyncResponse

        if reason != "":
            client.headers["X-Audit-Log-Reason"] = encodeUrl(reason)
        if auth:
            client.headers["Authorization"] = api.token

        client.headers["Content-Type"] = "application/json"
        client.headers["Content-Length"] = $pl.len
        client.headers["X-RateLimit-Precision"] = "millisecond"

        log("Sending HTTP request", @[
            "method", meth,
            "endpoint", url,
            "payload_size", $pl.len,
            "reason", if reason != "": reason else: "\"\""
        ])

        try:
            if mp == nil:
                resp = (await client.request(url, meth, pl))
            else:
                resp = (await client.post(url, pl, mp))
        except:
            raise newException(Exception, getCurrentExceptionMsg())

        log("Got response.")

        let
            retry_header = resp.headers.getOrDefault(
                "X-RateLimit-Reset-After",
                @["1.000"].HttpHeaderValues).parseFloat
            status = resp.code.int
            fin = "[" & $status & "] "

        if retry_header > r.retry_after:
            r.retry_after = retry_header

        if status >= 200:
            if status >= 300:
                error = fin & "Unknown error."

                if status != 429: r.processing = false
                if status >= 400:
                    if resp.headers["content-type"] == "application/json":
                        expiry = getTime().toUnix() + (retry_header.int + 3)
                        data = (await resp.body).parseJson
                        expiry = 0

                    error = fin & "Bad request."
                    if status == 401:
                        error = fin & "Invalid authorization."
                        invalid_requests += 1
                    elif status == 403:
                        error = fin & "Missing permissions/access."
                        invalid_requests += 1
                    elif status == 404:
                        error = fin & "Not found."
                    elif status == 429:
                        fatalErr = false
                        ratelimited = true

                        invalid_requests += 1

                        error = fin & "You are being rate-limited."
                        if resp.headers.hasKey("Retry-After"): # ;-; no `in` support
                            await sleepAsync resp.headers["Retry-After"].parseInt

                        await doreq()

                    if "code" in data and "message" in data:
                        error &= "\n\n - " & data.getErrorDetails()
                if status >= 500:
                    error = fin & "Internal Server Error."
                    if status == 503:
                        error = fin & "Service Unavailable."
                    elif status == 504:
                        error = fin & "Gateway timed out."

                if fatalErr:
                    raise newException(RestError, error)
                else:
                    echo error

            if status < 300:
                if resp.headers["content-type"] == "application/json":
                    try:
                        log("Awaiting for body to be parsed")

                        expiry = getTime().toUnix() + (retry_header.int + 3)
                        data = (await resp.body).parseJson
                        expiry = 0
                    except:
                        raise newException(RestError, "An error occurred.")
                else:
                    data = nil

                if invalid_requests > 0: invalid_requests -= 250

        let headerLimited = resp.headers.getOrDefault(
            "X-RateLimit-Remaining",
            @["0"].HttpHeaderValues).toString == "0"

        if headerLimited:
            if resp.headers.hasKey("X-RateLimit-Global"):
                global = true
                ratelimited = true
                r.ratelimited = true

                await api.delayRoutes(global)
            else:
                r.ratelimited = true
                await api.delayRoutes(false, route)

        r.processing = false
    try:
        r.processing = true
        await doreq()
        log("Request has finished.")

        result = data
    except:
        var err = getCurrentExceptionMsg()

        if error != "":
            err = error

        if fatalErr:
            raise newException(RestError, err)

proc `%`(o: Overwrite): JsonNode =
    result = newJObject()
    result["id"] = %o.id
    result["type"] = %o.kind
    result["allow"] = %o.allow
    result["deny"] = %o.deny

proc sendMessage*(api: RestApi, channel_id: string;
            content = ""; tts = false; embed = none Embed;
            allowed_mentions = none AllowedMentions;
            nonce: tuple[ival: int, str: string] = (-1, "");
            files = none seq[DiscordFile]): Future[Message] {.async.} =
    ## Sends a discord message.
    ## * `nonce` This can be used for optimistic message sending
    let payload = %*{
        "content": content,
        "tts": tts
    }

    if embed.isSome:
        payload["embed"] = %get embed

    if allowed_mentions.isSome:
        payload["allowed_mentions"] = %get allowed_mentions

    if nonce.ival != -1:
        payload["nonce"] = %nonce.ival
    if nonce.str != "":
        payload["nonce"] = %nonce.str

    if files.isSome:
        var mpd = newMultipartData()
        for file in get files:
            var contenttype = ""
            if file.name == "":
                raise newException(Exception, "File name needs to be provided.")

            let fil = splitFile(file.name)

            if fil.ext != "":
                let ext = fil.ext[1..high(fil.ext)]
                contenttype = newMimetypes().getMimetype(ext)

            if file.body == "":
                file.body = readFile(file.name)

            mpd.add(fil.name, file.body, file.name,
                contenttype, useStream = false)

        mpd.add("payload_json", $payload, contentType = "application/json")
        return (await api.request(
            "POST",
            endpointChannelMessages(channel_id),
            $payload,
            mp = mpd
        )).newMessage

    result = (await api.request(
        "POST",
        endpointChannelMessages(channel_id),
        $payload
    )).newMessage

proc editMessage*(api: RestApi, channel_id, message_id: string;
        content = ""; tts = false; flags = none(int);
        embed = none Embed): Future[Message] {.async.} =
    ## Edits a discord message.
    let payload = %*{
        "content": content,
        "tts": tts,
        "flags": %flags,
        "embed": %embed
    }

    result = (await api.request(
        "PATCH",
        endpointChannelMessages(channel_id, message_id),
        $payload
    )).newMessage

proc deleteMessage*(api: RestApi, channel_id, message_id: string;
        reason = "") {.async.} =
    ## Deletes a discord message.
    discard await api.request(
        "DELETE",
        endpointChannelMessages(channel_id, message_id),
        reason
    )

proc getChannelMessages*(api: RestApi, channel_id: string;
        around, before, after = "";
        limit = 50): Future[seq[Message]] {.async.} =
    ## Gets channel messages.
    var url = endpointChannelMessages(channel_id) & "?"

    if before != "":
        url &= "before=" & before & "&"
    if after != "":
        url &= "after=" & after & "&"
    if around != "":
        url &= "around=" & around & "&"
    if limit > 0 and limit <= 100:
        url &= "limit=" & $limit

    result = (await api.request("GET", url)).elems.map(newMessage)

proc getChannelMessage*(api: RestApi, channel_id,
        message_id: string): Future[Message] {.async.} =
    ## Get a channel message.
    result = (await api.request(
        "GET",
        endpointChannelMessages(channel_id, message_id)
    )).newMessage

proc bulkDeleteMessages*(api: RestApi, channel_id: string;
        message_ids: seq[string]; reason = "") {.async.} =
    ## Bulk deletes messages.
    discard await api.request(
        "POST",
        endpointBulkDeleteMessages(channel_id),
        $(%*{
            "messages": message_ids
        }),
        reason
    )

proc addMessageReaction*(api: RestApi,
        channel_id, message_id, emoji: string) {.async.} =
    ## Adds a message reaction to a Discord message.
    ##
    ## The `emoji` param can be like 👀💩.
    ## For custom emojis, use 'likethis:123456789012345678'.

    var emj = emoji
    if emoji == decodeUrl(emoji):
        emj = encodeUrl(emoji)

    discard await api.request(
        "PUT",
        endpointReactions(channel_id, message_id, e=emj, uid="@me")
    )

proc deleteMessageReaction*(api: RestApi,
        channel_id, message_id, emoji: string;
        user_id = "@me") {.async.} =
    ## Deletes the user's or the bot's message reaction to a Discord message.
    var emj = emoji
    if emoji == decodeUrl(emoji):
        emj = encodeUrl(emoji)

    discard await api.request(
        "DELETE",
        endpointReactions(channel_id, message_id, e=emj, uid=user_id)
    )

proc deleteMessageReactionEmoji*(api: RestApi,
        channel_id, message_id, emoji: string) {.async.} =
    ## Deletes all the reactions for emoji.
    discard await api.request(
        "DELETE",
        endpointReactions(channel_id, message_id, emoji)
    )

proc getMessageReactions*(api: RestApi,
        channel_id, message_id, emoji: string;
        before, after = "";
        limit = 25): Future[seq[User]] {.async.} =
    ## Get all user message reactions on the emoji provided.
    var emj = emoji
    var url = endpointReactions(channel_id, message_id, e=emj, uid="@me") & "?"

    if emoji == decodeUrl(emoji):
        emj = encodeUrl(emoji)

    if before != "":
        url = url & "before=" & before & "&"
    if after != "":
        url = url & "after=" & after & "&"
    if limit > 0 and limit <= 100:
        url = url & "limit=" & $limit

    result = (await api.request(
        "GET",
        endpointReactions(channel_id, message_id, e = emj)
    )).elems.map(newUser)

proc deleteAllMessageReactions*(api: RestApi,
        channel_id, message_id: string) {.async.} =
    ## Remove all message reactions.
    discard await api.request(
        "DELETE",
        endpointReactions(channel_id, message_id)
    )

proc triggerTypingIndicator*(api: RestApi, channel_id: string) {.async.} =
    ## Starts typing in a specific Discord channel.
    discard await api.request("POST", endpointTriggerTyping(channel_id))

proc addChannelMessagePin*(api: RestApi,
        channel_id, message_id: string; reason = "") {.async.} =
    ## Add pinned message.
    discard await api.request(
        "PUT",
        endpointChannelPins(channel_id, message_id),
        reason
    )

proc deleteChannelMessagePin*(api: RestApi,
        channel_id, message_id: string; reason = "") {.async.} =
    ## Remove pinned message.
    discard await api.request(
        "DELETE",
        endpointChannelPins(channel_id, message_id),
        reason
    )

proc getChannelPins*(api: RestApi,
        channel_id: string): Future[seq[Message]] {.async.} =
    ## Get channel pins.
    result = (await api.request(
        "GET",
        endpointChannelPins(channel_id)
    )).elems.map(newMessage)

macro loadOpt(obj: typed, lits: varargs[untyped]): untyped =
    result = newStmtList()
    for lit in lits:
        let fieldName = lit.strVal
        result.add quote do:
            if `lit`.isSome:
                `obj`[`fieldName`] = %get(`lit`)

macro loadNullableOptStr(obj: typed, lits: varargs[untyped]): untyped =
    result = newStmtList()
    for lit in lits:
        let fieldName = lit.strVal
        result.add quote do:
            if `lit`.isSome and get(`lit`) == "":
                `obj`[`fieldName`] = newJNull()

macro loadNullableOptInt(obj: typed, lits: varargs[untyped]): untyped =
    result = newStmtList()
    for lit in lits:
        let fieldName = lit.strVal
        result.add quote do:
            if `lit`.isSome and get(`lit`) == -1:
                `obj`[`fieldName`] = newJNull()

proc editGuildChannel*(api: RestApi, channel_id: string;
            name, parent_id, topic = none string;
            rate_limit_per_user, bitrate = none int;
            position, user_limit = none int;
            permission_overwrites = none seq[Overwrite];
            nsfw = none bool; reason = ""): Future[GuildChannel] {.async.} =
    ## Modify a guild channel.
    let payload = newJObject()

    payload.loadOpt(name, position, topic, nsfw, rate_limit_per_user,
        bitrate, user_limit, permission_overwrites, parent_id)

    payload.loadNullableOptStr(topic, parent_id)
    payload.loadNullableOptInt(position, rate_limit_per_user, bitrate,
        user_limit)

    result = (await api.request(
        "PATCH",
        endpointChannels(channel_id),
        $payload,
        reason
    )).newGuildChannel

proc createGuildChannel*(api: RestApi, guild_id, name: string; kind = 0;
            parent_id, topic = none string; nsfw = none bool;
            rate_limit_per_user, bitrate, position, user_limit = none int;
            permission_overwrites = none seq[Overwrite];
            reason = ""): Future[GuildChannel] {.async.} =
    ## Creates a channel.
    let payload = %*{"name": name, "type": kind}

    payload.loadOpt(position, topic, nsfw, rate_limit_per_user,
                    bitrate, user_limit, parent_id, permission_overwrites)

    result = (await api.request(
        "POST",
        endpointGuildChannels(guild_id),
        $payload
    )).newGuildChannel

proc deleteChannel*(api: RestApi, channel_id: string; reason = "") {.async.} =
    ## Deletes or closes a channel.
    discard await api.request("DELETE", endpointChannels(channel_id), reason)

proc editGuildChannelPermissions*(api: RestApi,
        channel_id, perm_id, kind: string;
        perms: PermObj; reason = "") {.async.} =
    ## Modify the channel's permissions.
    ## The `kind` param needs to be either "member" or "role".
    let payload = %*{"type": kind}

    if perms.allowed.len > 0:
        payload["allow"] = %(cast[int](perms.allowed))
    if perms.denied.len > 0:
        payload["deny"] = %(cast[int](perms.denied))

    discard await api.request(
        "PUT",
        endpointChannelOverwrites(channel_id, perm_id),
        $payload,
        reason
    )

proc getInvite*(api: RestApi, code: string;
        with_counts, auth = false): Future[Invite] {.async.} =
    ## Get's a channel invite.
    ##
    ## The auth param is whether you should get the invite while authenticated.
    result = (await api.request(
        "GET",
        endpointInvites(code) & fmt"?with_counts={with_counts}",
        auth = auth
    )).newInvite

proc beginGuildPrune*(api: RestApi, guild_id: string;
        days = 7;
        compute_prune_count = true;
        reason = "") {.async.} =
    ## Begins a guild prune.
    let url = endpointGuildPrune(guild_id) & "?days=" & $days &
        "&compute_prune_count=" & $compute_prune_count
    discard await api.request("POST", url, reason)

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
        reason
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
            if c.kind == ctGuildParent:
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
        pobj: PermObj;
        color = 0; reason = ""): Future[Role] {.async.} =
    ## Creates a guild role.
    result = (await api.request("PUT", endpointGuildRoles(guild_id), $(%*{
        "name": name,
        "permissions": %(+pobj),
        "color": color,
        "hoist": hoist,
        "mentionable": mentionable
    }), reason)).newRole

proc deleteGuildRole*(api: RestApi, guild_id, role_id: string) {.async.} =
    ## Deletes a guild role.
    discard await api.request("DELETE", endpointGuildRoles(guild_id, role_id))

proc editGuildRole*(api: RestApi, guild_id, role_id: string;
            name = none string;
            pobj = none PermObj; color = none int;
            hoist, mentionable = none bool;
            reason = ""): Future[Role] {.async.} =
    ## Modifies a guild role.
    let payload = newJObject()

    payload.loadOpt(name, color, hoist, mentionable)

    payload.loadNullableOptStr(name)
    payload.loadNullableOptInt(color)

    if pobj.isSome:
        payload["permissions"] = %(+(get pobj))

    result = (await api.request(
        "PATCH",
        endpointGuildRoles(guild_id, role_id),
        $payload,
        reason
    )).newRole

proc editGuildRolePosition*(api: RestApi, guild_id, role_id: string;
        position = none int; reason = ""): Future[seq[Role]] {.async.} =
    ## Edits guild role position.
    result = (await api.request("PATCH", endpointGuildRoles(guild_id), $(%*{
        "id": role_id,
        "position": %position
    }), reason)).elems.map(newRole)

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

    discard await api.request("PATCH", endpointGuildMembers(guild_id, user_id),
        $payload, reason)

proc removeGuildMember*(api: RestApi, guild_id, user_id: string;
        reason = "") {.async.} =
    ## Removes a guild member.
    discard await api.request(
        "DELETE",
        endpointGuildMembers(guild_id, user_id),
        reason
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
    discard await api.request("PUT", endpointGuildBans(guild_id, user_id), $(%*{
        "delete-message-days": $deletemsgdays,
        "reason": reason
    }), reason)

proc removeGuildBan*(api: RestApi, guild_id, user_id: string; reason = "") {.async.} =
    ## Removes a guild ban.
    discard await api.request(
        "DELETE",
        endpointGuildBans(guild_id, user_id),
        reason
    )

proc getGuildChannels*(api: RestApi,
        guild_id: string): Future[seq[GuildChannel]] {.async.} =
    ## Gets a list of a guild's channels
    result = (await api.request(
        "GET",
        endpointGuildChannels(guild_id)
    )).elems.map(newGuildChannel)

proc editGuildChannelPositions*(api: RestApi, guild_id, channel_id: string;
        position = none int; reason = "") {.async.} =
    ## Edits a guild channel's position.
    discard await api.request(
        "PATCH",
        endpointGuildChannels(guild_id, channel_id),
        $(%*{
            "id": channel_id,
            "position": %position
        }),
        reason
    )

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

proc setGuildNick*(api: RestApi, guild_id: string; nick, reason = "") {.async.} =
    ## Sets the current user's guild nickname, defaults to "" if no nick is set.
    discard await api.request(
        "PATCH",
        endpointGuildMembersNick(guild_id, "@me"),
        $(%*{
            "nick": nick
        }),
        reason
    )

proc addGuildMemberRole*(api: RestApi, guild_id, user_id, role_id: string;
        reason = "") {.async.} =
    ## Assigns a member's role.
    discard await api.request(
        "PUT",
        endpointGuildMembersRole(guild_id, user_id, role_id),
        reason
    )

proc removeGuildMemberRole*(api: RestApi, guild_id, user_id, role_id: string;
        reason = "") {.async.} =
    ## Removes a member's role.
    discard await api.request(
        "DELETE",
        endpointGuildMembersRole(guild_id, user_id, role_id),
        reason
    )

proc createChannelInvite*(api: RestApi, channel_id: string;
    max_age = 86400,
    max_uses = 0,
    temp, unique = false,
    target_user = none string,
    target_user_type = none int; reason = ""): Future[Invite] {.async.} =
    ## Creates an instant invite.
    let payload = %*{
        "max_age": max_age,
        "max_uses": max_uses,
        "temp": temp,
        "unique": unique,
    }
    payload.loadOpt(target_user, target_user_type)

    result = (await api.request(
        "POST",
        endpointChannelInvites(channel_id),
        $payload,
        reason
    )).newInvite

proc deleteGuildChannelPermission*(api: RestApi, channel_id, overwrite: string;
        reason = "") {.async.} =
    ## Deletes a guild channel overwrite.
    discard await api.request(
        "DELETE",
        endpointChannelOverwrites(channel_id, overwrite),
        reason
    )

proc deleteInvite*(api: RestApi, code: string; reason = "") {.async.} =
    ## Deletes a guild invite.
    discard await api.request("DELETE", endpointInvites(code), reason)

proc getChannelInvites*(api: RestApi,
        channel_id: string): Future[seq[Invite]] {.async.} =
    ## Gets a list of a channel's invites.
    result = (await api.request(
        "GET",
        endpointChannelInvites(channel_id)
    )).elems.map(newInvite)

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

proc getChannelWebhooks*(api: RestApi,
        channel_id: string): Future[seq[Webhook]] {.async.} =
    ## Gets a list of a channel's webhooks.
    result = (await api.request(
        "GET",
        endpointChannelWebhooks(channel_id)
    )).elems.map(newWebhook)

proc getGuildWebhooks*(api: RestApi,
        guild_id: string): Future[seq[Webhook]] {.async.} =
    ## Gets a list of a channel's webhooks.
    result = (await api.request(
        "GET",
        endpointGuildWebhooks(guild_id)
    )).elems.map(newWebhook)

proc createWebhook*(api: RestApi, channel_id, username: string;
        avatar = none string; reason = ""): Future[Webhook] {.async.} =
    ## Creates a webhook.
    ## (webhook names cannot be: 'clyde', and they range 1-80)
    result = (await api.request(
        "POST",
        endpointChannelWebhooks(channel_id),
        $(%*{
            "username": username,
            "avatar": avatar
        }),
        reason
    )).newWebhook

proc executeWebhook*(api: RestApi, webhook_id, token: string; wait = true;
            content = ""; tts = false;
            file = none DiscordFile;
            embeds = none seq[Embed];
            allowed_mentions = none AllowedMentions;
            username, avatar_url = none string): Future[Message] {.async.} =
    ## Executes a webhook. If wait is false make sure to asyncCheck it.
    var url = endpointWebhookToken(webhook_id, token) & "?wait=" & $wait
    let payload = %*{
        "content": content,
        "tts": tts
    }

    payload.loadOpt(username, avatar_url, allowed_mentions)

    if embeds.isSome:
        payload["embeds"] = %embeds

    if file.isSome:
        var mpd = newMultipartData()
        var contenttype = ""
        let fileOpt = get file
        if fileOpt.name == "":
            raise newException(Exception, "File name needs to be provided.")

        let fil = splitFile(fileOpt.name)

        if fil.ext != "":
            let ext = fil.ext[1..high(fil.ext)]
            contenttype = newMimetypes().getMimetype(ext)

        if fileOpt.body == "":
            fileOpt.body = readFile(fileOpt.name)

        mpd.add(fil.name, fileOpt.body, fileOpt.name,
            contenttype, useStream = false)

        mpd.add("payload_json", $payload, contentType = "application/json")

        return (await api.request("POST", url, $payload, mp = mpd)).newMessage
    result = (await api.request("POST", url, $payload)).newMessage

proc executeSlackWebhook*(api: RestApi, webhook_id, token: string;
        wait = true): Future[Message] {.async.} =
    ## Executes a slack webhook.
    ## If wait is false make sure to asyncCheck it.
    result = (await api.request(
        "POST",
        endpointWebhookTokenSlack(webhook_id, token) & "?wait=" & $wait
    )).newMessage

proc executeGithubWebhook*(api: RestApi, webhook_id, token: string;
        wait = true): Future[Message] {.async.} =
    ## Executes a github webhook.
    ## If wait is false make sure to asyncCheck it.
    result = (await api.request(
        "POST",
        endpointWebhookTokenGithub(webhook_id, token) & "?wait=" & $wait
    )).newMessage

proc getWebhook*(api: RestApi, webhook_id: string): Future[Webhook] {.async.} =
    ## Gets a webhook.
    result = (await api.request("GET", endpointWebhooks(webhook_id))).newWebhook

proc deleteWebhook*(api: RestApi, webhook_id: string; reason = "") {.async.} =
    ## Deletes a webhook.
    discard await api.request(
        "DELETE",
        endpointWebhooks(webhook_id),
        reason
    )

proc editWebhook*(api: RestApi, webhook_id: string;
        name, avatar, channel_id = none string; reason = "") {.async.} =
    ## Modifies a webhook.
    let payload = newJObject()

    payload.loadOpt(name, avatar, channel_id)
    payload.loadNullableOptStr(avatar)

    discard await api.request("PATCH",
        endpointWebhooks(webhook_id),
        $payload,
        reason
    )

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
        reason
    )

proc deleteGuildIntegration*(api: RestApi, integ_id: string;
        reason = "") {.async.} =
    ## Deletes a guild integration.
    discard await api.request(
        "DELETE",
        endpointGuildIntegrations(integ_id),
        reason
    )

proc getGuildEmbed*(api: RestApi,
        guild_id: string): Future[tuple[enabled: bool,
                                        channel_id: Option[string]]] {.async.} =
    ## Gets a guild embed.
    result = (await api.request(
        "GET",
        endpointGuildEmbed(guild_id)
    )).to(tuple[enabled: bool, channel_id: Option[string]])

proc editGuildEmbed*(api: RestApi, guild_id: string,
        enabled = none bool;
        channel_id = none string): Future[tuple[enabled: bool,
                                        channel_id: Option[string]]] {.async.} =
    ## Modifies a guild embed.
    let payload = newJObject()

    payload.loadOpt(enabled, channel_id)
    payload.loadNullableOptStr(channel_id)

    result = (await api.request(
        "PATCH",
        endpointGuildEmbed(guild_id),
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
        reason
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
    }), reason)).newEmoji

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
        reason
    )).newEmoji

proc deleteGuildEmoji*(api: RestApi, guild_id, emoji_id: string;
        reason = "") {.async.} =
    ## Deletes a guild emoji.
    discard await api.request("DELETE",
        endpointGuildEmojis(guild_id, emoji_id),
        reason
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
    ## * `nicks` Example: `{"2123450": "MrDude"}.toTable`
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