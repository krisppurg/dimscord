# Utilities for every discord object.
## It mostly contains `helper` procedures.
## You can use this for getting an avatar url and permission checking without
## the hassle for doing complicated bitwise work.

import constants, objects, options
import strformat, strutils, times
import tables, regex
import macros

macro event*(discord: DiscordClient, fn: untyped): untyped =
    ## Sugar for registering an event handler.
    let 
        eventName = fn[0]
        params = fn[3]
        pragmas = fn[4]
        body = fn[6]

    var anonFn = newTree(
        nnkLambda,
        newEmptyNode(),
        newEmptyNode(),
        newEmptyNode(),
        params,
        pragmas,
        newEmptyNode(),
        body
    )

    if pragmas.findChild(it.strVal == "async").kind == nnkNilLit:
        anonFn.addPragma ident("async")

    quote:
        `discord`.events.`eventName` = `anonFn`

proc defaultAvatarUrl*(u: User): string =
    ## Returns the default avatar for a user.
    result = &"{cdnBase}embeds/avatars/{parseInt(u.discriminator) mod 5}.png"

proc avatarUrl*(u: User, fmt = "png"; size = 128): string =
    ## Gets the user's avatar url.
    ## If user does not have an avatar it will return default avatar of the user.
    if u.avatar.isNone:
        return defaultAvatarUrl(u)
    cdnAvatars&u.id&"/"&u.avatar.get&"."&fmt&"?size="&($size)

proc guildAvatarUrl*(g: Guild, m: Member; fmt = "png"): string =
    ## Gets a user's avatar url.
    ## If user does not have an avatar it will return default avatar of the user.
    if m.user.isNil: return "" # imagine

    if m.avatar.isNone:
        return avatarUrl(m.user)

    endpointGuilds(g.id)&"/users/"&m.user.id&"/avatars/"&m.avatar.get&"."&fmt

proc iconUrl*(r: Role, fmt = "png"): string =
    ## Gets a role's icon url.
    result = cdnRoleIcons&r.id&"/role_icon."&fmt

proc eventCover*(e: GuildScheduledEvent, fmt = "png"): string =
    ## Get scheduled event cover
    result = cdnBase&"guild-events/"&e.id&"/scheduled_event_cover_image."&fmt

proc guildBanner*(g: Guild, fmt = "png"): string =
    ## Get guild banner url
    cdnBanners&g.id&"/guild_banner."&fmt

proc memberBanner*(g: Guild, m: Member, fmt = "png"): string =
    ## Get member banner url
    endpointGuilds(g.id)&"/users/"&m.user.id&"/banners/member_banner."&fmt

proc iconUrl*(e: Emoji, fmt = "png"; size = 128): string =
    ## Gets an emoji's url.
    if e.id.isNone or e.name.isNone:
        return ""

    result = &"{cdnCustomEmojis}{e.id}.{fmt}?size={size}"

proc iconUrl*(g: Guild, fmt = "png"; size = 128): string =
    ## Get icon url for guild.
    if g.icon.isSome:
        result = &"{cdnIcons}{g.id}/{get(g.icon)}.{fmt}?size={size}"
    else:
        result = ""

proc `$`*(u: User): string =
    ## Stringifies a user.
    ## This would return something like `MrDude#6969`
    result = &"{u.username}#{u.discriminator}"

proc `@`*(u: User, nick = false): string =
    ## Mentions a user.
    let n = if nick: "!" else: ""
    result = &"<@{n}{u.id}>"

proc `@`*(r: Role): string =
    ## Mentions a role.
    result = &"<@&{r.id}>"

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

proc perms*(p: PermObj): int =
    ## Gets the total permissions.
    result = 0
    if p.allowed.len > 0:
        for it in p.allowed:
            result = result or it.int
    if p.denied.len > 0:
        for it in p.denied:
            result = result and (it.int - it.int - it.int)

proc permCheck(perms, perm: int): bool =
    ## Checks if the set of permissions has the specific permission.
    result = (perms and perm) == perm

proc `in`*(x, y: set[PermissionFlags]): bool =
    if x.len == 0: return false
    result = false
    for flag in x:
        if flag notin y:
            return false
        result = flag in y

proc `notin`*(x, y: set[PermissionFlags]): bool =
    not (x in y)

