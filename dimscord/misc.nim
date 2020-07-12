import constants, objects, options
import strformat, strutils, times
import tables

proc defaultAvatarUrl*(u: User): string =
    ## Returns the default avatar for a user.
    result = &"{cdnBase}embeds/avatars/{parseInt(u.discriminator) mod 5}.png"

proc avatarUrl*(u: User, fmt = ""; size = 128): string =
    ## Gets a user's avatar url.
    ## If user does not have an avatar it will return default avatar of the user.
    var ift = fmt
    if fmt == "":
        ift = "jpg"
        if u.avatar.isSome and (get(u.avatar)).startsWith("a_"):
            ift = "gif"

    if u.avatar.isNone:
        return defaultAvatarUrl(u)
    result = &"{cdnAvatars}{u.id}/{get(u.avatar)}.{ift}?size={size}"

proc iconUrl*(e: Emoji, fmt = ""; size = 128): string =
    ## Gets an emoji's url.
    if e.id == "" or e.name == "":
        return ""

    var ift = fmt
    if fmt == "":
        ift = "png"
        if e.animated.isSome and e.animated.get: # this field is troublesome.
            ift = "gif"

    result = &"{cdnCustomEmojis}{e.id}.{ift}?size={size}"

proc iconUrl*(g: Guild, fmt = ""; size = 128): string =
    ## Get icon url for guild.
    var ift = fmt
    if fmt == "":
        ift = "png"
        if g.icon.isSome and get(g.icon).startsWith("a_"):
            ift = "gif"

    if g.icon.isSome:
        result = &"{cdnIcons}{g.id}/{get(g.icon)}.{ift}?size={size}"
    else:
        result = ""

proc `$`*(u: User): string =
    ## Stringifies a user.
    ## This would return something like `MrDude#6969`
    result = &"{u.username}#{u.discriminator}"

proc `@`*(u: User; nick = false): string =
    ## Mentions a user.
    var n = if nick: "!" else: ""
    result = &"<@{n}{u.id}>"

proc `@`*(r: Role): string =
    ## Mentions a role.
    result = &"<@{r.id}>"

proc `@`*(g: GuildChannel): string =
    ## Mentions a guild channel.
    result = &"<#{g.id}>"

proc `$`*(g: GuildChannel): string =
    ## Stringifies a guild channel.
    ## This would return something like `#general`
    result = &"#{g.name}"

proc getGuildWidget*(guild_id, style: string): string =
    ## Gets a guild widget.
    ## https://discord.com/developers/docs/resources/guild#get-guild-widget-image-widget-style-options
    result = &"{restBase}/guilds/{guild_id}/widget.png"

proc timestamp*(id: string): Time =
    ## Gets a timestamp from a Discord ID.
    let snowflake = parseBiggestUint(id)
    result = fromUnix int64(((snowflake shr 22) + 1420070400000'u64) div 1000)

proc `+`*(p: PermObj): int =
    ## Sums up the total permissions.
    result = 0
    if p.allowed.len > 0:
        for it in p.allowed:
            result = result or it.int
    if p.denied.len > 0:
        for it in p.denied:
            result = result and (it.int - it.int - it.int)

proc permCheck*(perms: int, p: int): bool =
    ## Checks if the set of permissions has the specific permission.
    result = (perms and p) == p

proc permCheck*(perms: int, p: PermObj): bool =
    ## Just like permCheck, but with a PermObj.
    var allowed: Option[bool]
    var denied: Option[bool]

    if p.allowed.len > 0:
        allowed = some permCheck(perms, cast[int](p.allowed))
    if p.denied.len > 0:
        denied = some permCheck(perms,  cast[int](p.denied))

    if allowed.isSome and denied.isSome:
        if allowed.get != denied.get:
            result = false
    elif allowed.isSome:
        result = allowed.get
    elif denied.isSome:
        result = denied.get
    else:
        if p.perms != 0:
            result = permCheck(perms, p.perms)

proc computeBasePerms*(guild: Guild, role: Role): PermObj =
    ## Computes the base permissions for a role.
    let
        everyone = guild.roles[guild.id]
        perms = everyone.permissions or role.permissions

    if perms.permCheck(cast[int]({permAdministrator})):
        return PermObj(allowed: permAll)

    result = PermObj(allowed: cast[set[PermEnum]](perms))

proc computeBasePerms*(guild: Guild, member: Member): PermObj =
    ## Computes the base permissions for a member.
    if guild.owner_id == member.user.id:
        return PermObj(allowed: permAll)

    let everyone = guild.roles[guild.id]
    var perms = cast[set[PermEnum]](everyone.permissions)

    for r in member.roles:
        perms = perms + guild.computeBasePerms(guild.roles[r]).allowed
        let permissions = cast[int](perms)
        if permissions.permCheck(cast[int]({permAdministrator})):
            return PermObj(allowed: permAll)

    result = PermObj(allowed: perms)

proc readPerms*(guild: Guild, member: Member, channel: GuildChannel): PermObj =
    ## Returns the permissions for the guild member of the channel.
    ## For permission checking you can do something like this:
    ## 
    ## .. code-block:: Nim
    ##    cast[int](setofpermshere).permCheck(PermObj(
    ##        allowed: {permExample}
    ##    ))
    var
        perms = cast[int](guild.computeBasePerms(member))
        allow = 0
        deny = 0

    if perms.permCheck(cast[int]({permAdministrator})):
        return PermObj(allowed: permAll)

    let overwrites = channel.permission_overwrites

    if channel.guild_id in overwrites:
        let eow = overwrites[channel.guild_id]
        perms = perms or cast[int](eow.permObj.allowed)
        perms = perms and cast[int](eow.permObj.denied)

    for role in member.roles:
        if role in overwrites:
            allow = allow or overwrites[role].allow
            deny = deny or overwrites[role].deny

    if member.user.id in overwrites:
        let m = member.user.id
        allow = allow or overwrites[m].allow
        deny = deny or overwrites[m].deny

    perms = (perms and deny - deny - deny - 1) or allow
    result = PermObj(allowed: cast[set[PermEnum]](perms))

func inviteLink*(user: User, permissions: set[PermEnum] = {}, guild = none(Guild), disableGuildSelect = false): string =
    ## Creates an invite link for the bot of the form https://discord.com/api/oauth2/authorize?client_id=157730590492196864&scope=bot&permissions=1
    ## see https://discord.com/developers/docs/topics/oauth2#bots for more information
    result = restBase & "oauth2/authorize?client_id=" & user.id & "&scope=bot&permissions=" & $cast[int](permissions)
    if guild.isSome:
        result &= "&guild_id=" & guild.get.id
        if disableGuildSelect:
            result &= "&disable_guild_select=true"
