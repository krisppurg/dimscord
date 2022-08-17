import httpclient, asyncdispatch, json, options
import ../objects, ../constants
import tables, regex, times, os, sequtils, strutils
import uri, macros

var
    fatalErr = true
    ratelimited, global = false
    global_retry_after = 0.0
    invalid_requests = 0

proc `<=`(x, y: HttpCode): bool =
    result = x.int <= y.int

proc parseRoute(endpoint, meth: string): string =
    let
        majorParams = @["channels", "guilds", "webhooks"]
        params = endpoint.findAndCaptureAll(re"([a-z-]+)")

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

proc handleRoute(api: RestApi, glbal = false; route = "") {.async.} =
    var rl: tuple[retry_after: float, ratelimited: bool]

    if glbal:
        rl = (global_retry_after, ratelimited)
    elif route != "":
        rl = (api.endpoints[route].retry_after,
            api.endpoints[route].ratelimited)

    if rl.ratelimited:
        log "Delaying " & (if global: "all" else: "HTTP") &
            " requests in (" & $(int(rl.retry_after * 1000) + 250) &
            "ms) [" & (if glbal: "global" else: route) & "]"

        await sleepAsync int(rl.retry_after * 1000) + 250

        if not glbal:
            api.endpoints[route].ratelimited = false
        else:
            ratelimited = false
            global = false

proc discordDetailedErrors(errors: JsonNode, extra = ""): seq[string] =
    let ext = extra

    case errors.kind:
    of JArray:
        var err: seq[string] = @[]

        for e in errors.elems:
            err.add("\n    - " & ext & ": " & e["message"].str)
        result = result.concat(err)
    of JObject:
        for err in errors.pairs:
            return discordDetailedErrors(err.val, (if ext == "":
                    err.key & "." & err.key else: ext & "." & err.key))
    else:
        discard

proc discordErrors(data: JsonNode): string =
    result = "[DiscordError]:: " &
        data["message"].str & " (" & $data["code"].getInt & ")"

    if "errors" in data:
        result &= "\n" & discordDetailedErrors(data["errors"]).join("\n")