proc permCheck*(perms: int, p: PermObj): bool =
    ## Just like permCheck, but with a PermObj.
    var
        allowed: Option[bool]
        denied: Option[bool]

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

proc computePerms*(guild: Guild, role: Role): PermObj =
    ## Computes the guild permissions for a role.
    let
        everyone = guild.roles[guild.id]
        perms = everyone.permissions + role.permissions

    if permAdministrator in perms:
        return PermObj(allowed: permAll)

    result = PermObj(allowed: perms)

proc computePerms*(guild: Guild, member: Member): PermObj =
    ## Computes the guild permissions for a member.
    if guild.owner_id == member.user.id:
        return PermObj(allowed: permAll)

    let everyone = guild.roles[guild.id]
    var perms = everyone.permissions

    for r in member.roles:
        perms = perms + guild.computePerms(guild.roles[r]).allowed
        if permAdministrator in perms:
            return PermObj(allowed: permAll)

    result = PermObj(allowed: perms)

proc computePerms*(guild: Guild;
        member: Member, channel: GuildChannel): PermObj =
    ## Returns the permissions for the guild member of the channel.
    ## For permission checking you can do something like this:
    ## 
    ## .. code-block:: Nim
    ##    cast[int](setofpermshere).permCheck(PermObj(
    ##        allowed: {permExample}
    ##    ))
    var
        perms = cast[int](guild.computePerms(member).perms)
        allow = 0
        deny = 0
    if permAdministrator in guild.computePerms(member).allowed:
        return PermObj(allowed: permAll)
    let overwrites = channel.permission_overwrites

    if channel.guild_id in overwrites:
        let eow = overwrites[channel.guild_id]
        perms = perms or cast[int](eow.allow)
        perms = perms and cast[int](eow.deny)

    for role in member.roles:
        if role in overwrites:
            allow = allow or cast[int](overwrites[role].allow)
            deny = deny or cast[int](overwrites[role].deny)

    if member.user.id in overwrites:
        let m = member.user.id
        allow = allow or cast[int](overwrites[m].allow)
        deny = deny or cast[int](overwrites[m].deny)

    perms = (perms and deny - deny - deny - 1) or allow
    result = PermObj(
        allowed: cast[set[PermissionFlags]](allow),
        denied: cast[set[PermissionFlags]](deny)
    )

proc createBotInvite*(client_id: string, permissions: set[PermissionFlags]={};
        guild_id = ""; disable_guild_select = false): string =
    ## Creates an invite link for the bot of the form.
    ## 
    ## Example:
    ## `https://discord.com/api/oauth2/authorize?client_id=1234&scope=bot&permissions=1`
    ## 
    ## See https://discord.com/developers/docs/topics/oauth2#bots for more information.
    result = restBase & "oauth2/authorize?client_id=" & client_id &
        "&scope=bot&permissions=" & $cast[int](permissions)

    if guild_id != "":
        result &= "&guild_id=" & guild_id &
            "&disable_guild_select=" & $disable_guild_select

proc stripUserMentions*(m: Message): string =
    ## Strips out user mentions.
    ## Example: `<@1234567890>` to `@TheMostMysteriousUser#0000`
    result = m.content
    for user in m.mention_users:
        result = result.replace(re("<@!?" & user.id & ">"), "@" & $user)

proc stripRoleMentions*(m: Message): string =
    ## Strips out role mentions.
    ## Example: `<@&123456890>` to `@1243456890`
    result = m.content
    for role in m.mention_roles:
        result = result.replace(re("<@&?" & role & ">"), "@" & role)

proc stripChannelMentions*(m: Message): string =
    ## Strips out channel mentions.
    ## Example: `<#123456790>` to `#such-a_long-time-ago` or `#123456790`
    result = m.content
    if m.mention_channels.len == 0:
        result = result.replace(re"<(#\d{17,19})>", "$1")
    else:
        for chan in m.mention_channels:
            result = result.replace(re"<#\d{17,19}>", "#" & chan.name)

proc stripMentions*(m: Message): string =
    ## Strips all mentions.
    result = m.content
    for user in m.mention_users:
        result = result.replace(re("<@!?" & user.id & ">"), "@" & $user)

    for role in m.mention_roles:
        result = result.replace(re("<@&?" & role & ">"), "@" & role)

    if m.mention_channels.len == 0:
        result = result.replace(re"<(#\d{17,19})>", "$1")
    else:
        for chan in m.mention_channels:
            result = result.replace(re"<#\d{17,19}>", "#" & chan.name)
