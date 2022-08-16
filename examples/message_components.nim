import dimscord, asyncdispatch, strutils, options
const token {.strdefine.} = "<your bot token goes here or use -d:token=(yourtoken)>"
let discord = newDiscordClient(token)

proc interactionCreate(s: Shard, i: Interaction) {.event(discord).} =
    var msg = ""
    let data = i.data.get
    # You
    if data.custom_id == "slmColours":
        msg = "You selected " & data.values[0]
    elif data.custom_id == "btnClick":
        msg = "You clicked the button"

    await discord.api.interactionResponseMessage(
        i.id, i.token,
        kind = irtChannelMessageWithSource,
        response = InteractionCallbackDataMessage(
            content: msg
        )
    )

proc messageCreate(s: Shard, m: Message) {.event(discord).} =
    let content = m.content
    if m.author.bot or not content.startsWith("$$"): return
    var row = newActionRow()
    case content.replace("$$", "").toLowerAscii():
        of "button":
            row &= newButton(
                label = "click me!",
                idOrUrl = "btnClick",
                emoji = Emoji(name: some "🔥")
            )
        of "menu":
            row &= newSelectMenu("slmColours", @[
                newMenuOption("Red", "red", emoji = Emoji(name: some "🔥")),
                newMenuOption("Green", "green"),
                newMenuOption("Blue", "blue")
            ])
    if row.len > 0:
        discard await discord.api.sendMessage(
            m.channel_id,
            "hello",
            components = @[row]
        )

proc onReady(s: Shard, r: Ready) {.event(discord).} =
    echo "Ready as: " & $r.user

# Connect to Discord and run the bot.
waitFor discord.startSession()
