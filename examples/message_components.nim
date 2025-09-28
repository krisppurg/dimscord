import dimscord, asyncdispatch, strutils, options, times

const token {.strdefine.} = "<your bot token goes here or use -d:token=(yourtoken)>"
let discord = newDiscordClient(token)

proc messageCreate(s: Shard, m: Message) {.event(discord).} =
    let content = m.content
    if m.author.bot or not content.startsWith("$$"): return
    case content.replace("$$", "").toLowerAscii():
    of "button", "menu":
        var row = newActionRow()

        if content.endsWith("button"):
            row &= newButton(
                label = "click me!",
                idOrUrl = "someUniqueID",
                emoji = >"🔥" # the `>` converts string to emoji object: Emoji(name: some "🔥")
            )
        else:
            row &= newSelectMenu("someUniqueID", @[
                newMenuOption("Red", "red", emoji = >"🔥"),
                newMenuOption("Green", "green"),
                newMenuOption("Blue", "blue")
            ])

        discard await discord.api.sendMessage(
            m.channel_id,
            "hello",
            components = @[row]
        )
        let iOpt = await discord.waitForComponentUse("someUniqueID").orTimeout(10.seconds)
        # Timed out, just ignore it.
        # You could send a message to the user, delete the components, etc
        if iOpt.isNone: return

        let
            i = iOpt.unsafeGet()
            data = i.data.unsafeGet()
        # Change the message depending on what the user used
        let msg = if data.componentType == mctSelectMenu: "You selected " & data.values[0]
                else: "You pressed the button"
        # Respond back to the interaction
        await discord.api.interactionResponseMessage(
            i.id, i.token,
            kind = irtChannelMessageWithSource,
            response = InteractionCallbackDataMessage(
                content: msg
            )
        )
    of "v2":
        discard await discord.api.sendMessage(m.channel_id, components = @[
            MessageComponent(
                kind: mctSection,
                sect_components: @[
                    TextDisplay(kind: mctTextDisplay, content: "this is"),
                    TextDisplay(kind: mctTextDisplay, content: "just"),
                    TextDisplay(kind: mctTextDisplay, content: "a test on message components v2"),
                ],
                accessory: MessageComponent(
                    kind: mctThumbnail,
                    description: some "My honest reaction",
                    media: UnfurledMediaItem(url: "attachment://facepalm.png"),
                    spoiler: some true,
                ),
            )],
            attachments = @[
                Attachment(filename: "facepalm.png", file: readFile("./facepalm.png"))
            ],
            flags = {mfIsComponentsV2},
        )
    else:
      # Message doesn't match, ignore
      return

proc onReady(s: Shard, r: Ready) {.event(discord).} =
    echo "Ready as: " & $r.user

# Connect to Discord and run the bot.
waitFor discord.startSession(gateway_intents={giMessageContent, giGuildMessages})
