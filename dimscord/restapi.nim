import httpclient, sequtils, asyncdispatch, json, options, objects, constants, strutils, tables, re, times, random, os, uri, mimetypes, strformat, macros

randomize()

type
    RestException* = object of CatchableError
    RequestException* = object of CatchableError 
    DiscordFile* = ref object ## A Discord file.
        name*, body*: string
    AllowedMentions* = object
        ## An object of allowed mentions.
        ## For parse: The values should be "roles", "users", "everyone"
        parse*, roles*, users*: seq[string]
var fatalErr = false
var ratelimited = false
var global_retry_after = 0
var global = false

proc parseRoute(endpoint, meth: string): string =
    let majorParams = @["channels", "guilds", "webhooks"]
    let params = endpoint.findAll(re"([a-z-]+)")
    var route = endpoint.split("?", 2)[0]

    for param in params:
        if majorParams.contains(param):
            if param == "webhooks":
                route = route.replace(re"webhooks\/[0-9]{17,19}\/.*", "webhooks/:id/:token")

            route = route.replace(re"\/(?:[0-9]{17,19})", "/:id")
        elif param == "reactions":
            route = route.replace(re"reactions\/[^/]+", "reactions/:id")

    if route.endsWith("messages/:id") and meth == "DELETE":
        return meth & route

    result = route # I love 'result ='

proc delayRoutes(api: RestApi; global = false; route = "") {.async.} =
    var rl: tuple[retry_after: int, ratelimited: bool]

    if global:
        rl = (global_retry_after, ratelimited)
    elif route != "":
        rl = (api.endpoints[route].retry_after, api.endpoints[route].ratelimited)

    if rl.ratelimited:
        echo "Delaying ",(if global: "all" else: "HTTP")," requests in (", rl.retry_after * 1000 + 250, "ms) [", (if global: "global" else: route), "]"

        await sleepAsync rl.retry_after * 1000 + 250
        api.endpoints[route].ratelimited = false

proc clean(errors: JsonNode, extra = ""): seq[string] =
    result = @[]        
    var ext = extra

    case errors.kind:
        of JArray:
            var err: seq[string] = @[]

            for e in errors.elems:
                err.add("\n    - " & ext & ": " & e["message"].str)
            result = result.concat(err)
        of JObject:
            for err in errors.pairs:
                return clean(err.val, (if ext == "": err.key & "." & err.key else: ext & "." & err.key))
        else:
            discard

proc getErrorDetails(data: JsonNode): string =
    result = "[Discord Exception]:: " & data["message"].str & " (" & $data["code"].getInt() & ")"

    if data.hasKey("errors"):
        result = result & "\n" & clean(data["errors"]).join("\n")