proc request*(api: RestApi, meth, endpoint: string;
            pl, audit_reason = ""; mp: MultipartData = nil;
            auth = true): Future[JsonNode] {.async.} =
    if api.token == "Bot  ":
        raise newException(Exception, "The token you specified was empty.")
    let route = endpoint.parseRoute(meth)

    if route notin api.endpoints:
        api.endpoints[route] = Ratelimit()

    var
        data: JsonNode
        error = ""

    let r = api.endpoints[route]
    while r.processing:
        await sleepAsync 0

    proc doreq() {.async.} =
        if invalid_requests >= 1500:
            raise newException(RestError,
                "You are sending too many invalid requests.")

        if global:
            await api.handleRoute(global)
        else:
            await api.handleRoute(false, route)

        let
            client = newAsyncHttpClient(libAgent)
            url = restBase & "v" & $api.restVersion & "/" & endpoint

        var resp: AsyncResponse

        if audit_reason != "":
            client.headers["X-Audit-Log-Reason"] = encodeUrl(
                audit_reason, usePlus = false
            ).replace(" ", "%20")
        if auth:
            client.headers["Authorization"] = api.token

        client.headers["Content-Type"] = "application/json"
        client.headers["Content-Length"] = $pl.len

        log("Making request to " & meth & " " & url, (
            size: pl.len,
            reason: if audit_reason != "": audit_reason else: ""
        ))

        try:
            if mp == nil:
                resp = await client.request(url, parseEnum[HttpMethod](meth), pl)
            else:
                resp = await client.post(url, pl, mp)
        except:
            r.processing = false
            raise newException(Exception, getCurrentExceptionMsg())

        log("Got response.")

        let
            retry_header = resp.headers.getOrDefault(
                "X-RateLimit-Reset-After",
                @["0.250"].HttpHeaderValues).parseFloat
            status = resp.code
            fin = "[" & $status.int & "] "

        if retry_header > r.retry_after:
            r.retry_after = retry_header

        if status >= Http300:
            error = fin & "Client error."

            if status != Http429: r.processing = false

            if status.is4xx:
                if resp.headers["content-type"] == "application/json":
                    let body = resp.body

                    if not (await withTimeout(body, 60_000)):
                        raise newException(RestError,
                            "Body took too long to parse.")
                    else:
                        data = (await body).parseJson
                let detailederr = "code" in data and "message" in data

                case status:
                of Http400:
                    error = fin & "Bad request.\n"
                    if not data.isNil and not detailederr:#dont want duplicates
                        error &= data.pretty()
                of Http401:
                    error = fin & "Invalid authorization."
                    invalid_requests += 1
                of Http403:
                    error = fin & "Missing permissions/access."
                    invalid_requests += 1
                of Http404:
                    error = fin & "Not found."
                of Http429:
                    fatalErr = false
                    ratelimited = true

                    invalid_requests += 1

                    error = fin & "You are being rate-limited."
                    var retry: int 

                    if api.restVersion >= 8:
                        retry = data["retry_after"].getInt * 1000
                    else:
                        retry = int(data{"retry_after"}.getFloat(1.25) * 1000)

                    await sleepAsync retry

                    await doreq()
                else:
                    error = fin & "Unknown error"

                if detailederr and not data.isNil:
                    error &= "\n\n - " & data.discordErrors()

            if status.is5xx:
                error = fin & "Internal Server Error."
                if status == Http503:
                    error = fin & "Service Unavailable."
                elif status == Http504:
                    error = fin & "Gateway timed out."

            if fatalErr:
                raise newException(RestError, error)
            else:
                echo error

        if status.is2xx:
            if resp.headers["content-type"] == "application/json":
                log("Awaiting for body to be parsed")
                let body = resp.body

                if not (await withTimeout(body, 60_000)):
                    raise newException(RestError,
                        "Body took too long to parse.")
                else:
                    data = (await body).parseJson
            else:
                data = nil

            if invalid_requests > 0: invalid_requests -= 250

        let headerLimited = resp.headers.getOrDefault(
            "X-RateLimit-Remaining",
            @["0"].HttpHeaderValues).toString == "0"

        if headerLimited:
            if resp.headers.hasKey("X-RateLimit-Global"):
                global = true
                global_retry_after = r.retry_after
                ratelimited = true
                r.ratelimited = true

                await api.handleRoute(global)
            else:
                global = false #if it was global before set it to false
                r.ratelimited = true
                await api.handleRoute(false, route)

        r.processing = false
        client.close()
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

proc `%`*(t: tuple[channel_id: string, duration_seconds: int]): JsonNode =
    %*{"channel_id":t.channel_id,"duration_seconds":t.duration_seconds}

proc `%`*(tm: tuple[keyword_filter: seq[string], presets: seq[int]]): JsonNode =
    %*{"keyword_filter":tm.keyword_filter,"presets":tm.presets}

proc `%`*(o: Overwrite): JsonNode =
    %*{"id": o.id,
        "type": %o.kind,
        "allow": %cast[int](o.allow),
        "deny": %cast[int](o.deny)}

proc `%`*(flags: set[MessageFlags]): JsonNode =
    %cast[int](flags)

proc `%`*(flags: set[PermissionFlags]): JsonNode =
    %($cast[int](flags))

macro loadOpt*(obj: typed, lits: varargs[untyped]): untyped =
    result = newStmtList()
    for lit in lits:
        let fieldName = lit.strVal
        result.add quote do:
            if `lit`.isSome:
                `obj`[`fieldName`] = %*get(`lit`)

macro loadNullableOptStr*(obj: typed, lits: varargs[untyped]): untyped =
    result = newStmtList()
    for lit in lits:
        let fieldName = lit.strVal
        result.add quote do:
            if `lit`.isSome and get(`lit`) == "":
                `obj`[`fieldName`] = newJNull()

macro loadNullableOptInt*(obj: typed, lits: varargs[untyped]): untyped =
    result = newStmtList()
    for lit in lits:
        let fieldName = lit.strVal
        result.add quote do:
            if `lit`.isSome and get(`lit`) == -1:
                `obj`[`fieldName`] = newJNull()
