import dimscord, asyncdispatch, strutils, sequtils, options, tables
const token {.strdefine.} = "<your bot token goes here or use -d:token=(yourtoken)>"
let discord = newDiscordClient(token)

proc messageCreate(s: Shard, m: Message) {.event(discord).} =
    let content = m.content
    if m.author.bot or not content.startsWith("$$"): return
    var components: seq[MessageComponent]
    case content.replace("$$", "").toLowerAscii():
        of "button":
            components = @[MessageComponent(
                kind: ActionRow,
                components: @[MessageComponent(
                    kind: Button,
                    label: some "Press me",
                    style: some Primary,
                    customID: some "foobar" # Used to identify it later
                )]
            )]
        of "menu":
            components = @[MessageComponent(
                kind: ActionRow,
                components: @[MessageComponent(
                    kind: SelectMenu,
                    placeholder: some "Select colour",
                    customID: some "colourSelect",
                    options: @[
                        SelectMenuOption(
                            label: "Red",
                            value: "red"
                        ),
                        SelectMenuOption(
                            label: "Green",
                            value: "green"
                        ),
                        SelectMenuOption(
                            label: "Blue",
                            value: "blue"
                        )
                    ]
                )]
            )]
    echo components.len
    if components.len > 0:
        discard await discord.api.sendMessage(m.channelID, "hello", components = components)

proc onReady(s: Shard, r: Ready) {.event(discord).} =
    echo "Ready as: " & $r.user

# Connect to Discord and run the bot.
waitFor discord.startSession()
