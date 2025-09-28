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
                kind: atUser, # You right click on user and you'll eventually see the option in the Apps section
                contexts: some @[ictGuild, ictBotDm],              # Fyi: these options are very useful and you can change them based
                integration_types: some @[aitUserInstall, aitGuildInstall], # on your preferred use-case.
            ),
            ApplicationCommand( # Echo a message back
                name: "Echo",
                kind: atMessage, # You right click on message and you'll eventually see the option in the Apps section
                contexts: some @[ictBotDm, ictPrivateChannel], # ictPrivateChannel if you want to annoy your friends
                integration_types: some @[aitUserInstall], # We can take this to DMs only.
            )
        ]
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

    await discord.api.interactionResponseMessage(i.id, i.token,
        kind = irtChannelMessageWithSource,
        response = InteractionCallbackDataMessage(
            content: msg
        )
    )

# Connect to Discord and run the bot.
waitFor discord.startSession(gateway_intents = {giMessageContent})
