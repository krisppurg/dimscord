import objects, tables, constants, options

type
    CacheTable* = ref object ## An object that has properties of stored things
        preferences*: CacheTablePrefs
        users*: Table[string, User]
        guilds*: Table[string, Guild]
        guildChannels*: Table[string, GuildChannel]
        dmChannels*: Table[string, DMChannel]
    CacheTablePrefs* = ref object
        cache_users*: bool
        cache_guilds*: bool
        cache_guild_channels*: bool
        cache_dm_channels*: bool
    CacheError* = object of Exception

proc newCacheTable*(cache_users: bool; cache_guilds: bool;
            cache_guild_channels: bool; cache_dm_channels: bool): CacheTable =
    ## Initialises cache.
    var prefs = CacheTablePrefs(
        cache_users: cache_users,
        cache_guilds: cache_guilds,
        cache_guild_channels: cache_guild_channels,
        cache_dm_channels: cache_dm_channels
    )

    result = CacheTable(
        preferences: prefs,
        users: initTable[string, User](),
        guilds: initTable[string, Guild](),
        guildChannels: initTable[string, GuildChannel](),
        dmChannels: initTable[string, DMChannel]()
    )

proc kind*(c: CacheTable, channel_id: string): int =
    ## Checks for a channel kind. (Shortcut)
    if c.dmChannels.hasKey(channel_id):
        result = c.dmChannels[channel_id].kind
    elif c.guildChannels.hasKey(channel_id):
        result = c.guildChannels[channel_id].kind
    else:
        raise newException(CacheError, "Channel doesn't exist in cache.")

proc guild*(c: CacheTable, channel_id: string): Guild =
    ## Get's a guild from a channel_id.
    if c.kind(channel_id) != ctDirect or c.preferences.cache_guilds:
        let guild = c.guildChannels[channel_id].guild_id
        if guild.isSome:
            result = c.guilds[get(guild)]
        else:
            raise newException(Exception, "Failed to get guild.")
    else:
        raise newException(Exception, "Failed to get guild.")

proc clear*(c: CacheTable) =
    ## Empties cache.
    c.users.clear()
    c.guilds.clear()
    c.guildChannels.clear()
    c.dmChannels.clear()