#
# Message components
#

proc checkActionRow*(row: MessageComponent) =
    ## Checks if an action row meets these requirements
    ## - A row cannot contain another row
    ## - If a row contains buttons, then it can only have 5 buttons
    ## - If a row contains buttons, then it cannot contains select menu
    ## - If a row contiains a select menu, then there can only be one select
    ##   menu
    ## Throws an `AssertionDefect` if any of these checks fail
    doAssert row.kind == ActionRow, "Only action rows can be checked"
    # Keep count of every message component
    var contains: CountTable[MessageComponentType]
    for component in row.components:
        contains.inc component.kind
    # Beware, this check might be invalid in future when more
    # components are added
    assert contains.len <= 1, "Action rows can only contain one type"
    if contains.hasKey(SelectMenu):
        assert contains[SelectMenu] == 1, "Can only have one select menu per action row"
        assert row.components[0].options.len > 0, "Menu must have options"
    elif contains.hasKey(Button):
        assert contains[Button] <= 5, "Can only have <= 5 buttons per row"
    else:
        assert not contains.hasKey(ActionRow), "Action row cannot contain an action row"

proc newActionRow*(components: seq[MessageComponent] = @[]): MessageComponent =
    ## Creates a new action row which you can add components to.
    ## It is recommended to use this over raw objects since this
    ## does validation of the row as you add objects
    result = MessageComponent(
        kind: ActionRow,
        components: components
    )
    if components.len > 0:
        checkActionRow result

proc len*(component: MessageComponent): int =
    ## Returns number of items in an ActionRow or number of options in a menu
    case component.kind:
        of ActionRow:
            result = component.components.len
        of SelectMenu:
            result = component.options.len
        else:
            raise newException(ValueError, "Component must be ActionRow or SelectMenu")

template optionalEmoji(): untyped {.dirty.} =
    (if emoji.id.isSome() or emoji.name.isSome(): some emoji else: none Emoji)

proc newButton*(label, idOrUrl: string, style = Primary, emoji = Emoji(),
                disabled = false): MessageComponent =
    ## Creates a new button.
    ## - If the buttons style is NOT Link then it requires a customID
    ## - If the buttons style is Link then it requires a url
    result = MessageComponent(
        kind: Button,
        label: optionIf(label == ""), # Don't send label if it's empty
        style: style,
        emoji: optionalEmoji(),
        disabled: some disabled
    )
    if style == Link:
        result.url = some idOrUrl
    else:
        result.customID = some idOrUrl

proc newMenuOption*(label: string, value: string,
                    description = "", emoji = Emoji(),
                    default = false): SelectMenuOption =
    ## Creates a new menu option for a select menu.
    ## - label: The user facing value
    ## - value: The dev facing value
    ## - default: Whether this option is the default
    result = SelectMenuOption(
        label: label,
        value: value,
        description: optionIf(description == ""),
        emoji: optionalEmoji(),
        default: some default
    )

proc newSelectMenu*(custom_id: string; options: seq[SelectmenuOption];
        placeholder = ""; minValues, maxValues = 1;
        disabled = false
): MessageComponent =
    ## Creates a new select menu.
    ## Options can be an empty seq but you MUST add options before adding it
    ## to the option row.
    ## min and max values is if you want users to be able to select multiple
    ## options
    doAssert(
        minValues in 0..25,
        "minValues must be between 0 and 25 (inclusive)"
    )
    doAssert(
        maxValues in 1..25,
        "maxValues must be between 1 and 25 (inclusive)"
    )
    result = MessageComponent(
        kind: SelectMenu,
        customID: some customID,
        options: options,
        placeholder: optionIf(placeholder == ""),
        minValues: some minValues,
        maxValues: some maxValues
    )

proc add*(component: var MessageComponent, item: MessageComponent) =
    ## Add another component onto an ActionRow
    assert(
        component.kind == ActionRow,
        "Can only add components onto an ActionRow."
    )
    component.components &= item
    checkActionRow component

proc add*(component: var MessageComponent, item: SelectMenuOption) =
    ## Add another menu option onto the select menu
    assert(
        component.kind == SelectMenu,
        "Can only add menu options to a SelectMenu."
    )
    component.options &= item