proc request(api: RestApi, meth, endpoint: string;
            pl = "", mp: MultipartData = nil;
            xheaders: HttpHeaders = nil; auth = true): Future[JsonNode] {.async.} =
    var data: JsonNode
    var error = ""
    let route = endpoint.parseRoute(meth)

    if not api.endpoints.hasKey(route):
        api.endpoints.add(route, Ratelimit())

    proc doreq() {.async.} =
        if global:
            await api.delayRoutes(global)
        else:
            await api.delayRoutes(false, route)

        let client = newAsyncHttpClient("DiscordBot (https://github.com/krisppurg/dimscord, v" & libVer & ")")
        var resp: AsyncResponse

        if xheaders != nil: client.headers = xheaders
        if auth: client.headers["Authorization"] = api.token

        client.headers["Content-Type"] = "application/json"
        client.headers["Content-Length"] = $(pl.len)

        try:
            let url = restBase & "v" & $api.rest_ver & "/" & endpoint
            if mp == nil:
                resp = (await client.request(url, meth, pl))
            else:
                resp = (await client.post(url, pl, mp))
        except:
            raise newException(Exception, getCurrentExceptionMsg())

        client.close()

        var status = resp.code.int

        if api.endpoints.hasKey(route):
            let r = api.endpoints[route]           

            if resp.headers.hasKey("X-RateLimit-Reset"):
                r.retry_after = int(resp.headers["X-RateLimit-Reset"].parseInt - getTime().toUnix())

                if resp.headers.hasKey("X-RateLimit-Reset-After"):
                    if r.retry_after < resp.headers["X-RateLimit-Reset-After"].parseInt:
                        r.retry_after = resp.headers["X-RateLimit-Reset-After"].parseInt

            if r.retry_after <= 0: # if discord gives us reset-after a negative int, this would be cursed.
                r.retry_after = (r.retry_after - r.retry_after - r.retry_after) + 3

            if resp.headers.hasKey("X-RateLimit-Global"):
                global = true
                global_retry_after = r.retry_after

        let fin = "[" & $status & "] "
        if status >= 200:
            if status >= 300:
                error = fin & "Unknown error."
                fatalErr = true
                if status >= 400:
                    var res: JsonNode
                    if resp.headers["content-type"] == "application/json":
                        res = (await resp.body).parseJson

                    error = fin & "Bad request."
                    if status == 401:
                        error = fin & "Invalid authorization or missing authorization."
                    elif status == 403:
                        error = fin & "Missing permissions/access."
                    elif status == 404:
                        error = fin & "Not found."
                    elif status == 429:
                        fatalErr = false
                        ratelimited = true

                        error = fin & "You are being rate-limited."
                        if resp.headers.hasKey("Retry-After"):
                            await sleepAsync resp.headers["Retry-After"].parseInt

                        data = await api.request(meth, endpoint, pl, mp, xheaders, auth)

                    if res.hasKey("code") and res.hasKey("message"):
                        error = error & "\n\n - " & res.getErrorDetails()
                if status >= 500:
                    error = fin & "Internal Server Error."
                    if status == 503:
                        error = fin & "Service Unavailable."
                    elif status == 504:
                        error = fin & "Gateway timed out."

                if fatalErr:
                    raise newException(RestException, error)
                else:
                    echo error

            if status < 300 and status >= 200:
                if resp.headers["content-type"] == "application/json":
                    data = (await resp.body).parseJson
                else:
                    data = nil # Did you know JsonNode is nilable?

        if api.endpoints.hasKey(route):
            let rl = api.endpoints[route]

            if resp.headers.getOrDefault("X-RateLimit-Remaining", @["0"].HttpHeaderValues).toString == "0":
                if resp.headers.hasKey("X-RateLimit-Global"):
                    echo "Got ratelimit global."
                    ratelimited = true
                else:
                    rl.ratelimited = true

            if ratelimited or rl.ratelimited:
                if global:
                    await api.delayRoutes(global)
                else:
                    await api.delayRoutes(false, route)
    try:
        await doreq()
        result = data
    except:
        raise newException(RestException, if error == "": getCurrentExceptionMsg() else: error)

proc `%`*(o: Overwrite): JsonNode =
    result = newJObject()
    result["id"] = %o.id
    result["type"] = %o.kind
    result["allow"] = %o.allow
    result["deny"] = %o.deny

proc sendMessage*(api: RestApi, channel_id: string;
            content = ""; tts = false; embed = none(Embed);
            allowed_mentions = none(AllowedMentions); files = none(seq[DiscordFile])): Future[Message] {.async.} =
    ## Sends a discord message.
    let payload = %*{
        "content": content,
        "tts": tts
    }

    if embed.isSome: payload["embed"] = %get(embed)
    if allowed_mentions.isSome: payload["allowed_mentions"] = %get(allowed_mentions)

    var contenttype = ""

    if files.isSome:
        var mpd = newMultipartData()
        for file in get(files):
            if file.body != "":
                if file.body.startsWith("http"):
                    let client = newAsyncHttpClient()
                    let resp = await client.get(file.body)
                    file.body = await resp.body
    
                    let fil = splitFile(file.name)

                    if file.name == "":
                        contenttype = resp.headers["Content-Type"].toString
                        file.name = "file." & contenttype.split("/")[1]
                    else:
                        if fil.ext != "": contenttype = newMimetypes().getMimetype(fil.ext[1..high(fil.ext)])

                    mpd.add(fil.name, file.body, file.name, contenttype, useStream = false)
                else:
                    if file.name == "":
                        file.name = "file.png"
                    let fil = splitFile(file.name)

                    if fil.ext != "": contenttype = newMimetypes().getMimetype(fil.ext[1..high(fil.ext)])
                    mpd.add(file.name, file.body, file.name, contenttype, useStream = false)
            else:
                if file.name == "":
                    file.name = "file.png"
                let fil = splitFile(file.name)
                if fil.ext != "": contenttype = newMimetypes().getMimetype(fil.ext[1..high(fil.ext)])
                file.body = readFile(file.name)
                mpd.add(file.name, file.body, file.name, contenttype, useStream = false)

        mpd.add("payload_json", $payload, contentType = "application/json")
        return (await api.request("POST", endpointChannelMessages(channel_id), $(payload), mp = mpd)).newMessage

    result = (await api.request("POST", endpointChannelMessages(channel_id), $(payload))).newMessage

proc editMessage*(api: RestApi, channel_id, message_id: string; content = ""; tts = false; embed = none(Embed)): Future[Message] {.async.} =
    ## Edits a discord message.
    let payload = %*{
        "content": content,
        "tts": tts
    }
    if embed.isSome: payload["embed"] = %get(embed)
    result = (await api.request("PATCH", endpointChannelMessages(channel_id, message_id), $(payload))).newMessage

