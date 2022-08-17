import httpclient, mimetypes, asyncdispatch, options
import ../objects, ../constants
import tables, os, json, sequtils, jsony
import uri, ../helpers, requester

proc sendMessage*(api: RestApi, channel_id: string;
        content = ""; tts = false;
        nonce: Option[string] or Option[int] = none(int);
        files = newSeq[DiscordFile]();
        embeds = newSeq[Embed]();
        attachments = newSeq[Attachment]();
        allowed_mentions = none AllowedMentions;
        message_reference = none MessageReference;
        components = newSeq[MessageComponent]();
        sticker_ids = newSeq[string]()): Future[Message] {.async.} =
    ## Sends a Discord message.
    ## - `nonce` This can be used for optimistic message sending
    assert content.len in 0..2000, "Message too long to send :: "&($content.len)
    assert sticker_ids.len in 0..3
    let payload = %*{
        "content": content,
        "tts": tts,
    }
    if message_reference.isSome:
        payload["message_reference"] = %*{
          "fail_if_not_exists":message_reference.get.fail_if_not_exists.get true
        }

    if sticker_ids.len > 0: payload["sticker_ids"] = %sticker_ids
    if embeds.len > 0: payload["embeds"] = %embeds

    payload.loadOpt(allowed_mentions, nonce, message_reference)

    if components.len > 0:
        payload["components"] = newJArray()
        for component in components:
            payload["components"].add %%*component

    var mpd: MultipartData

    if files.len > 0:
        mpd = newMultipartData()
        for file in files:
            var contenttype = ""
            if file.name == "":
                raise newException(Exception,
                    "File name needs to be provided."
                )

            let fil = splitFile(file.name)

            if fil.ext != "":
                let ext = fil.ext[1..high(fil.ext)]
                contenttype = newMimetypes().getMimetype(ext)

            if file.body == "":
                file.body = readFile(file.name)

            mpd.add(fil.name, file.body, file.name,
                contenttype, useStream = false)

        mpd.add("payload_json", $payload, contentType = "application/json")

    if attachments.len > 0:
        mpd = newMultipartData()
        payload["attachments"] = %[]
        for i, a in attachments:
            payload["attachments"].add %a
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

        mpd.add("payload_json", $payload, contentType = "application/json")

    result = (await api.request(
        "POST",
        endpointChannelMessages(channel_id),
        pl = $payload,
        mp = mpd
    )).newMessage

proc editMessage*(api: RestApi, channel_id, message_id: string;
        content = ""; tts = false; flags = none int;
        embeds = newSeq[Embed](); attachments = newSeq[Attachment]();
        components = newSeq[MessageComponent]()): Future[Message] {.async.} =
    ## Edits a discord message.
    assert content.len <= 2000
    let payload = %*{
        "content": content,
        "tts": tts,
        "flags": %flags
    }
    var mpd: MultipartData

    if embeds.len > 0:
        payload["embeds"] = %embeds

    if components.len > 0:
        payload["components"] = newJArray()
        for component in components:
            payload["components"] &= %%*component
    if attachments.len > 0:
        mpd = newMultipartData()
        payload["attachments"] = %[]
        for i, a in attachments:
            payload["attachments"].add %a
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

        mpd.add("payload_json", $payload, contentType = "application/json")

    result = (await api.request(
        "PATCH",
        endpointChannelMessages(channel_id, message_id),
        $payload
    )).newMessage

proc crosspostMessage*(api: RestApi;
        channel_id, message_id: string): Future[Message] {.async.} =
    ## Crosspost channel message aka publish messages into news channels.
    result = (await api.request(
        "POST",
        endpointChannelMessagesCrosspost(channel_id, message_id)
    )).newMessage

proc deleteMessage*(api: RestApi, channel_id, message_id: string;
        reason = "") {.async.} =
    ## Deletes a discord message.
    discard await api.request(
        "DELETE",
        endpointChannelMessages(channel_id, message_id),
        audit_reason = reason
    )

proc getChannelMessages*(api: RestApi, channel_id: string;
        around, before, after = "";
        limit: range[1..100] = 50): Future[seq[Message]] {.async.} =
    ## Gets channel messages.
    var url = endpointChannelMessages(channel_id) & "?"

    if before != "":
        url &= "before=" & before & "&"
    if after != "":
        url &= "after=" & after & "&"
    if around != "":
        url &= "around=" & around & "&"

    result = (await api.request("GET",
        url & "limit=" & $limit
    )).elems.map(newMessage)

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
    assert message_ids.len in 1..100
    discard await api.request(
        "POST",
        endpointBulkDeleteMessages(channel_id),
        $(%*{
            "messages": message_ids
        }),
        audit_reason = reason
    )

