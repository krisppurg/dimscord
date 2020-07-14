import dimscord, asyncdispatch, strutils, sequtils, options, tables
let discord = newDiscordClient("<your bot token goes here>") 

discord.events.on_ready = proc (s: Shard, r: Ready) {.async.} =
    echo "Ready as: " & $r.user

    await s.updateStatus(game = some GameStatus(
        name: "around.",
        kind: gatPlaying
    ), status = "idle")

discord.events.message_create = proc (s: Shard, m: Message) {.async.} =
    let args = m.content.split(" ") # Splits a message.
    if m.author.bot or not args[0].startsWith("$$"): return
    let command = args[0][2..args[0].high]

    case command.toLowerAscii():
    of "test": # Sends a basic message.
        discard await discord.api.sendMessage(m.channel_id, "Success!")
    of "deletemsg": # Deletes a message.
        if s.cache.kind(m.channel_id) == ctDirect: return

        let guild = s.cache.guilds[m.guild_id.get]
        let chan = s.cache.guildChannels[m.channel_id]
        let perms = guild.computePerms(guild.members[m.author.id], chan)
        let pobj = PermObj(allowed: {permManageMessages})

        if not cast[int](pobj.allowed).permCheck(pobj):
            discard await discord.api.sendMessage(
                m.channel_id, "you can't do that command!")
            return
        try:
            let messages = await discord.api.getChannelMessages(
                m.channel_id,
                limit = 2
            )
            await discord.api.bulkDeleteMessages(
                m.channel_id,
                messages.mapIt(it.id)
            )
        except:
            echo "An error occurred when deleting a message."
            echo getCurrentExceptionMsg()
    of "facepalm": # Sends a facepalm image.
        discard await discord.api.sendMessage(m.channel_id, "smh",
            files = some @[DiscordFile(
                name: "facepalm.png"
            )]
        )
    of "help": # Sends help.
        discard await discord.api.sendMessage(
            m.channel_id,
            "`test, echo, facepalm, deletemsg` are the commands."
        )
    of "echo": # Copies your text.
        var text = args[1..args.high].join(" ")
        if text == "":
            text = "Empty text."
        discard await discord.api.sendMessage(m.channel_id, text)
    else:
        discard

discord.events.message_delete = proc (s: Shard, m: Message,
        exists: bool) {.async.} =
    echo "A wild message has been deleted!"

waitFor discord.startSession()