proc deleteMessage*(api: RestApi, channel_id, message_id: string; reason = "") {.async.} =
    ## Deletes a discord message.
    let h = if reason != "": newHttpHeaders({"X-Audit-Log-Reason": reason}) else: nil
    discard await api.request("DELETE", endpointChannelMessages(channel_id, message_id), xheaders = h)

proc getChannelMessages*(api: RestApi, channel_id: string; around = ""; before = ""; after = ""; limit = 50): Future[seq[Message]] {.async.} =
    ## Gets channel message.
    result = @[]

    var url = endpointChannelMessages(channel_id) & "?"

    if before != "":
        url = url & "before=" & before & "&"
    if after != "":
        url = url & "after=" & after & "&"
    if around != "":
        url = url & "around=" & around & "&"
    if limit > 0 and limit <= 100:
        url = url & "limit=" & $limit

    result = (await api.request("GET", url)).elems.map(newMessage)

proc getChannelMessage*(api: RestApi, channel_id, message_id: string): Future[Message] {.async.} =
    result = (await api.request("GET", endpointChannelMessages(channel_id, message_id))).newMessage

proc bulkDeleteMessages*(api: RestApi, channel_id: string; message_ids: seq[string]; reason = "") {.async.} =
    ## Bulk deletes messages
    let h = if reason != "": newHttpHeaders({"X-Audit-Log-Reason": reason}) else: nil
    discard await api.request("POST", endpointBulkDeleteMessages(channel_id), $(%*{"messages": message_ids}), xheaders = h)

proc addMessageReaction*(api: RestApi, channel_id, message_id, emoji: string) {.async.} =
    ## Add a message reaction to a Discord message.
    ## Emoji can be like 👀💩, but on animated custom emojis remove the 'a:' and should be 'likethis:123456789012345678'.

    var emj = emoji
    if emoji == decodeUrl(emoji):
        emj = encodeUrl(emoji)

    discard await api.request("PUT", endpointReactions(channel_id, message_id, e = emj, uid = "@me")) # first 'PUT' request :)

proc deleteMessageReaction*(api: RestApi, channel_id, message_id, emoji: string; user_id = "@me") {.async.} =
    ## Deletes the user's or the current user's message reaction to a Discord message.
    var emj = emoji
    if emoji == decodeUrl(emoji):
        emj = encodeUrl(emoji)

    discard await api.request("DELETE", endpointReactions(channel_id, message_id, e = emj, uid = user_id))

proc deleteMessageReactionEmoji*(api: RestApi, channel_id, message_id, emoji: string) {.async.} =
    discard await api.request("DELETE", endpointReactions(channel_id, message_id, emoji))

proc getMessageReactions*(api: RestApi, channel_id, message_id, emoji: string; before = ""; after = ""; limit = 25): Future[seq[User]] {.async.} =
    ## Get all user message reactions on the emoji provided.
    var emj = emoji
    var url = endpointReactions(channel_id, message_id, e = emj, uid = "@me") & "?"

    if emoji == decodeUrl(emoji):
        emj = encodeUrl(emoji)

    if before != "":
        url = url & "before=" & before & "&"
    if after != "":
        url = url & "after=" & after & "&"
    if limit > 0 and limit <= 100:
        url = url & "limit=" & $limit  

    result = (await api.request("GET", endpointReactions(channel_id, message_id, e = emj))).elems.map(newUser)

proc deleteAllMessageReactions*(api: RestApi, channel_id, message_id: string) {.async.} =
    ## Remove all message reactions.
    discard await api.request("DELETE", endpointReactions(channel_id, message_id))

proc triggerTypingIndicator*(api: RestApi, channel_id: string) {.async.} =
    ## Start typing in a specific discord channel.
    discard await api.request("POST", endpointTriggerTyping(channel_id))

proc addChannelMessagePin*(api: RestApi, channel_id, message_id: string) {.async.} =
    ## Add pin message.
    discard await api.request("PUT", endpointChannelPins(channel_id, message_id))

proc deleteChannelMessagePin*(api: RestApi, channel_id, message_id: string) {.async.} =
    ## Remove pinned message.
    discard await api.request("DELETE", endpointChannelPins(channel_id, message_id))

proc getChannelPins*(api: RestApi, channel_id: string): Future[seq[Message]] {.async.} =
    ## Get channel pins.
    result = (await api.request("GET", endpointChannelPins(channel_id))).elems.map(newMessage)

