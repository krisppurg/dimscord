import httpclient, mimetypes, asyncdispatch, options
import ../objects, ../constants
import tables, os, json, sequtils
import uri, ../helpers, requester

proc sendMessage*(api: RestApi, channel_id: string;
        content = ""; tts = false;
        nonce: Option[string] or Option[int] = none(int);
        files = newSeq[DiscordFile]();
        embeds = newSeq[Embed]();
        allowed_mentions = none AllowedMentions;
        message_reference = none MessageReference,
        components = newSeq[MessageComponent](),
        sticker_ids = newSeq[string]()): Future[Message] {.async.} =
    ## Sends a Discord message.
    ## - `nonce` This can be used for optimistic message sending
    assert content.len in 0..2000
    assert sticker_ids.len in 0..3
    let payload = %*{
        "content": content,
        "tts": tts,
    }
    if message_reference.isSome:
        payload["message_reference"] = %*{"fail_if_not_exists": true}

    if sticker_ids.len > 0: payload["sticker_ids"] = %sticker_ids
    if embeds.len > 0: payload["embeds"] = %embeds

    payload.loadOpt(allowed_mentions, nonce, message_reference)

    if components.len > 0:
        payload["components"] = newJArray()
        for component in components:
            payload["components"].add %%*component

    if files.len > 0:
        var mpd = newMultipartData()
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
        embeds = newSeq[Embed](),
        components = newSeq[MessageComponent]()): Future[Message] {.async.} =
    ## Edits a discord message.
    assert content.len <= 2000
    let payload = %*{
        "content": content,
        "tts": tts,
        "flags": %flags
    }

    if embeds.len > 0:
        payload["embeds"] = %embeds

    if components.len > 0:
        payload["components"] = newJArray()
        for component in components:
            payload["components"] &= %%*component

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
    assert message_ids.len >= 100
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
        content = ""; tts = false;
        file = none DiscordFile;
        embeds = newSeq[Embed]();
        allowed_mentions = none AllowedMentions;
        username, avatar_url = none string,
        components = newSeq[MessageComponent]()): Future[Message] {.async.} =
    ## Executes a webhook or create a followup message.
    ## If `wait` is `false` make sure to `discard await` it.
    ## - `webhook_id` can be used as application id
    ## - `webhook_token` can be used as interaction token
    
    var url = endpointWebhookToken(webhook_id, webhook_token) & "?wait=" & $wait
    if thread_id.isSome: url &= "&thread_id=" & thread_id.get
    let payload = %*{
        "content": content,
        "tts": tts
    }

    payload.loadOpt(username, avatar_url, allowed_mentions)

    if embeds.len > 0:
        payload["embeds"] = %embeds

    if components.len > 0:
        payload["components"] = newJArray()
        for component in components:
            payload["components"].add %%*component

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

proc editWebhookMessage*(api: RestApi;
        webhook_id, webhook_token, message_id: string;
        content = none string;
        embeds = newSeq[Embed]();
        allowed_mentions = none AllowedMentions;
        attachments = newSeq[Attachment]();
        components = newSeq[MessageComponent]()) {.async.} =
    ## Modifies the webhook message.
    ## You can actually use this to modify
    ## original interaction or followup message.
    ##
    ## - `webhook_id` can also be application_id
    ## - `webhook_token` can also be interaction token.
    ## - `message_id` can be `@original`
    let payload = %*{
        "content": %content,
        "embeds": %embeds,
        "allowed_mentions": %(%allowed_mentions)
    }
    if attachments.len > 0:
        payload["attachments"] = newJArray()
        for attachment in attachments:
            payload["attachments"].add %*attachment        

    if components.len > 0:
        payload["components"] = newJArray()
        for component in components:
            payload["components"].add %%*component

    discard await api.request(
        "PATCH",
        endpointWebhookMessage(webhook_id, webhook_token, message_id),
        $payload
    )

proc deleteWebhookMessage*(api: RestApi;
        webhook_id, webhook_token, message_id: string) {.async.} =
    ## Modifies the webhook message.
    ## You can actually use this to delete
    ## original interaction or followup message.
    ##
    ## - `webhook_id` can also be application_id
    ## - `webhook_token` can also be interaction token.
    discard await api.request("DELETE",
        endpointWebhookMessage(webhook_id, webhook_token, message_id)
    )

proc executeSlackWebhook*(api: RestApi, webhook_id, token: string;
        wait = true): Future[Message] {.async.} =
    ## Executes a slack webhook.
    ## If `wait` is `false` make sure to `discard await` it.
    result = (await api.request(
        "POST",
        endpointWebhookTokenSlack(webhook_id, token) & "?wait=" & $wait
    )).newMessage

proc executeGithubWebhook*(api: RestApi, webhook_id, token: string;
        wait = true): Future[Message] {.async.} =
    ## Executes a github webhook.
    ## If `wait` is `false` make sure to `discard await` it.
    result = (await api.request(
        "POST",
        endpointWebhookTokenGithub(webhook_id, token) & "?wait=" & $wait
    )).newMessage

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
    )).getElems.map(proc (x: JsonNode): ThreadMember =
        x.to(ThreadMember)
    )

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