proc addMessageReaction*(api: RestApi,
        channel_id, message_id, emoji: string) {.async.} =
    ## Adds a message reaction to a Discord message.
    ##
    ## - `emoji` Example: '👀', '💩', `likethis:123456789012345678`

    var emj = emoji
    if emoji == decodeUrl(emoji):
        emj = encodeUrl(emoji)

    discard await api.request("PUT",
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
        limit: range[1..100] = 25): Future[seq[User]] {.async.} =
    ## Get all user message reactions on the emoji provided.
    var emj = emoji
    var url = endpointReactions(channel_id, message_id, e=emj, uid="@me") & "?"

    if emoji == decodeUrl(emoji):
        emj = encodeUrl(emoji)

    if before != "":
        url = url & "before=" & before & "&"
    if after != "":
        url = url & "after=" & after & "&"

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

proc executeWebhook*(api: RestApi, webhook_id, webhook_token: string;
        wait = true; thread_id = none string;
        content = ""; tts = false; flags = none int;
        files = newSeq[DiscordFile]();
        attachments = newSeq[Attachment]();
        embeds = newSeq[Embed]();
        allowed_mentions = none AllowedMentions;
        username, avatar_url = none string;
        components = newSeq[MessageComponent]()
): Future[Option[Message]] {.async.} =
    ## Executes a webhook or create a followup message.
    ## - `webhook_id` can be used as application id
    ## - `webhook_token` can be used as interaction token
    ## - `flags` are only used for interaction responses
    assert embeds.len in 0..10

    var
        url = endpointWebhookToken(webhook_id,webhook_token) & "?wait=" & $wait
        rawResult: JsonNode
        mpd: MultipartData

    if thread_id.isSome: url &= "&thread_id=" & thread_id.get

    let payload = %*{
        "content": content,
        "tts": tts
    }

    payload.loadOpt(username, avatar_url, allowed_mentions, flags)

    if embeds.len > 0: payload["embeds"] = %embeds

    if components.len > 0:
        payload["components"] = newJArray()
        for component in components:
            payload["components"].add %%*component

    if attachments.len > 0:
        mpd = newMultipartData()
        payload["attachments"] = %[]
        for i, a in attachments:
            payload["attachments"].add %a
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

        mpd.add("payload_json", $payload, contentType = "application/json")

    if files.len > 0:
        mpd = newMultipartData()
        for file in files:
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

    rawResult = (await api.request("POST", url, $payload, mp = mpd))

    if wait:
        result = some rawResult.newMessage
    else:
        result = none Message

proc createFollowupMessage*(api: RestApi,
        application_id, interaction_token: string;
        content = ""; tts = false;
        files = newSeq[DiscordFile]();
        attachments = newSeq[Attachment]();
        embeds = newSeq[Embed]();
        allowed_mentions = none AllowedMentions;
        components = newSeq[MessageComponent]();
        flags = none int): Future[Message] {.async.} =
    ## Create a followup message.
    ## - `flags` can set the followup message as ephemeral.
    result = get(await api.executeWebhook(
        application_id, interaction_token,
        content = content,
        tts = tts,
        files = files,
        embeds = embeds,
        allowed_mentions = allowed_mentions,
        components = components,
        attachments = attachments,
        flags = flags,
        wait = true
    ))

proc editWebhookMessage*(api: RestApi;
        webhook_id, webhook_token, message_id: string;
        content, thread_id = none string;
        embeds = newSeq[Embed]();
        allowed_mentions = none AllowedMentions;
        attachments = newSeq[Attachment]();
        files = newSeq[DiscordFile]();
        components = newSeq[MessageComponent]()): Future[Message] {.async.} =
    ## Modifies the webhook message.
    ## You can actually use this to modify
    ## original interaction or followup message.
    ##
    ## - `webhook_id` can also be application_id
    ## - `webhook_token` can also be interaction token.
    ## - `message_id` can be `@original`
    assert embeds.len in 0..10
    var endpoint = endpointWebhookMessage(webhook_id, webhook_token, message_id)
    if thread_id.isSome: endpoint &= "?thread_id=" & thread_id.get

    let payload = %*{
        "content": %content,
        "embeds": %embeds,
        "allowed_mentions": %(%allowed_mentions)
    }
    var mpd: MultipartData

    if components.len > 0:
        payload["components"] = newJArray()
        for component in components:
            payload["components"].add %%*component

    if files.len > 0:
        mpd = newMultipartData()
        for file in files:
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

    if attachments.len > 0:
        mpd = newMultipartData()
        payload["attachments"] = %[]

        for i, a in attachments:
            payload["attachments"].add %a
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

        mpd.add("payload_json", $payload, contentType = "application/json")

    result = (await api.request("PATCH", endpoint, $payload, mp=mpd)).newMessage

proc editInteractionResponse*(api: RestApi;
        application_id, interaction_token, message_id: string;
        content = none string;
        embeds = newSeq[Embed]();
        allowed_mentions = none AllowedMentions;
        attachments = newSeq[Attachment]();
        files = newSeq[DiscordFile]();
        components = newSeq[MessageComponent]()): Future[Message] {.async.} =
    ## Modifies interaction response
    ## You can actually use this to modify original interaction or followup message.
    ##
    ## - `message_id` can be `@original`
    result = await api.editWebhookMessage(
        application_id, interaction_token, message_id,
        content = content,
        embeds = embeds,
        allowed_mentions = allowed_mentions,
        attachments = attachments,
        files = files,
        components = components,
    )

