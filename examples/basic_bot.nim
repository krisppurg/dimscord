import ../dimscord, asyncdispatch, os, strutils, sequtils
let cl = newDiscordClient("<your bot token goes here>") 

cl.events.on_ready = proc (s: Shard, r: Ready) {.async.} =
    echo "Ready as: " & $r.user
    await cl.updateStatus(game = ?GameStatus(
        name: "with Nim.", kind: gatPlaying), status="idle")

cl.events.message_create = proc (s: Shard, m: Message) {.async.} =
    let args = m.content.split(" ") # Splits a message.
    if m.author.bot or not args[0].startsWith("$$"): return
    let command = args[0][2..args[0].high]

    case command.toLowerAscii():
    of "test": # Sends a basic message.
        discard await cl.api.sendMessage(m.channel_id, "Success!")
    of "deletemsg": # Deletes a message.
        if cl.cache.kind(m.channel_id) == ctDirect:
            discard await cl.api.sendMessage(m.channel_id, "I can't do that command!")
        try:
            var messages = await cl.api.getChannelMessages(m.channel_id, limit = 2)
            await cl.api.bulkDeleteMessages(m.channel_id, messages.mapIt(it.id))
        except:
            echo "An error occurred when deleting a message."
            echo getCurrentExceptionMsg()
    of "facepalm": # Sends a facepalm image.
        discard await cl.api.sendMessage(m.channel_id, "hello", files = ?(@[DiscordFile(
            body: "https://www.google.co.uk/url?sa=i&url=https%3A%2F%2Fknowyourmeme.com%2Fmemes%2Ffacepalm&psig=AOvVaw22sed3su41CKE9j0DhcArI&ust=1588072580944000&source=images&cd=vfe&ved=0CAIQjRxqFwoTCNiy2cK9iOkCFQAAAAAdAAAAABAE"
        )]))
    of "help": # Sends help.
        discard await cl.api.sendMessage(m.channel_id, "`test, echo, deletemsg` are the commands.")
    of "echo": # Copies your text.
        let text = args[1..args.high].join(" ")
        discard await cl.api.sendMessage(m.channel_id, text)
    else:
        discard

cl.events.message_delete = proc (s: Shard, m: Message, exists: bool) {.async.} =
    echo "A wild message has been deleted!"

waitFor cl.startSession()