import dimscord, asyncdispatch, json, sequtils

let discord = newDiscordClient(
    "<your bot token goes here>",
    rest_mode = true
)

let
    testing = (id: "571779270498713603", msg: "724649362088525914")
    announcements = (id: "576419090512478228", msg: "576420262426443788")

let messages = waitFor discord.api.getChannelMessages( # Get messages after
    testing.id, after = testing.msg # the id provided.
)
echo messages.mapIt(it.id)

let users = waitFor discord.api.getMessageReactions( # Get users that reacted.
    announcements.id, announcements.msg, "🇪"
)
echo users.mapIt(it[])

when defined(sendMsg): # NOTE: This may not work for you, because this endpoint
    discard waitFor discord.api.sendMessage( # requires your bot to connect to
        testing.id, "just testing here dont mind meh" # the gateway at least once.
    )