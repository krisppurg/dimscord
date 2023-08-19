import dimscord, asyncdispatch, strutils, sequtils, options, tables

# In order to enable helper procs, use the `mainClient` pragma to register your client.
let discord {.mainClient.} = newDiscordClient("<your bot token goes here or use -d:token=(yourtoken)>")

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
    of "hello": # Basic Messaging
        let msg = await ch.send("Hey, how's your day ?")

        for emj in ["😁", "😩", "😎"]:
            await msg.react(emj) 
      
    of "highfive": # Simple reply
        await! m.reply("🖐", mention = true)

    of "counter": # Simple Interaction
        let btns = newActionRow @[
            newButton(label = "+", idOrUrl = "addBtn", style = Primary),
            newButton(label = "-", idOrUrl = "subBtn", style = Danger)
        ]

        asyncCheck m.reply(
          "Current Count: 0",
          components = @[btns]
        )

proc interactionCreate(s: Shard, i: Interaction) {.event(discord).} =
    let 
        data = i.data.get()
        msg = await i.getResponse()

    var 
        text = msg.content.split(" ")
        num = text[2].parseInt()

    case data.custom_id
    of "addBtn":
        await i.update(
            "Current Count: " & $(num + 1), 
            components = i.data.get.components
        )
    of "subBtn":
        await i.update(
            "Current Count: " & $(num - 1), 
            components = i.data.get.components
        )    
    else:
        discard

waitFor discord.startSession(
    gateway_intents = {giGuildMessages, giGuilds, giGuildMembers, giMessageContent}
)
