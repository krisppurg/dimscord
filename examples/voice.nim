import dimscord, asyncdispatch, times, options, strutils, tables
import std/with
##[
  In this example, the bot will accept these commands

   * !playMusic <url>: Will play url in the voice channel that the user is connected to
   * !pause: Will pause the current music
   * !unpause: Will play the current music
   * !stop: Will stop the music and the bot will disconnect

  This example is very basic and should not be used in production, more checks
  need to be done for it to be more production ready
]##
const
  defaultTokenMsg = "<your bot token goes here or use -d:token=(yourtoken)>"
  token {.strdefine.} = defaultTokenMsg
doAssert token != defaultTokenMsg, defaultTokenMsg

let discord = newDiscordClient(token)

type
  VoiceSession = ref object
    ## A voice session is the context of being in a voice channel
    url: string
    playing: bool
    client: VoiceClient

var voiceSessions: Table[string, VoiceSession] # Mapping of channel to session

proc onReady(s: Shard, r: Ready) {.event(discord).} =
    echo "Ready as " & $r.user

proc onVoiceReady(client: VoiceClient) {.async.} =
  let session = voiceSessions[client.channelID]
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

  try:
    await session.client.startSession()
  except:
    echo "Voice disconnected before session could start"

template getMemberState(m: Message, body: untyped) =
  ## Injects the members voice state if it exists
  ## else it sends a message telling them to join a channel
  if m.member.isSome and m.member.get().voiceState.isSome:
    let voiceState {.inject.} = m.membe.get().voiceState.get()
    body
  else:
    discard await discord.api.sendMessage(
      m.channelID,
      "Please connect to a voice channel first"
    )

template withVoiceSession(body: untyped) =
  ## Injects the VoiceSession_ if it exists
  if voiceSessions.hasKey(voiceState.channelID):
    let session {.inject.} = voiceSessions[voiceState.channelID]
    body
  else:
    discard await discord.api.sendMessage(
      m.channelID,
      "Please play some music first"
    )

proc messageCreate(s: Shard, m: Message) {.event(discord).} =
  if m.member.isSome and m.member.get().voiceState.isSome:
    let voiceState = m.member.get().voiceState.get()
    var params = m.content.split(" ")

    case params[0]:
    of "!playmusic":
      var newSession = VoiceSession()
      newSession.url = params[1]
      voiceSessions[voiceState.channelID] = newSession
      await s.voiceStateUpdate(m.guildID, some voiceState.channelID)

    of "!pause":
      withVoiceSession:
        session.playing = false
        discard await discord.api.sendMessage(
          m.channelID,
          "Music is now paused"
        )

    of "!unpause":
      withVoiceSession:
        session.playing = true
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

  else:
    discard await m.sendMessage(
      m.channelID,
      "Please connect to a voice channel first"
    )

# Connect to Discord and run the bot.
waitFor discord.startSession()
