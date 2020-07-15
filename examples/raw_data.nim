import dimscord, asyncdispatch, json

let discord = newDiscordClient("<your bot token goes here>")
var expected: string

proc onDispatch(s: Shard, evt: string, data: JsonNode) {.async.} =
    if evt == "MESSAGE_CREATE":
        if data["content"].str == "!raw":
            let msg = await discord.api.sendMessage(
                data["channel_id"].str, "THIS DATA IS RAW!!"
            )
            expected = msg.id
    elif evt == "MESSAGE_REACTION_ADD":
        if expected == data["message_id"].str:
            if data["emoji"]["name"].str == "🍗":
                expected = ""
                await discord.api.addMessageReaction(
                    data["channel_id"].str,
                    data["message_id"].str,
                    data["emoji"]["name"].str
                )

discord.events.onDispatch = onDispatch

waitFor discord.startSession()