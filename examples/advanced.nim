import dimscord, asyncdispatch, strutils, sequtils, options, tables
let discord = newDiscordClient("<your bot token goes here>")

proc getGuildMember(s: Shard, guild, user: string): Future[Member] {.async.} =
    var
        member: Member
        waiting = true
    await s.requestGuildMembers(guild, presences = true, user_ids = @[user])

    discord.events.guild_members_chunk = proc (s: Shard,
        g: Guild, e: GuildMembersChunk) {.async.} =
        if e.members.len == 0:
            raise newException(Exception, "Member was not found.")

        member = e.members[0]
        if member == nil:
            raise newException(Exception, "Member was not found.")

        waiting = false

    while member == nil:
        poll()

    return member

proc messageCreate(s: Shard, m: Message) {.event(discord).} =
    let args = m.content.split(" ") # Splits a message.
    if m.author.bot or not args[0].startsWith("$$"): return
    let command = args[0][2..args[0].high]

    case command.toLowerAscii():
    of "test": # Sends a basic message.
        discard await discord.api.sendMessage(m.channel_id, "Success!")
    of "prune": # Prune messages.
        if m.member.isNone: return

        let
            guild = s.cache.guilds[m.guild_id.get]
            chan = s.cache.guildChannels[m.channel_id]
            memb = await s.getGuildMember(m.guild_id.get, m.author.id)
            perms = guild.computePerms(memb, chan)

        if permManageMessages notin perms.allowed:
            discard await discord.api.sendMessage(
                m.channel_id, "you can't do that command!")
            return
        try:
            let messages = await discord.api.getChannelMessages(
                m.channel_id,
                before = m.id,
                limit = max(2, if args.len == 1: 2 else: args[1].parseInt)
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
            files = @[DiscordFile(
                name: "facepalm.png"
            )]
        )
    of "help": # Sends help.
        discard await discord.api.sendMessage(
            m.channel_id,
            "`test, echo, facepalm, prune` are the commands."
        )
    of "echo": # Copies your text.
        var text = args[1..args.high].join(" ")
        if text == "":
            text = "Empty text."
        discard await discord.api.sendMessage(m.channel_id, text)
    else:
        discard

proc onReady(s: Shard, r: Ready) {.event(discord).} =
    echo "Ready as: " & $r.user

    await s.updateStatus(activity = some ActivityStatus(
        name: "around.",
        kind: atPlaying
    ), status = "idle")

proc messageDelete(s: Shard, m: Message, exists: bool) {.event(discord).} =
    echo "A wild message has been deleted!"

# Connect to Discord and run the bot.
waitFor discord.startSession(
    gateway_intents = {giGuildMessages, giGuilds, giGuildMembers, giMessageContent}
)