macro loadOpt(obj: typed, lits: varargs[untyped]): untyped =
    # Best demonstrated through example.
    # loadOpt(payload, name, position, topic) expands to:
    # if name.isSome:
    #     payload["name"] = %get(name)
    # if position.isSome:
    #     payload["position"] = %get(position)
    # if topic.isSome:
    #     payload["topic"] = %get(topic)
    result = newStmtList()
    for lit in lits:
        let fieldName = lit.strVal
        result.add quote do:
            if `lit`.isSome:
                `obj`[`fieldName`] = %get(`lit`)

macro loadNullableOptStr(obj: typed, lits: varargs[untyped]): untyped =
    # Best demonstrated through example.
    # loadNullableOpt(payload, channel_id) expands to:
    # if channel_id.isSome and getOrDefault(channel_id) == "":
    #     payload["channel_id"] = newJNull()

    result = newStmtList()
    for lit in lits:
        let fieldName = lit.strVal
        result.add quote do:
            if `lit`.isSome and get(`lit`) == "":
                `obj`[`fieldName`] = newJNull()

macro loadNullableOptInt(obj: typed, lits: varargs[untyped]): untyped =
    # Best demonstrated through example.
    # loadNullableOpt(payload, channel_id) expands to:
    # if channel_id.isSome and get(channel_id) == "":
    #     payload["channel_id"] = newJNull()

    result = newStmtList()
    for lit in lits:
        let fieldName = lit.strVal
        result.add quote do:
            if `lit`.isSome and get(`lit`) == -1:
                `obj`[`fieldName`] = newJNull()

proc editGuildChannel*(api: RestApi, channel_id: string; name, parent_id,
            topic = none(string); nsfw = none(bool);
            rate_limit_per_user, bitrate, position, user_limit = none(int);
            permission_overwrites = none(seq[Overwrite]); reason = ""): Future[GuildChannel] {.async.} =
    let h = if reason != "": newHttpHeaders({"X-Audit-Log-Reason": reason}) else: nil
    let payload = newJObject()

    payload.loadOpt(name, position, topic, nsfw, rate_limit_per_user,
        bitrate, user_limit, permission_overwrites, parent_id)

    payload.loadNullableOptStr(topic, parent_id)
    payload.loadNullableOptInt(position, rate_limit_per_user, bitrate, user_limit)

    result = (await api.request("PATCH", endpointChannels(channel_id), $(payload), xheaders = h)).newGuildChannel

proc createGuildChannel*(api: RestApi, guild_id, name: string; kind = 0;
            parent_id, topic = none(string); nsfw = none(bool);
            rate_limit_per_user, bitrate, position, user_limit = none(int);
            permission_overwrites = none(seq[Overwrite]); reason = ""): Future[GuildChannel] {.async.} =
    ## Creates a channel
    let payload = %*{"name": name, "type": kind}

    payload.loadOpt(position, topic, nsfw, rate_limit_per_user, bitrate, user_limit, permission_overwrites, parent_id)

    result = (await api.request("POST", endpointGuildChannels(guild_id), $(payload))).newGuildChannel

proc deleteChannel*(api: RestApi, channel_id: string) {.async.} =
    ## Deletes or closes a channel.
    discard await api.request("DELETE", endpointChannels(channel_id))

proc editGuildChannelPermissions*(api: RestApi, channel_id, perm_id, kind: string, perms: PermObj) {.async.} =
    ## Modify the channel's permissions.
    ## The `kind` param needs to be either "member" or "role".
    let payload = %*{"type": kind}
    if perms.allowed.len > 0:
        payload["allow"] = %(+perms.allowed)
    if perms.denied.len > 0:
        payload["deny"] = %(+perms.denied)
    discard await api.request("PUT", endpointChannelOverwrites(channel_id, perm_id), $(payload))

proc getInvite*(api: RestApi, code: string; with_counts, auth = false): Future[Invite] {.async.} =
    ## Get's a channel invite. The auth param is whether or not you should get the invite while authenticated.
    result = (await api.request("GET", endpointInvites(code) & fmt"?with_counts={with_counts}", auth = auth)).newInvite

proc beginGuildPrune*(api: RestApi, guild_id: string; days = 7; compute_prune_count = true; reason = "") {.async.} =
    ## Begins a guild prune.
    let h = if reason != "": newHttpHeaders({"X-Audit-Log-Reason": reason}) else: nil
    let url = endpointGuildPrune(guild_id) & "?days=" & $days & "&compute_prune_count=" & $compute_prune_count
    discard await api.request("POST", url, xheaders = h)

proc getGuildPruneCount*(api: RestApi, guild_id: string, days: int): Future[int] {.async.} =
    ## Gets the prune count.
    result = (await api.request("GET", endpointGuildPrune(guild_id) & "?days=" & $days))["pruned"].getInt()

