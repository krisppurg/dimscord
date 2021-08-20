import dimscord, asyncdispatch, strutils, sequtils, options, tables
const token {.strdefine.} = "<your bot token goes here or use -d:token=(yourtoken)>"
let discord = newDiscordClient(token)

proc interactionCreate(s: Shard, i: Interaction) {.event(discord).} =
    var msg = ""
    let data = i.data.get()
    if data.componentType == SelectMenu:
        msg = "You selected " & data.values[0]
    elif data.componentType == Button:
        msg = "You clicked the button"
    let response = InteractionResponse(
            kind: irtChannelMessageWithSource,
            data: some InteractionApplicationCommandCallbackData(
                content: msg
            )
        )
    await discord.api.createInteractionResponse(i.id, i.token, response)

proc messageCreate(s: Shard, m: Message) {.event(discord).} =
    let content = m.content
    if m.author.bot or not content.startsWith("$$"): return
    var row = newActionRow()
    case content.replace("$$", "").toLowerAscii():
        of "button":
            row &= newButton("click me!", "btnClick",  emoji = Emoji(name: some "🔥"))
        of "menu":
            row &= newSelectMenu("slmColours", @[
                newMenuOption("Red", "red", emoji = Emoji(name: some "🔥")),
                newMenuOption("Green", "green"),
                newMenuOption("Blue", "blue")
            ])
    if row.len > 0:
        discard await discord.api.sendMessage(m.channelID, "hello", components = @[row])

proc onReady(s: Shard, r: Ready) {.event(discord).} =
    echo "Ready as: " & $r.user

# Connect to Discord and run the bot.
waitFor discord.startSession()
