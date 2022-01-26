import dimscord, asyncdispatch, times, options, strutils, tables
import std/with
##[
  In this example, the bot will accept these commands

   * !playMusic <url>: Will play url in the voice channel that the user is connected to
   * !pause: Will pause the current music
   * !unpause: Will play the current music
   * !stop: Will stop the music and the bot will disconnect

  This example is very basic and should not be used in production
]##
const
  defaultTokenMsg = "<your bot token goes here or use -d:token=(yourtoken)>"
  token {.strdefine.} = defaultTokenMsg
static:
  doAssert token != defaultTokenMsg, defaultTokenMsg

let discord = newDiscordClient(token)

type
  VoiceSession = ref object
    ## A voice session is the context of being in a voice channel
    url: string
    client: VoiceClient

# We will store all the sessions in a global table so that we can
# easily pass state around
var voiceSessions: Table[string, VoiceSession]

proc onReady(s: Shard, r: Ready) {.event(discord).} =
    echo "Ready as " & $r.user

proc onVoiceReady(client: VoiceClient) {.async.} =
  let session = voiceSessions[client.guildID]
  echo "Playing, ", session.url
  await client.playYTDL(session.url)

proc onVoiceDisconnect(client: VoiceClient) {.async.} =
  voiceSessions.del client.channelID

proc voiceServerUpdate(s: Shard, g: Guild, token: string,
                       endpoint: Option[string]) {.event(discord).} =

  let session = voiceSessions[g.id]
  session.client = s.voiceConnections[g.id]
  with session.client.voiceEvents:
    onReady = onVoiceReady
    onDisconnect = onVoiceDisconnect

  await session.client.startSession()

template getMemberState(m: Message, body: untyped) =
  ## Injects the members voice state if it exists
  ## else it sends a message telling them to join a channel
  if m.member.isSome and m.member.get().voiceState.isSome:
    let voiceState {.inject.} = m.member.get().voiceState.get()
    body
  else:
    discard await discord.api.sendMessage(
      m.channelID,
      "Please connect to a voice channel first"
    )

template withVoiceSession(body: untyped) {.dirty.} =
  ## Injects the VoiceSession_ if it exists
  let channelID = voiceState.channelID.get()
  voiceSessions.withValue(guildID, session):
    body
  do:
    discard await discord.api.sendMessage(
      m.channelID,
      "Please play some music first"
    )

proc getGuildCached(s: Shard, guildID: string): Future[Guild] {.async.} =
  s.cache.guilds.withValue(guildID, guild):
    result = guild[]
  do:
    result = await discord.api.getGuild(guild_id)
import sequtils
proc messageCreate(s: Shard, m: Message) {.event(discord).} =
  if m.author.bot: return
  echo m.member.get()[]
  if m.guildID.isSome:
    let
      guildID = m.guildID.get()

      guild = await s.getGuildCached(guildID)
      user = m.author
    guild.voiceStates.withValue(user.id, voiceState):
      var params = m.content.split(" ")

      case params[0]:
      of "!playmusic":
        var newSession = VoiceSession()
        newSession.url = params[1]
        voiceSessions[guildID] = newSession
        await s.voiceStateUpdate(guildID, voiceState.channelID)

      of "!pause":
        withVoiceSession:
          session.client.paused = true
          discard await discord.api.sendMessage(
            m.channelID,
            "Music is now paused"
          )

      of "!unpause":
        withVoiceSession:
          session.client.paused = false
          discard await discord.api.sendMessage(
            m.channelID,
            "Music is playing again"
          )

      of "!stop":
        withVoiceSession:
          await session.client.disconnect()
          discard await discord.api.sendMessage(
            m.channelID,
            "Music is now stopped"
          )

    do:
      discard await discord.api.sendMessage(
        m.channelID,
        "Please connect to a voice channel first"
      )

# Connect to Discord and run the bot.
waitFor discord.startSession()