proc deleteGuild*(api: RestApi, guild_id: string) {.async.} =
    discard await api.request("DELETE", endpointGuilds(guild_id))

proc editGuild*(api: RestApi, guild_id: string;
    name, region, afk_channel_id, icon = none(string);
    discovery_splash, owner_id, splash, banner = none(string);
    system_channel_id, rules_channel_id = none(string);
    preferred_locale, public_updates_channel_id = none(string);
    verification_level, default_message_notifications = none(int);
    explicit_content_filter, afk_timeout = none(int); reason = ""): Future[Guild] {.async.} =
    ## Edits a guild. Icon needs to be a base64 image (See: https://nim-lang.org/docs/base64.html)
    let h = if reason != "": newHttpHeaders({"X-Audit-Log-Reason": reason}) else: nil
    let payload = newJObject()

    payload.loadOpt(name, region, verification_level, default_message_notifications, icon,
        explicit_content_filter, afk_channel_id, afk_timeout, discovery_splash, owner_id,
        splash, banner, system_channel_id, rules_channel_id, public_updates_channel_id, preferred_locale)

    payload.loadNullableOptInt(verification_level, default_message_notifications,
        explicit_content_filter, afk_timeout)

    payload.loadNullableOptStr(icon, region, splash, discovery_splash, banner, system_channel_id,
        rules_channel_id, public_updates_channel_id, preferred_locale)

    result = (await api.request("PATCH", endpointGuilds(guild_id), $(payload), xheaders = h)).newGuild

proc getGuild*(api: RestApi, guild_id: string): Future[Guild] {.async.} =
    ## Get's guild via request.
    result = (await api.request("GET", endpointGuilds(guild_id))).newGuild

proc getGuildRoles*(api: RestApi, guild_id: string): Future[seq[Role]] {.async.} =
    ## Get's a guild's roles.
    result = (await api.request("GET", endpointGuildRoles(guild_id))).elems.map(newRole)

proc createGuildRole*(api: RestApi, guild_id: string; name = "new role";
            pobj: PermObj; color = 0; hoist, mentionable = false; reason = ""): Future[Role] {.async.} =
    ## Creates a guild role.
    let h = if reason != "": newHttpHeaders({"X-Audit-Log-Reason": reason}) else: nil
    result = (await api.request("PUT", endpointGuildRoles(guild_id), $(%*{
        "name": name,
        "permissions": %(+pobj),
        "color": color,
        "hoist": hoist,
        "mentionable": mentionable
    }), xheaders = h)).newRole

proc deleteGuildRole*(api: RestApi, guild_id, role_id: string) {.async.} =
    ## Deletes a guild role.
    discard await api.request("DELETE", endpointGuildRoles(guild_id, role_id))

proc editGuildRole*(api: RestApi, guild_id, role_id: string;
            name = none(string);
            pobj = none(PermObj); color = none(int);
            hoist, mentionable = none(bool)): Future[Role] {.async.} =
    ## Modifies a guild role.
    let payload = newJObject()

    payload.loadOpt(name, color, hoist, mentionable)

    payload.loadNullableOptStr(name)
    payload.loadNullableOptInt(color)

    if pobj.isSome:
        payload["permissions"] = %(+(get(pobj)))

    result = (await api.request("PATCH", endpointGuildRoles(guild_id, role_id), $(payload))).newRole

proc editGuildRolePosition*(api: RestApi, guild_id, role_id: string; position = none(int); reason = ""): Future[seq[Role]] {.async.} =
    ## Edits guild role position.
    let h = if reason != "": newHttpHeaders({"X-Audit-Log-Reason": reason}) else: nil

    result = (await api.request("PATCH", endpointGuildRoles(guild_id), $(%*{
        "id": role_id,
        "position": %position
    }), xheaders = h)).elems.map(newRole)

proc getGuildInvites*(api: RestApi, guild_id: string): Future[seq[InviteMetadata]] {.async.} =
    ## Gets guild invites.
    result = (await api.request("GET", endpointGuildInvites(guild_id))).elems.map(newInviteMetadata)

proc getGuildVanityUrl*(api: RestApi, guild_id: string): Future[tuple[code: Option[string], uses: int]] {.async.} =
    ## Gets the guild vanity url.
    result = (await api.request("GET", endpointGuildVanity(guild_id))).to(tuple[code: Option[string], uses: int])

proc editGuildMember*(api: RestApi, guild_id, user_id: string;
        nick, channel_id = none(string);
        roles = none(seq[string]);
        mute, deaf = none(bool); reason = "") {.async.} =
    let h = if reason != "": newHttpHeaders({"X-Audit-Log-Reason": reason}) else: nil
    let payload = newJObject()

    payload.loadOpt(nick, roles, mute, deaf, channel_id)
    payload.loadNullableOptStr(channel_id)

    discard await api.request("PATCH", endpointGuildMembers(guild_id, user_id), $(payload), xheaders = h)

