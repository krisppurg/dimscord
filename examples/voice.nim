import dimscord, asyncdispatch, times, options, strutils, tables

const token {.strdefine.} = "<your bot token goes here or use -d:token=(yourtoken)>"
let discord = newDiscordClient(token)

proc onReady(s: Shard, r: Ready) {.event(discord).} =
    echo "Ready as " & $r.user
    echo "Joining voice"

proc messageCreate(s: Shard, m: Message) {.event(disord).} =
    if m.startsWith("!playmusic"):
        var voiceChannelID: string = "" # TODO: Find users voice channel
        await s.voiceStateUpdate(m.guildID, some voiceClient)
        await sleepAsync(2000)
        let voiceClient = s.voiceConnections[guildID]
        voiceClient.voiceEvents.onReady = proc (v: VoiceClient) {.async.} =
            echo "Playing audio"
            await v.playFFmpeg("kayne.mp3")
        asyncCheck voiceClient.startSession()

proc messageCreate(s: Shard, m: Message) {.event(discord).} =
    if m.author.bot: return
    discard await cmd.handleMessage("!", s, m)



# Connect to Discord and run the bot.
waitFor discord.startSession()