proc getWebhookMessage*(api: RestApi;
        webhook_id, webhook_token, message_id: string;
        thread_id = none string): Future[Message] {.async.} =
    ## Get webhook message.
    var endpoint = endpointWebhookMessage(webhook_id, webhook_token, message_id)
    if thread_id.isSome: endpoint &= "?thread_id=" & thread_id.get
    result = (await api.request("GET", endpoint)).newMessage

proc getInteractionResponse*(
    api: RestApi;
    application_id, interaction_token, message_id: string
): Future[Message] {.async.} =
    ## Get interaction response or follow up message.
    result = await api.getWebhookMessage(
        application_id, interaction_token, message_id
    )

proc deleteWebhookMessage*(api: RestApi;
        webhook_id, webhook_token, message_id: string;
        thread_id = none string) {.async.} =
    ## Delete webhook message.
    var endpoint = endpointWebhookMessage(webhook_id, webhook_token, message_id)
    if thread_id.isSome: endpoint &= "?thread_id=" & thread_id.get
    discard await api.request("DELETE", endpoint)

proc deleteInteractionResponse*(api: RestApi;
        application_id, interaction_token, message_id: string) {.async.} =
    ## Delete followup message or interaction response.
    await api.deleteWebhookMessage(
        application_id, interaction_token, message_id
    )

proc executeSlackWebhook*(api: RestApi, webhook_id, token: string;
        wait = true;thread_id = none string): Future[Option[Message]] {.async.} =
    ## Executes a slack webhook.
    var ep = endpointWebhookTokenSlack(webhook_id, token) & "?wait=" & $wait
    var rawResult: JsonNode
    if thread_id.isSome: ep &= "&thread_id=" & thread_id.get
    rawResult = (await api.request("POST", ep))
    if wait: return some rawResult.newMessage else: return none Message

proc executeGithubWebhook*(api: RestApi, webhook_id, token: string;
        wait = true;thread_id = none string): Future[Option[Message]] {.async.} =
    ## Executes a github webhook.
    var ep = endpointWebhookTokenSlack(webhook_id, token) & "?wait=" & $wait
    var rawResult: JsonNode
    if thread_id.isSome: ep &= "&thread_id=" & thread_id.get
    rawResult = (await api.request("POST", ep))
    if wait: return some rawResult.newMessage else: return none Message

proc getSticker*(api: RestApi, sticker_id: string): Future[Sticker] {.async.} =
    result = (await api.request("GET", endpointStickers(sticker_id))).newSticker

proc getNitroStickerPacks*(api: RestApi): Future[seq[StickerPack]] {.async.} =
    result = (await api.request(
        "GET",
        endpointStickerPacks()
    )).elems.map(newStickerPack)

proc getThreadMembers*(api: RestApi;
        channel_id: string): Future[seq[ThreadMember]] {.async.} =
    ## List thread members.
    ## Note: This endpoint requires the `GUILD_MEMBERS` Privileged Intent 
    ## if not enabled on your application.
    result = (await api.request(
        "GET",
        endpointChannelThreadsMembers(channel_id)
    )).getElems.mapIt(($it).fromJson(ThreadMember))

proc removeThreadMember*(api: RestApi;
        channel_id, user_id: string;
        reason = "") {.async.} =
    ## Remove thread member.
    discard await api.request(
        "DELETE",
        endpointChannelThreadsMembers(channel_id, user_id),
        audit_reason = reason
    )

proc addThreadMember*(api: RestApi;
        channel_id, user_id: string;
        reason = "") {.async.} =
    ## Adds a thread member.
    discard await api.request(
        "PUT",
        endpointChannelThreadsMembers(channel_id, user_id),
        audit_reason = reason
    )

proc getThreadMember*(api: RestApi;
        channel_id, user_id: string) {.async.} =
    ## Get a thread member.
    discard await api.request(
        "GET",
        endpointChannelThreadsMembers(channel_id, user_id)
    )

proc leaveThread*(api: RestApi; channel_id: string) {.async.} =
    ## Leave thread.
    discard await api.request(
        "DELETE",
        endpointChannelThreadsMembers(channel_id, "@me")
    )

proc joinThread*(api: RestApi; channel_id: string) {.async.} =
    ## Join thread.
    discard await api.request(
        "PUT",
        endpointChannelThreadsMembers(channel_id, "@me")
    )

proc startThreadWithMessage*(api: RestApi,
    channel_id, message_id, name: string;
    auto_archive_duration: range[60..10080];
    reason = ""
): Future[GuildChannel] {.async.} =
    ## Starts a public thread.
    ## - `auto_archive_duration` Duration in mins. Can set to: 60 1440 4320 10080
    assert name.len in 1..100
    result = (await api.request(
        "POST",
        endpointChannelMessagesThreads(channel_id, message_id),
        $(%*{
            "name": name,
            "auto_archive_duration": auto_archive_duration
        }),
        audit_reason = reason
    )).newGuildChannel