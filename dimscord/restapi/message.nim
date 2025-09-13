import httpclient, asyncdispatch, options
import ../objects, ../constants
import tables, os, json, sequtils
import uri, ../helpers, requester

proc sendMessage*(api: RestApi, channel_id: string;
        content = ""; tts = false;
        nonce: Option[string] or Option[int] = none(int);
        flags: set[MessageFlags] = {};
        files: seq[DiscordFile] = @[];
        embeds: seq[Embed] = @[];
        attachments: seq[Attachment] = @[];
        allowed_mentions = none AllowedMentions;
        message_reference = none MessageReference;
        components: seq[MessageComponent] = @[];
        sticker_ids: seq[string] = @[];
        poll = none PollRequest,
        enforce_nonce = none bool): Future[Message] {.async.} =
    ## Sends a Discord message.
    ## - `nonce` This can be used for optimistic message sending
    softAssert content.len in 0..2000, "Message too long to send :: "&($content.len)
    softAssert sticker_ids.len in 0..3
    var payload = %*{
        "content": content,
        "tts": tts,
    }
    if flags != {}: payload["flags"] = %cast[int](flags)

    if message_reference.isSome:
        var mf = %*{
            "type": int message_reference.get.kind,
            "fail_if_not_exists":message_reference.get.fail_if_not_exists.get true
        }
        if message_reference.get.channel_id.isSome:
            mf["channel_id"] = %message_reference.get.channel_id.get
        if message_reference.get.message_id.isSome:
            mf["message_id"] = %message_reference.get.message_id.get
        if message_reference.get.guild_id.isSome:
            mf["guild_id"] = %message_reference.get.guild_id.get

        payload["message_reference"] = mf

    if sticker_ids.len > 0: payload["sticker_ids"] = %sticker_ids
    if embeds.len > 0: payload["embeds"] = %embeds
    if poll.isSome:
        softAssert poll.get.duration in 1..768
        softAssert(poll.get.layout_type.int != 0,
            "Must include 'layout_type' field in PollRequest object or set value to plDefault.")
        payload["poll"] = %poll.get
        payload["poll"]["layout_type"] = %int(poll.get.layout_type)
    if enforce_nonce.isSome: payload["enforce_nonce"] = %enforce_nonce.get
    payload.loadOpt(allowed_mentions, nonce)

    if components.len > 0:
        payload["components"] = newJArray()
        for component in components:
            payload["components"].add %%*component

    var mpd: MultipartData

    if files.len > 0:
        mpd.append(files, payload)
    if attachments.len > 0:
        mpd.append(attachments, payload, is_interaction=false)

    result = (await api.request(
        "POST",
        endpointChannelMessages(channel_id),
        $payload,
        mp = mpd
    )).newMessage

proc editMessage*(api: RestApi, channel_id, message_id: string;
        content = ""; tts = false; flags: set[MessageFlags] = {};
        files: seq[DiscordFile] = @[];
        embeds: seq[Embed] = @[]; attachments: seq[Attachment] = @[];
        components: seq[MessageComponent] = @[]): Future[Message] {.async.} =
    ## Edits a discord message.
    softAssert content.len <= 2000
    var payload = %*{
        "content": content,
        "tts": tts,
    }
    if flags != {}:
        payload["flags"] = %cast[int](flags)

    var mpd: MultipartData

    if embeds.len > 0:
        payload["embeds"] = %embeds
    if components.len > 0:
        payload["components"] = newJArray()
        for component in components:
            payload["components"] &= %%*component

    if files.len > 0:
        mpd.append(files, payload)
    if attachments.len > 0:
        mpd.append(attachments, payload, is_interaction=false)

    result = (await api.request(
        "PATCH",
        endpointChannelMessages(channel_id, message_id),
        $payload,
        mp = mpd
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
        message_ids: seq[string] | seq[Message]; reason = "") {.async.} =
    ## Bulk deletes messages.
    template req(data: untyped) {.dirty.} =
        softAssert message_ids.len in 1..100
        discard await api.request(
            "POST",
            endpointBulkDeleteMessages(channel_id),
            $(%*{
                "messages": data
            }),
            audit_reason = reason
        )
    when message_ids is seq[string]:
        req(message_ids)
    elif message_ids is seq[Message]:
        var ids = newSeqOfCap[string](message_ids.len)
        for msg in message_ids:
            ids.add(msg.id)
        req(ids)


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
        kind = ReactionType.rtNormal;
        after = ""; limit: range[1..100] = 25): Future[seq[User]] {.async.} =
    ## Get all user message reactions on the emoji provided.
    var emj = emoji
    var url = endpointReactions(channel_id, message_id, e=emj, uid="@me") & "?"

    if emoji == decodeUrl(emoji):
        emj = encodeUrl(emoji)

    if after != "":
        url = url & "after=" & after & "&"

    url = url & "type=" & $kind & "&limit=" & $limit

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
        wait = true; with_components = false;
        thread_id, thread_name = none string;
        content = ""; tts = false; flags: set[MessageFlags] = {};
        files: seq[DiscordFile] = @[];
        attachments: seq[Attachment] = @[];
        embeds: seq[Embed] = @[];
        allowed_mentions = none AllowedMentions;
        username, avatar_url = none string;
        components: seq[MessageComponent] = @[];
        applied_tags: seq[string] = @[];
        poll = none PollRequest;
): Future[Option[Message]] {.async.} =
    ## Executes a webhook or create a followup message.
    ## - `webhook_id` can be used as application id
    ## - `webhook_token` can be used as interaction token
    ## - `flags` are only used for interaction responses
    softAssert embeds.len in 0..10

    var
        url = endpointWebhookToken(webhook_id,webhook_token) & "?wait=" & $wait
        rawResult: JsonNode
        mpd: MultipartData

    if thread_id.isSome: url &= "&thread_id=" & thread_id.get

    var payload = %*{
        "content": content,
        "tts": tts
    }

    if flags != {}: payload["flags"] = %*(cast[int](flags))

    payload.loadOpt(username, avatar_url,
        allowed_mentions,
        thread_id, thread_name)

    if embeds.len > 0: payload["embeds"] = %embeds
    if applied_tags.len > 0: payload["applied_tags"] = %applied_tags

    if components.len > 0:
        url &= "&with_components=true"
        payload["components"] = newJArray()
        for component in components:
            payload["components"].add %%*component
    elif with_components:
        url &= "&with_components=" & $with_components # user might use it for later

    if poll.isSome:
        softAssert poll.get.duration in 1..768
        softAssert(poll.get.layout_type.int != 0,
            "Must include 'layout_type' field in PollRequest object or set value to plDefault.")

        payload["poll"] = %poll.get
        payload["poll"]["layout_type"] = %int(poll.get.layout_type)

    if files.len > 0:
        mpd.append(files, payload)
    if attachments.len > 0:
        mpd.append(attachments, payload, is_interaction=false)

    rawResult = (await api.request("POST", url, $payload, mp = mpd))

    if wait:
        result = some rawResult.newMessage
    else:
        result = none Message