proc removeGuildMember*(api: RestApi, guild_id, user_id, reason: string) {.async.} =
    ## Removes a guild member.
    discard await api.request("DELETE", endpointGuildMembers(guild_id, user_id))

proc getGuildBan*(api: RestApi, guild_id, user_id: string): Future[GuildBan] {.async.} =
    ## Gets guild ban.
    result = (await api.request("GET", endpointGuildBans(guild_id, user_id))).newGuildBan

proc getGuildBans*(api: RestApi, guild_id: string): Future[seq[GuildBan]] {.async.} =
    ## Gets all the guild bans.
    result = (await api.request("GET", endpointGuildBans(guild_id))).elems.map(newGuildBan)

proc createGuildBan*(api: RestApi, guild_id, user_id: string; deletemsgdays = 0; reason = "") {.async.} =
    ## Creates a guild ban.
    let h = if reason != "": newHttpHeaders({"X-Audit-Log-Reason": reason}) else: nil
    discard await api.request("PUT", endpointGuildBans(guild_id, user_id), $(%*{
        "delete-message-days": $deletemsgdays,
        "reason": reason
    }), xheaders = h)

proc removeGuildBan*(api: RestApi, guild_id, user_id: string) {.async.} =
    ## Removes a guild ban. 
    discard await api.request("DELETE", endpointGuildBans(guild_id, user_id))

proc getGuildChannels*(api: RestApi, guild_id: string): Future[seq[GuildChannel]] {.async.} =
    ## Gets a list of a guild's channels
    result = (await api.request("GET", endpointGuildChannels(guild_id))).elems.map(newGuildChannel)

proc editGuildChannelPositions*(api: RestApi, guild_id, channel_id: string; position = none(int); reason = "") {.async.} =
    ## Edits a guild channel's position.
    let h = if reason != "": newHttpHeaders({"X-Audit-Log-Reason": reason}) else: nil
    discard await api.request("PATCH", endpointGuildChannels(guild_id, channel_id), $(%*{
        "id": channel_id,
        "position": %position
    }), xheaders = h)

proc getGuildMember*(api: RestApi, guild_id, user_id: string): Future[Member] {.async.} =
    ## Gets a guild member.
    result = (await api.request("GET", endpointGuildMembers(guild_id, user_id))).newMember

proc getGuildMembers*(api: RestApi, guild_id: string; limit = 1, after = "0"): Future[seq[Member]] {.async.} =
    ## Gets a list of a guild's members.
    result = ((await api.request("GET", endpointGuildMembers(guild_id) & "?limit=" & $limit & "&after=" & after))).elems.map(newMember)

proc setGuildNick*(api: RestApi, guild_id: string; nick = "") {.async.} =
    ## Sets the current user's guild nickname, defaults to "" if no nick is set.
    discard await api.request("PATCH", endpointGuildMembersNick(guild_id, "@me"), $(%*{"nick": nick}))

proc addGuildMemberRole*(api: RestApi, guild_id, user_id, role_id: string; reason = "") {.async.} =
    ## Assigns a member's role.
    let h = if reason != "": newHttpHeaders({"X-Audit-Log-Reason": reason}) else: nil
    discard await api.request("PUT", endpointGuildMembersRole(guild_id, user_id, role_id), xheaders = h)

proc removeGuildMemberRole*(api: RestApi, guild_id, user_id, role_id: string; reason = "") {.async.} =
    ## Removes a member's role.
    let h = if reason != "": newHttpHeaders({"X-Audit-Log-Reason": reason}) else: nil
    discard await api.request("DELETE", endpointGuildMembersRole(guild_id, user_id, role_id), xheaders = h)

proc createChannelInvite*(api: RestApi, channel_id: string;
    max_age = 86400,
    max_uses = 0,
    temp, unique = false,
    target_user = none(string),
    target_user_type = none(int)): Future[Invite] {.async.} =
    ## Creates an instant invite.
    let payload = %*{
        "max_age": max_age,
        "max_uses": max_uses,
        "temp": temp,
        "unique": unique,
    }
    payload.loadOpt(target_user, target_user_type)

    result = (await api.request("POST", endpointChannelInvites(channel_id), $(payload))).newInvite

proc deleteGuildChannelPermission*(api: RestApi, channel_id, overwrite: string; reason = "") {.async.} =
    ## Deletes guild channel permission overwrite.
    let h = if reason != "": newHttpHeaders({"X-Audit-Log-Reason": reason}) else: nil
    discard await api.request("DELETE", endpointChannelOverwrites(channel_id, overwrite), xheaders = h)

