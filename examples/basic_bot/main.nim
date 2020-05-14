import dimscord, asyncdispatch, times

let cl = newDiscordClient("<token>")

cl.events.on_ready = proc (s: Shard, r: Ready) = # Add Event Handler for on_ready.
  echo "Connected to Discord as " & $r.user

cl.events.message_create = proc (s: Shard, m: Message) = #  Add Event Handler for message_create.
  if m.author.bot: return
  if m.content == "!ping": # if message content is "!ping"
    let before = getTime().utc.toTime.toUnix
    let msg = waitFor cl.api.sendMessage(m.channel_id, "ping?")
    let after = getTime().utc.toTime.toUnix 
    asyncCheck cl.api.editMessage(m.channel_id, msg.id, "Pong! took " & $int(after - before) & "ms | " & $s.getPing() & "ms.") # Edit the message as pong! asyncCheck means that it  will only raise an exception if it fails.
  elif m.content == "!embed": # otherwise if content is embed
    asyncCheck cl.api.sendMessage(m.channel_id, embed = ?Embed( # Sends a messge with embed. The '?' symbol is a shorthand for 'some' in options.
      title: ?"Hello there!", 
      description: ?"This is a cool embed",
      color: ?5))

waitFor cl.startSession(compress=true)
