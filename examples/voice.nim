import dimscord, asyncdispatch, options, strutils, tables
##[
  In this example, the bot will accept these commands

   * !playmusic <url>: Will play url in the voice channel that the user is connected to
   * !pause: Will pause the current music
   * !resume: Will play the current music
   * !stop: Will stop the music and the bot will disconnect

  This example is basic and should not be used in production
]##
const
    defaultTokenMsg = "<your bot token goes here or use -d:token=(yourtoken)>"
    token {.strdefine.} = defaultTokenMsg

let discord = newDiscordClient(token)

var voicesessions: Table[string, tuple[chanID: string, ready: bool]]

proc onReady(s: Shard, r: Ready) {.event(discord).} =
    echo "ready as " & $s.user

proc voiceServerUpdate(s: Shard, g: Guild, token: string;
        endpoint: Option[string]; initial: bool) {.event(discord).} =
    let vc = s.voiceConnections[g.id]

    vc.voice_events.on_ready = proc (v: VoiceClient) {.async.} =
        voicesessions[g.id].ready = true

    vc.voice_events.on_speaking = proc (v: VoiceClient, s: bool) {.async.} =
        if not s and v.sent == 0 and voicesessions[g.id].chanID != "":
            discard await discord.api.sendMessage(
                voicesessions[g.id].chanID, "Music ended."
            )
    when defined(dimscordVoice): await vc.startSession()

when defined(dimscordVoice): # this would only work if you defined dimscordVoice
    proc messageCreate(s: Shard, m: Message) {.event(discord).} =
        if m.author.bot: return
        if m.guild_id.isNone: return

        let args = m.content.split(" ")
        let command = args[0]
        case command:
        of "!playmusic":
            let g = s.cache.guilds[m.guildID.get]
            if m.author.id notin g.voiceStates:
                discard await discord.api.sendMessage(
                    m.channelID,
                    "You're not connected to a voice channel"
                )
                return
            if m.guildID.get notin s.voiceConnections:
                await s.voiceStateUpdate(
                    guildID = m.guildID.get,
                    channelID = g.voiceStates[m.author.id].channelID,
                    selfDeaf = true
                )
                voicesessions[g.id] = (chanID: m.channelID, ready: false)

                while not voicesessions[g.id].ready:
                    await sleepAsync 1

            let vc = s.voiceConnections[m.guildID.get]
            let link = args[1]
            discard await discord.api.sendMessage(m.channelID, "Playing music")

            await vc.playYTDL(link)
        of "!pause":
            if m.guildID.get notin s.voiceConnections: return
            let vc = s.voiceConnections[m.guildID.get]
            if not vc.ready: return
            vc.pause()

            discard await discord.api.sendMessage(m.channelID, "Music paused.")
        of "!resume":
            if m.guildID.get notin s.voiceConnections: return
            let vc = s.voiceConnections[m.guildID.get]
            if not vc.ready: return
            vc.resume()

            discard await discord.api.sendMessage(m.channelID, "Music resumed.")
        of "!stop":
            if m.guildID.get notin s.voiceConnections: return
            let vc = s.voiceConnections[m.guildID.get]
            if not vc.ready: return
            vc.stopped = true
            voicesessions[m.guildID.get].ready = false
            await s.voiceStateUpdate( # if channelID is none then we would disconnect
                guildID=m.guildID.get,
                channelID=none string
            )

            discard await discord.api.sendMessage(
                m.channelID,
                "Left voice channel."
            )

waitFor discord.startSession(
    gateway_intents = {
        giMessageContent,
        giGuildVoiceStates,
        giGuildMessages,
        giGuilds,
        giGuildMembers
    }
)