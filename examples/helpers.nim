import dimscord, asyncdispatch, strutils, sequtils, options, tables, sugar

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
    of "highfive": # Simple reply
        await! m.reply("🖐", mention = true)

    of "hello": # Basic Messaging
        let msg = await ch.send("Hey, how's your day ?")

        for emj in ["😁", "😩", "😎"]:
            await msg.react(emj) 

        let emoji = await discord.waitForReaction(msg, m.author)

        case $emoji
        of "😁":
            await! ch.send("Today is a nice day, indeed " & @(m.author))
        of "😩":
            await! ch.send("Best of luck, champ " & @(m.author))
        of "😎":
            await! ch.send("I see you're having one heck of a day " & @(m.author))
        else:
            discard

    of "counter": # Simple Interaction
        let btns = newActionRow @[
            newButton(label = "+", idOrUrl = "addBtn", style = Primary),
            newButton(label = "-", idOrUrl = "subBtn", style = Danger)
        ]

        await! m.reply(
          "Current Count: 0",
          components = @[btns]
        )
        
        let i = await discord.waitFor(InteractionCreate) do (i: Interaction) -> bool:
            if (i.member.get.user.id == m.author.id) and (i.channel_id.get == m.channel_id):
                return true
            else:
                return false

        await i.deferResponse()

        let originalMsg = await i.getResponse()

        var 
            text = originalMsg.content.split(" ")
            num = text[2].parseInt()

        case i.data.get.custom_id
        of "addBtn":
            await i.edit(
                "Current Count: " & $(num + 1), 
                components = i.data.get.components
            )
        of "subBtn":
            await i.edit(
                "Current Count: " & $(num - 1), 
                components = i.data.get.components
            )    
        else:
            discard
            




waitFor discord.startSession(
    gateway_intents = {giGuildMessages, giGuilds, giGuildMembers, giMessageContent, giDirectMessageReactions, giGuildMessageReactions}
)