proc deleteInvite*(api: RestApi, code: string) {.async.} =
    ## Deletes a guild invite.
    discard await api.request("DELETE", endpointInvites(code))

proc getChannelInvites*(api: RestApi, channel_id: string): Future[seq[Invite]] {.async.} =
    ## Gets a list of a channel's invites.
    result = (await api.request("GET", endpointChannelInvites(channel_id))).elems.map(newInvite)

proc getGuildIntegrations*(api: RestApi, guild_id: string): Future[seq[Integration]] {.async.} =
    ## Gets a list of guild integrations.
    result = (await api.request("GET", endpointGuildIntegrations(guild_id))).elems.map(proc (x: JsonNode): Integration =
        result = x.to(Integration))

proc getChannelWebhooks*(api: RestApi, channel_id: string): Future[seq[Webhook]] {.async.} =
    ## Gets a list of a channel's webhooks.
    result = (await api.request("GET", endpointChannelWebhooks(channel_id))).elems.map(newWebhook)

proc getGuildWebhooks*(api: RestApi, guild_id: string): Future[seq[Webhook]] {.async.} =
    ## Gets a list of a channel's webhooks.
    result = (await api.request("GET", endpointGuildWebhooks(guild_id))).elems.map(newWebhook)

proc executeWebhook*(api: RestApi, webhook_id, token: string; wait = true;
            content = ""; tts = false;
            file = none(DiscordFile);
            embeds = none(seq[Embed]);
            allowed_mentions = none(AllowedMentions);
            username, avatar_url = none(string)): Future[Message] {.async.} =
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
        var contenttype = ""
        var mpd = newMultipartData()

        if get(file).name == "":
            get(file).name = "file.png"
        let fil = splitFile(get(file).name)

        if fil.ext != "": contenttype = newMimetypes().getMimetype(fil.ext[1..high(fil.ext)])
        get(file).body = readFile(get(file).name)
        mpd.add(get(file).name, get(file).body, get(file).name, contenttype, useStream = false)

        mpd.add("payload_json", $payload, contentType = "application/json")

        return (await api.request("POST", url, $(payload), mp = mpd)).newMessage
    result = (await api.request("POST", url, $(payload))).newMessage

proc executeSlackWebhook*(api: RestApi, webhook_id, token: string; wait = true): Future[Message] {.async.} =
    ## Executes a slack webhook. If wait is false make sure to asyncCheck it.
    result = (await api.request("POST", endpointWebhookTokenSlack(webhook_id, token) & "?wait=" & $wait)).newMessage

proc executeGithubWebhook*(api: RestApi, webhook_id, token: string; wait = true): Future[Message] {.async.} =
    ## Executes a github webhook. If wait is false make sure to asyncCheck it.
    result = (await api.request("POST", endpointWebhookTokenGithub(webhook_id, token) & "?wait=" & $wait)).newMessage

proc getWebhook*(api: RestApi, webhook_id: string): Future[Webhook] {.async.} =
    ## Gets a webhook.
    result = (await api.request("GET", endpointWebhooks(webhook_id))).newWebhook

proc deleteWebhook*(api: RestApi, webhook_id: string; reason = "") {.async.} =
    ## Deletes a webhook.
    let h = if reason != "": newHttpHeaders({"X-Audit-Log-Reason": reason}) else: nil
    discard await api.request("DELETE", endpointWebhooks(webhook_id), xheaders = h)

proc editWebhook*(api: RestApi, webhook_id: string;
        name, avatar, channel_id = none(string); reason = "") {.async.} =
    ## Modifies a webhook. 
    let h = if reason != "": newHttpHeaders({"X-Audit-Log-Reason": reason}) else: nil
    let payload = newJObject()

    payload.loadOpt(name, avatar, channel_id)
    payload.loadNullableOptStr(avatar)

    discard await api.request("PATCH", endpointWebhooks(webhook_id), $(payload), xheaders = h)

proc syncGuildIntegration*(api: RestApi, guild_id, integ_id: string) {.async.} =
    ## Syncs a guild integration.
    discard await api.request("POST", endpointGuildIntegrationsSync(guild_id, integ_id))

proc editGuildIntegration*(api: RestApi, guild_id, integ_id: string;
        expire_behavior, expire_grace_period = none(int);
        enable_emoticons = none(bool); reason: string = "") {.async.} =
    ## Edits a guild integration.
    let payload = newJObject()
    let h = if reason != "": newHttpHeaders({"X-Audit-Log-Reason": reason}) else: nil

    payload.loadOpt(expire_behavior, expire_grace_period, enable_emoticons)
    payload.loadNullableOptInt(expire_behavior, expire_grace_period)

    discard await api.request("PATCH", endpointGuildIntegrationsSync(guild_id, integ_id), $(payload), xheaders = h)

