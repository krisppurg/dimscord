import dimscord, asyncdispatch, strutils, options, tables
let discord = newDiscordClient("")

proc getGuild(s: Shard, guild_id: string): Future[Guild] {.async.} =
    if guild_id in s.cache.guilds:
        return s.cache.guilds[guild_id]

    result = await discord.api.getGuild(guild_id)

proc getGuildChannel(s: Shard, chan_id: string): Future[GuildChannel] {.async.} =
    if chan_id in s.cache.guildChannels:
        return s.cache.guildChannels[chan_id]

    let channel = await discord.api.getChannel(chan_id)
    if channel[0].isNone:
        raise newException(Exception, "The channel is not a guild channel")
    result = channel[0].get

proc getUser(s: Shard, user_id: string): Future[User] {.async.} =
    if user_id in s.cache.users:
        return s.cache.users[user_id]

    result = await discord.api.getUser(user_id)

proc messageCreate(s: Shard, m: Message) {.event(discord).} =
    if m.content == "#!getguild": # Gets a guild from rest or cache
        discard await discord.api.sendMessage(
            m.channel_id, "Getting guild!"
        )
        let guild = await s.getGuild(get m.guild_id)
        echo guild[]
    elif m.content == "#!getgchan": # Gets a guild channel from rest or cache
        discard await discord.api.sendMessage(
            m.channel_id, "Getting guild channel!"
        )
        let channel = await s.getGuildChannel(m.channel_id)
        echo channel[]
    elif m.content == "#!getuser": # Gets a user from rest or cache
        discard await discord.api.sendMessage(
            m.channel_id, "Getting user!"
        )
        let user = await s.getUser(m.author.id)
        echo user[]

when defined(noCaching): # Turn off caching when you define noCaching `-d:noCaching`
    waitFor discord.startSession(
        gateway_intents = {giGuildMessages, giGuilds, giMessageContent},
        cache_users = false,
        cache_guilds = false,
        cache_guild_channels = false,
        cache_dm_channels = false
    )
else:
    waitFor discord.startSession(
        gateway_intents = {giGuildMessages, giGuilds, giMessageContent}
    )
