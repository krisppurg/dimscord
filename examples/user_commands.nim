import dimscord, asyncdispatch, strutils, options
import tables
const token {.strdefine.} = "<your bot token goes here or use -d:token=(yourtoken)>"
let discord = newDiscordClient(token)

proc onReady(s: Shard, r: Ready) {.event(discord).} =
    discard await discord.api.bulkOverwriteApplicationCommands(
        s.user.id,
        @[
            ApplicationCommand( # Just say who they high fived
                name: "High Five",
                kind: atUser
            ),
            ApplicationCommand( # Echo a message back
                name: "Echo",
                kind: atMessage
            )
        ],
        guild_id = "479193574341214208"
    )

proc interactionCreate(s: Shard, i: Interaction) {.event(discord).} =
    let data = i.data.get
    var msg = ""
    if data.kind == atUser:
        for user in data.resolved.users.values: # Loop will only happen one
            msg &= "You have high fived " & user.username & "\n"
    elif data.kind == atMessage:
        for message in data.resolved.messages.values: # Same here
                msg &= message.content & "\n"
    let response = InteractionResponse(
        kind: irtChannelMessageWithSource,
        data: some InteractionApplicationCommandCallbackData(
            content: msg
        )
    )
    await discord.api.createInteractionResponse(i.id, i.token, response)

# Connect to Discord and run the bot.
waitFor discord.startSession()