proc createFollowupMessage*(api: RestApi,
        application_id, interaction_token: string;
        content = ""; tts = false;
        files: seq[DiscordFile] = @[];
        attachments: seq[Attachment] = @[];
        embeds: seq[Embed] = @[];
        allowed_mentions = none AllowedMentions;
        components: seq[MessageComponent] = @[];
        flags: set[MessageFlags] = {};
        thread_id, thread_name = none string;
        applied_tags: seq[string] = @[];
        poll = none PollRequest;
        ): Future[Message] {.async.} =
    ## Create a followup message.
    ## - `flags` valid options: `{mfIsEphemeral, mfIsComponentsV2}` 
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
        applied_tags=applied_tags,
        thread_name=thread_name,
        thread_id=thread_id,
        poll = poll,
        wait = true
    ))

proc editWebhookMessage*(api: RestApi;
        webhook_id, webhook_token, message_id: string;
        content, thread_id = none string;
        embeds: seq[Embed] = @[];
        allowed_mentions = none AllowedMentions;
        attachments: seq[Attachment] = @[];
        flags: set[MessageFlags] = {};
        files: seq[DiscordFile] = @[];
        components: seq[MessageComponent] = @[]): Future[Message] {.async.} =
    ## Modifies the webhook message.
    ## You can actually use this to modify
    ## original interaction or followup message.
    ##
    ## - `webhook_id` can also be application_id
    ## - `webhook_token` can also be interaction token.
    ## - `message_id` can be `@original`
    softAssert embeds.len in 0..10
    var endpoint = endpointWebhookMessage(webhook_id, webhook_token, message_id)
    if thread_id.isSome: endpoint &= "?thread_id=" & thread_id.get

    var payload = %*{
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
        mpd.append(files, payload)
    if attachments.len > 0:
        mpd.append(attachments, payload, is_interaction=false)
    if flags != {}: payload["flags"] = %*(cast[int](flags))

    result = (await api.request("PATCH", endpoint, $payload, mp=mpd)).newMessage

proc editInteractionResponse*(api: RestApi;
        application_id, interaction_token: string;
        message_id: string = "@original";
        content = none string;
        embeds: seq[Embed] = @[];
        flags: set[MessageFlags] = {};
        allowed_mentions = none AllowedMentions;
        attachments: seq[Attachment] = @[];
        files: seq[DiscordFile] = @[];
        components: seq[MessageComponent] = @[]): Future[Message] {.async.} =
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
        flags = flags,
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
        channel_id: string;
        with_member = true): Future[seq[ThreadMember]] {.async.} =
    ## List thread members.
    ## Note: This endpoint requires the `GUILD_MEMBERS` Privileged Intent
    ## if not enabled on your application.
    result = (await api.request(
        "GET",
        endpointChannelThreadsMembers(channel_id)&"?with_member=" & $with_member
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
        channel_id, user_id: string;
        with_member = true): Future[ThreadMember] {.async.} =
    ## Get a thread member.
    result = (await api.request(
        "GET",
        endpointChannelThreadsMembers(channel_id,
            user_id) & "?with_member=" & $with_member
    )).`$`.fromJson(ThreadMember)

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
    softAssert name.len in 1..100
    result = (await api.request(
        "POST",
        endpointChannelMessagesThreads(channel_id, message_id),
        $(%*{
            "name": name,
            "auto_archive_duration": auto_archive_duration
        }),
        audit_reason = reason
    )).newGuildChannel

proc getPollAnswerVoters*(api: RestApi;
    channel_id, message_id, answer_id: string;
    after = none string; limit: range[1..100] = 25): Future[seq[User]] {.async.} =
    var endpoint = endpointChannelPollsAnswer(channel_id, message_id, answer_id)

    endpoint &= "?limit=" & $limit
    if after.isSome: endpoint &= "&after="&after.get

    result = (await api.request("GET", endpoint)).elems.map(newUser)

proc endPoll*(api: RestApi, channel_id, message_id: string) {.async.} =
    discard await api.request(
        "POST",
        endpointChannelPollsExpire(channel_id, message_id)
    )