proc deleteGuildIntegration*(api: RestApi, integ_id: string; reason = "") {.async.} =
    ## Deletes a guild integration.
    let h = if reason != "": newHttpHeaders({"X-Audit-Log-Reason": reason}) else: nil
    discard await api.request("DELETE", endpointGuildIntegrations(integ_id), xheaders = h)

proc getGuildEmbed*(api: RestApi, guild_id: string): Future[tuple[enabled: bool, channel_id: Option[string]]] {.async.} =
    ## Gets a guild embed.
    result = (await api.request("GET", endpointGuildEmbed(guild_id))).to(tuple[enabled: bool, channel_id: Option[string]])

proc editGuildEmbed*(api: RestApi, guild_id: string, enabled = none(bool); channel_id = none(string)): Future[tuple[enabled: bool, channel_id: Option[string]]] {.async.} =
    ## Modifies a guild embed.
    let payload = newJObject()

    payload.loadOpt(enabled, channel_id)
    payload.loadNullableOptStr(channel_id)

    result = (await api.request("PATCH", endpointGuildEmbed(guild_id), $(payload))).to(tuple[enabled: bool, channel_id: Option[string]])

proc getGuildPreview*(api: RestApi, guild_id: string): Future[GuildPreview] {.async.} =
    ## Gets guild preview.
    result = (await api.request("GET", endpointGuildPreview(guild_id))).to(GuildPreview)

proc addGuildMember*(api: RestApi, guild_id, user_id,
        access_token: string;
        nick = none(string);
        roles = none(seq[string]);
        mute, deaf = none(bool); reason: string = ""): Future[tuple[member: Member, exists: bool]] {.async.} =
    ## Adds a guild member. If member is in the guild, then exists will be true.
    let h = if reason != "": newHttpHeaders({"X-Audit-Log-Reason": reason}) else: nil
    let payload = %*{"access_token": access_token}

    payload.loadOpt(nick, roles, mute, deaf)

    let member = (await api.request("PUT", endpointGuildMembers(guild_id, user_id), xheaders = h))
    if member.kind == JNull:
        result = (Member(), true)
    else:
        result = (newMember(member), false)

proc createGuildEmoji*(api: RestApi, guild_id, name, image: string; roles: seq[string] = @[]; reason = ""): Future[Emoji] {.async.} =
    ## Creates a guild emoji. The image needs to be a base64 string (See: https://nim-lang.org/docs/base64.html)
    let h = if reason != "": newHttpHeaders({"X-Audit-Log-Reason": reason}) else: nil

    result = (await api.request("POST", endpointGuildEmojis(guild_id), $(%*{
        "name": name,
        "image": image,
        "roles": roles
    }), xheaders = h)).newEmoji

proc editGuildEmoji*(api: RestApi, guild_id, emoji_id: string; name = none(string); roles = none(seq[string]); reason = ""): Future[Emoji] {.async.} =
    let payload = newJObject()
    let h = if reason != "": newHttpHeaders({"X-Audit-Log-Reason": reason}) else: nil

    payload.loadOpt(name)
    payload.loadNullableOptStr(name)

    if roles.isSome and get(roles).len < 0:
        payload["roles"] = newJNull()

    result = (await api.request("PATCH", endpointGuildEmojis(guild_id, emoji_id), $(%*{
        "name": name,
        "roles": roles
    }), xheaders = h)).newEmoji

proc deleteGuildEmoji*(api: RestApi, guild_id, emoji_id: string; reason = "") {.async.} =
    let h = if reason != "": newHttpHeaders({"X-Audit-Log-Reason": reason}) else: nil
    discard await api.request("DELETE", endpointGuildEmojis(guild_id, emoji_id), xheaders = h)

proc getUser*(api: RestApi, user_id: string): Future[User] {.async.} =
    result = (await api.request("GET", endpointUsers(user_id))).newUser

proc leaveGuild*(api: RestApi, guild_id: string) {.async.} =
    discard await api.request("DELETE", endpointUserGuilds(guild_id))

proc createUserDm*(api: RestApi, user_id: string): Future[DMChannel] {.async.} =
    result = (await api.request("POST", endpointUserChannels(), $(%*{
        "recipient_id": user_id
    }))).newDMChannel

# proc getGuildVoiceRegions*()
# proc getVoiceRegions*()
# proc getCurrentUser*()
# proc editCurrentUser*()
# proc getCurrentUserGuilds*()
# proc createGroupDm*()
# proc getGuildAuditLogs*()
# proc addGroupDmRecipient*()
# proc removeGroupDmRecipient*()