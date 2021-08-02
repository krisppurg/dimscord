import dimscord, asyncdispatch, strutils, sequtils, options, tables
const token {.strdefine.} = "<your bot token goes here or use -d:token=(yourtoken)>"
let discord = newDiscordClient(token)

proc messageCreate(s: Shard, m: Message) {.event(discord).} =
    let content = m.content
    if m.author.bot or not content.startsWith("$$"): return
    var row = newActionRow()
    case content.replace("$$", "").toLowerAscii():
        of "button":
            row &= newButton("click me!", "btnClick")
        of "menu":
            row &= newSelectMenu("slmColours", @[
                newMenuOption("Red", "red", emoji = Emoji(name: some ":fire:")),
                newMenuOption("Green", "green"),
                newMenuOption("Blue", "blue")
            ])
    if row.len > 0:
        discard await discord.api.sendMessage(m.channelID, "hello", components = @[row])

proc onReady(s: Shard, r: Ready) {.event(discord).} =
    echo "Ready as: " & $r.user

# Connect to Discord and run the bot.
waitFor discord.startSession()
