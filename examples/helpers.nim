import dimscord, asyncdispatch, strutils, sequtils, options, tables, sugar, json

# In order to enable helper procs, use the `mainClient` pragma to register your client.
const token {.strdefine.} = "your bot token goes here or use -d:token=yourtoken"

let discord {.mainClient.} = newDiscordClient(token)

template `!`(awt, code: untyped): auto =
    # simple template to discard awaited results
    discard awt code

proc messageCreate(s: Shard, m: Message) {.event(discord).} =
    let args = m.content.split(" ")
    if m.author.bot or not args[0].startsWith("$$"): return

    let # Simple getters
        cmd = args[0][2..args[0].high].toLowerAscii()
        g = s.cache.guilds[m.guild_id.get]
        ch = g.channels[m.channel_id]

    case cmd
    of "highfive": # Simple reply/edit
        let msg = await m.reply("🖐", mention = true)
        await sleepAsync(1000)
        await! msg.edit("🤙")

    of "hello": # Basic Messaging
        let msg = await ch.send("Hey, how's your day ?")

        for emj in ["😁", "😩", "😎"]:
            await msg.react(emj) 

        let emoji = await discord.waitForReaction(msg, m.author) # helper to wait for reactions on a message

        case $emoji
        of "😁":
            await! ch.send("Today is a nice day, indeed " & @(m.author))
        of "😩":
            await! ch.send("Best of luck, champ " & @(m.author))
        of "😎":
            await! ch.send("I see you're having one heck of a day " & @(m.author))

    of "waitfor": # Basic event waiting
        await! m.reply("Waiting for an answer [y/n]...")

        var msg = await discord.waitFor(MessageCreate) do (msg: Message) -> bool:
            echo msg.content.toLowerAscii
            if (msg.channel_id == m.channel_id) and (msg.author.id == m.author.id):
                return msg.content.toLowerAscii in ["yes", "no"]
   
        case msg.content
        of "yes":
            await! m.reply("You've said yes!")
        of "no":
            await! m.reply("You've said no!")

    of "counter": # Basic Interaction
        let btns = newActionRow @[
            newButton(label = "+", idOrUrl = "addBtn", style = Primary),
            newButton(label = "-", idOrUrl = "subBtn", style = Danger)
        ]

        await! m.reply(
          "Current Count: 0",
          components = @[btns]
        )

    of "game": # waitForRaw & withTimeout demo
        let rep = await m.reply("Try to send 3 messages in 5 seconds ! 🕙")
        var counter: int # waitForRaw will always be false until counter is equal to 3

        let wait = discord.waitForRaw("MESSAGE_CREATE") do (data: JsonNode) -> bool: # notice we dont `await` the `waitForRaw` because we're using `withTimeout`
            if (data["channel_id"].str == m.channel_id) and (data["author"]["id"].str == m.author.id):
                counter += 1
                return (counter == 3)
        
        if (await wait.withTimeout(5 * 1000)):
            await! rep.edit("You won the game!")
        else:
            await! rep.edit("You lost the game!")


proc interactionCreate(s: Shard, i: Interaction) {.event(discord).} =
    let 
        data = i.data.get()
        msg = await i.getResponse()

    var 
        text = msg.content.split(" ")
        num = text[2].parseInt()

    await i.deferResponse(hide = true)
    case data.custom_id
    of "addBtn":
        await! i.edit(
            some "Current Count: " & $(num + 1)
        )
    of "subBtn":
        await! i.edit(
            some "Current Count: " & $(num - 1)
        )    



waitFor discord.startSession(
    gateway_intents = {giGuildMessages, giGuilds, giGuildMembers, giMessageContent, giDirectMessageReactions, giGuildMessageReactions}
)
