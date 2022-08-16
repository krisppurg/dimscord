import dimscord, asyncdispatch, json

let discord = newDiscordClient("<your bot token goes here>")
var expected: string

proc onDispatch(s: Shard, evt: string, data: JsonNode) {.event(discord).} =
    if evt == "MESSAGE_CREATE": # if event is message create
        if data["content"].str == "!raw":
            let msg = await discord.api.sendMessage(
                data["channel_id"].str, "THIS DATA IS RAW!!"
            )
            expected = msg.id
    elif evt == "MESSAGE_REACTION_ADD": # if event is message reaction add
        if expected == data["message_id"].str: # we would need to check,
            if data["emoji"]["name"].str == "🍗": # if they have reacted '🍗'
                expected = "" # This needs to be empty so it won't react again
                await discord.api.addMessageReaction(
                    data["channel_id"].str,
                    data["message_id"].str,
                    data["emoji"]["name"].str
                )

waitFor discord.startSession(
    gateway_intents = {giGuilds, giGuildMessages, giGuildMessageReactions, giMessageContent}
)
