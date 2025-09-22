## Utilities and helper functions for every discord object.
## - You can use this for getting avatars, icons, get timestamp from id, permission checking without
## the hassle for doing complicated bitwise work.
## - Furthermore, you can also use this to [waitFor] a certain event and [waitForRaw] for raw json handling before dimscord handles them.

import constants, objects, options
import strformat, strutils, times, asyncdispatch
import tables, regex
import sugar, sequtils
import typetraits, json
import std/[macros, macrocache]
include ./helpers/[channel, guild, message, user]

const
    procsTable = macrocache.CacheTable"dimscord.handlerTypes"
        ## Stores a mapping of EventName -> parameters for event
        ## Note:: The shared parameter is removed from them
    dimscordEvents = macrocache.CacheTable"dimscord.eventNames"
        ## Stores names of events that exist. Basically
        ## a HashSet

# Build up the procsTable
static:
    # getTypleImpl returns `ref ObjSym` so we need to get the impl of ObjSym
    let impl = Events.getTypeImpl()[0].getImpl()
    for identDefs in impl[2][2]:
        var typ = identDefs[^2]

        # Desym all the parameters
        var params = newSeq[NimNode]()
        # Skip return type and shard parameter
        for identDef in typ[0][2 .. ^1]:
            var newDef = nnkIdentDefs.newTree()
            for param in identDef[0 ..< ^2]:
                newDef &= ident $param
            newDef &= identDef[^2]
            newDef &= identDef[^1]
            params &= newDef

        for field in identDefs[0 ..< ^2]:
            # Not exported so just ignore it
            if field.kind == nnkIdent: continue
            # Remove the on_ prefix for some events
            let origName = $field[1]
            let name = if origName == "on_dispatch": "unknown"
                       else: dup(origName, removePrefix("on_"))
            procsTable[name] = newStmtList(params).copy()
            dimscordEvents[origName.nimIdentNormalize()] = newEmptyNode()

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
    when (NimMajor, NimMinor, NimPatch) >= (2, 0, 0):
        # Check the event is valid, give proper error if it isn't
        if eventName.strVal.nimIdentNormalize() notin dimscordEvents:
            fmt"'{eventName}' is not a valid dimscord event".error(eventName)

    result = quote:
        `discord`.events.`eventName` = `anonFn`
    # Make sure the `anonFn` keeps its line info
    result[1].copyLineInfo(fn)

proc defaultAvatarUrl*(u: User): string =
    ## Returns the default avatar for a user.
    var index = block:
        if u.discriminator != "0":
            parseInt(u.discriminator) mod 5
        else:
            (parseInt(u.id) shr 22) mod 6

    result = &"{cdnBase}embed/avatars/{index}.png"

proc avatarUrl*(u: User, fmt = "png"; size = 128): string =
    ## Gets the user's avatar url.
    ## If user does not have an avatar it will return default avatar of the user.
    if u.avatar.isNone:
        return defaultAvatarUrl(u)
    cdnAvatars&u.id&"/"&u.avatar.get&"."&fmt&"?size="&($size)

proc memberAvatarUrl*(g: Guild, m: Member; fmt = "png"): string =
    ## Gets a user's avatar url.
    ## If user does not have an avatar it will return default avatar of the user.
    if m.user.isNil: return "" # imagine

    if m.avatar.isNone:
        return avatarUrl(m.user)

    result = cdnGuildMemberAvatar(g.id, m.user.id, m.avatar.get, fmt)

proc iconUrl*(r: Role; fmt = "png"): string =
    ## Gets a role's icon url.
    assert r.icon.isSome
    result = cdnRoleIcon(r.id, r.icon.get, fmt)

proc eventCover*(e: GuildScheduledEvent; fmt = "png"): string =
    ## Get scheduled event cover
    assert e.image.isSome

    result = cdnGuildScheduledEventCover(e.id, e.image.get, fmt)

proc guildBanner*(g: Guild; fmt = "png"): string =
    ## Get guild banner url
    result = cdnBanner(g.id, fmt)

proc memberBanner*(g: Guild, m: Member; fmt = "png"): string =
    ## Get member banner url
    result = cdnGuildMemberBanner(g.id, m.user.id, fmt)

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
    ## This would return something like `krisppurg#3211` or `krisp0`
    if u.username == "": return u.id

    result = u.username
    if u.discriminator != "0":
        result &= "#" & u.discriminator

proc `@`*(u: User, nick = false): string =
    ## Mentions a user.
    let n = if nick: "!" else: ""
    &"<@{n}{u.id}>"

proc `@`*(r: Role): string =
    ## Mentions a role.
    &"<@&{r.id}>"

proc `@`*(g: GuildChannel): string =
    ## Mentions a guild channel.
    &"<#{g.id}>"

proc `@`*(a: ApplicationCommand): string =
    ## Mentions a slash command.
    &"</{a.name}:{a.id}>"

proc `@`*(e: Emoji): string =
    ## Mentions emoji
    &"<{$e}>"

proc `>`*(e: string): Emoji =
    ## Converts string to Emoji
    ## "something:123" -> `Emoji(id: "123", name: "something")`
    var elems = e.split(":")
    Emoji(name: some elems[0],
          id: if elems.len > 1: some elems[1] else: none string)

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

proc toBits*(p: set[PermissionFlags]): int =
    ## Converts the set of permissions to an integer
    cast[int](p)

proc denied*(p: set[PermissionFlags]): set[PermissionFlags] =
    ## Returns the denied permissions
    permAll - p

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

proc computePerms*(guild: Guild, role: Role): PermObj =# todo: replace permobj with permissionflags
    ## Computes the guild permissions for a role.
    let
        everyone = guild.roles[guild.id]
        perms = everyone.permissions + role.permissions

    if permAdministrator in perms:
        return PermObj(allowed: permAll)

    result = PermObj(allowed: perms)

proc computePerms*(guild: Guild, member: Member): PermObj = # todo: replace permobj with permissionflags
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

proc reference*(m: Message): MessageReference =
    result.channel_id = some m.channel_id
    result.message_id = some m.id
    result.guild_id   = m.guild_id

proc mention*(parse, roles, users: seq[string];
    ping: bool): AllowedMentions =
    ## A constructor for AllowedMentions object that performs validation.
    ## - Any value in `parse` is mutually exclusive with a field of the same name. 
    ## - To suppress all mentions, set `parse` to `[]`.
    ## - `ping`: set to true if you want a mentioned reply to ping the target.
    doAssert(
        not("users" in parse and users.len > 0),
        "Mutually Exclusive: 'users' cannot be used when 'parse' includes 'users'"
    )

    doAssert(
        not("roles" in parse and roles.len > 0),
        "Mutually Exclusive: 'roles' cannot be used when 'parse' includes 'roles'"
    )

    result.parse        = parse
    result.roles        = roles
    result.users        = users
    result.replied_user = ping

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
    doAssert row.kind == mctActionRow, "Only action rows can be checked"
    # Keep count of every message component
    var contains: CountTable[MessageComponentType]
    for component in row.components:
        contains.inc component.kind
    # Beware, this check might be invalid in future when more
    # components are added
    assert contains.len <= 1, "Action rows can only contain one type"
    if mctSelectMenu in contains:
        assert(
            contains[mctSelectMenu] == 1,
            "Can only have one select menu per action row"
        )
        assert row.components[0].options.len > 0, "Menu must have options"
    elif mctButton in contains:
        assert contains[mctButton] <= 5, "Can only have <= 5 buttons per row"
    else:
        assert(
            mctActionRow notin contains,
            "Action row cannot contain an action row"
        )

proc newActionRow*(components: varargs[MessageComponent]): MessageComponent =
    ## Creates a new action row which you can add components to.
    ## It is recommended to use this over raw objects since this
    ## does validation of the row as you add objects
    result = MessageComponent(
        kind: mctActionRow,
        components: @components
    )
    if components.len > 0:
        checkActionRow result

proc len*(component: MessageComponent): int =
    ## Returns number of items in an ActionRow or number of options in a menu
    case component.kind:
    of mctActionRow:
        result = component.components.len
    of mctSelectMenu:
        result = component.options.len
    else:
        raise newException(
            ValueError, "Component must be ActionRow or SelectMenu")

template optionalEmoji(): untyped {.dirty.} =
    (if emoji.id.isSome() or emoji.name.isSome(): some emoji else: none Emoji)

proc newButton*(label, idOrUrl: string, style = bsPrimary, emoji = Emoji(),
                disabled = false): MessageComponent =
    ## Creates a new button.
    ## - If the buttons style is NOT Link then it requires a customID
    ## - If the buttons style is Link then it requires a url
    result = MessageComponent(
        kind: mctButton,
        label: optionIf(label == ""), # Don't send label if it's empty
        style: style,
        emoji: optionalEmoji(),
        disabled: some disabled
    )
    if style == bsLink:
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

proc newSelectMenu*(custom_id: string; options: openArray[SelectmenuOption];
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
        kind: mctSelectMenu,
        customID: some customID,
        options: @options,
        placeholder: optionIf(placeholder == ""),
        minValues: some minValues,
        maxValues: some maxValues
    )

proc add*(component: var MessageComponent, item: MessageComponent) =
    ## Add another component onto an ActionRow
    assert(
        component.kind == mctActionRow,
        "Can only add components onto an ActionRow."
    )
    component.components &= item
    checkActionRow component

proc add*(component: var MessageComponent, item: SelectMenuOption) =
    ## Add another menu option onto the select menu
    assert(
        component.kind == mctSelectMenu,
        "Can only add menu options to a SelectMenu."
    )
    component.options &= item

# Event Handlers

proc params(event: DispatchEvent): NimNode =
    ## Returns the proc type stored for an event
    var evt = toLowerAscii($event)
    if evt.startsWith("de"): evt = evt[2..^1]
    procsTable[evt].copy()

proc dataType(event: DispatchEvent): NimNode =
    ## Returns a tuple type that corresponds to the data for an event.
    result = nnkTupleTy.newTree(toSeq(event.params))

macro dataTypedesc(event: static[DispatchEvent]): typedesc =
    ## Returns typedesc for data that an event has
    result = event.dataType

macro passArgs(prc: proc, data: tuple): untyped =
    ## Calls a proc using the fields in a tuple
    let args = collect:
        for i in 0..<data.getTypeImpl().len:
            nnkBracketExpr.newTree(data, newLit i)
    result = newCall(prc, args)

proc orTimeout*[T](fut: Future[T], time: TimeInterval): Future[Option[T]] {.async.} =
    ## Helper that returns `none(T)` if a Future timeouts.
    ## Returns `some(T)` is it finished within time limit
    # We need time in milliseconds
    let milliseconds = initDuration(
        time.nanoseconds,
        time.microseconds,
        time.milliseconds,
        time.seconds,
        time.minutes,
        time.hours,
        time.days,
        time.weeks).inMilliseconds()

    if await fut.withTimeout(int milliseconds):
        result = some await fut

proc handlerType(event: DispatchEvent): NimNode =
    ## Returns a proc type which corresponds to what a handler
    ## should look like to handle an event
    let params = nnkFormalParams.newTree(
        ident"bool" # Handlers return if they handled the event
    )
    # Add parameters for the data
    for param in event.params:
        params &= param
    # Create the proc type
    result = nnkProcTy.newTree(params, newEmptyNode())

macro handlerTypeDesc(x: static[DispatchEvent]): typedesc =
  ## Returns a typedesc of what proc should be used to handle an event
  result = x.handlerType

proc waitForInternal*(discord: DiscordClient;
        event: static[DispatchEvent], handler: proc): auto =
    ## Internal proc for wait for.
    ## This is done so the procs can properly be binded to
    ##
    ## - The object returned would be a tuple that have the same parameter names in [Events].
    ##   e.g. if you were to waitFor message reaction add, it would be
    ##   `tuple[s: Shard, msg: Message, u: User, emj: Emoji, exists: bool]`
    ##   You can always find which type the parameter fields are by checking the [Events] object.

    type
      DataType = event.dataTypedesc
      # For simplicity, we make the return be the type of the first
      # item in the tuple if there is only one item
      FutReturn = (when DataType.tupleLen == 1: DataType.get(0)
                   else: DataType)

    # For single field tuples, we just want to return the first type
    let fut = newFuture[FutReturn]("waitFor(" & $event & ")")
    # We wrap the users handler inside another proc.
    # This allows us to abstract creating the future, completing it, handling timeouts, etc
    result = fut
    discord.waits[event] &= proc (data: pointer): bool =
        if fut.finished(): return true
        let data {.cursor.} = cast[ptr DataType](data)[]
        if handler.passArgs(data):
            when FutReturn is DataType:
                fut.complete(data)
            else:
                fut.complete(data[0])
            return true

template waitFor*(discord: DiscordClient; event: static[DispatchEvent],
                            handler: untyped): auto =
    ## Allows you to define a custom condition to wait for.
    ## This also returns the object that passed the condition.
    ## - Note: some event objects may be same as the event name e.g. GuildMembersChunk, you can write this as [deGuildMembersChunk] instead of having to write `DispatchEvent.GuildMembersChunk`.
    ##
    ## - The object returned would be a tuple that have the same parameter names in `Events`.
    ##   e.g. if you were to `waitFor` `MessageReactionAdd`, it would be
    ##   `tuple[msg: Message, u: User, emj: Emoji, exists: bool]`
    ##   You can always find which type the parameter fields are by checking the `Events` object.
    ## 
    ## See also:
    ## - [Events](./objects.html#Events)
    ## 
    ## Similar procs:
    ## - [waitForComponentUse]
    ## - [waitForModalUse]
    ## - [waitForDeletion]
    ## - [waitForInternal]
    ## - [waitForReaction]
    ## - [waitForReply]
    ## - [waitToJoinVoice]
    block:
        # Issue is that we can't refine the handler type to be
        # different depending on what event is. To get around this
        # we create a shim template which restricts the proc to only be
        # of one type
        template shim(prc: handlerTypeDesc(event)): auto =
            discord.waitForInternal(event, prc)
        shim(handler)

proc waitForRaw*(discord: DiscordClient;
        event: string;
        handler: proc (data: JsonNode): bool): Future[JsonNode] {.async.} =
    ## This allows waiting for a dispatch event, except you can specify any string.
    ## This allows for handling events that aren't implemented in dimscord yet.
    ## The handler is ran before dimscord handles the event, so items might not be in cache.
    ## Use [waitFor] if you know the event you want to wait for
    proc handled(eventKind: string, data: JsonNode): bool =
        if event == eventKind:
            return handler(data)

    return (await discord.waitFor(Unknown, handled)).data

proc waitForReply*(discord: DiscordClient;
        to: Message): Future[Message] {.async.} =
    ## Waits for a message to reply to a message
    return await discord.waitFor(MessageCreate) do (m: Message) -> bool:
        if m.referencedMessage.isSome:
            let referenced = m.referencedMessage.unsafeGet
            return referenced.id == to.id

proc waitForDeletion*(discord: DiscordClient;
        msg: Message): Future[void] {.async.} =
    ## Waits for a message to be deleted
    proc event(m: Message, exists: bool): bool =
        m.id == msg.id
    discard await discord.waitFor(MessageDelete, event)

proc waitForComponentUse*(discord: DiscordClient;
        custom_id: string): Future[Interaction] =
    ## Waits for a component to be used and returns the interaction.
    ## Data sent in the component can then be extracted.
    ##
    ## `custom_id` is the ID that you used when creating the component
    return discord.waitFor(InteractionCreate) do (i: Interaction) -> bool:
        i.data.isSome and
        i.data.unsafeGet().interactionType == idtMessageComponent and
        i.data.get.custom_id == custom_id

proc waitForModalUse*(discord: DiscordClient;
        custom_id: string): Future[Interaction] =
    ## Waits for a modal to be used and returns the interaction.
    ## Data sent in the component can then be extracted.
    ##
    ## `custom_id` is the ID that you used when creating the component
    return discord.waitFor(InteractionCreate) do (i: Interaction) -> bool:
        i.data.isSome and
        i.data.unsafeGet().interactionType == idtModalSubmit and
        i.data.get.custom_id == custom_id

proc waitToJoinVoice*(discord: DiscordClient;
        user: User; guildID: string): Future[VoiceState] {.async.} =
    ## Waits for a user to join a voice channel in a guild.
    assert giGuildVoiceStates in discord.intents

    proc handleUpdate(vs: VoiceState, o: Option[VoiceState]): bool =
        vs.guildID.isSome() and
        guildID == vs.guildID.unsafeGet() and
        user.id == vs.user_id

    return discord
        .waitFor(VoiceStateUpdate, handleUpdate)
        .await()
        .v

proc waitForReaction*(discord: DiscordClient;
        msg: Message, user: User = nil): Future[Emoji] {.async.} =
    ## Waits for a reaction to a message. Can optionally provide
    ## a user to only wait for a certain user.
    ##
    ## Make sure you have message reaction intents,
    ## either one of `giGuildMessageReactions` or `giDirectMessageReactions`.
    let direct = giDirectMessageReactions in discord.intents
    let guild = giGuildMessageReactions in discord.intents
    if not direct and not guild:
        raise newException(Exception,
            "You need to set either the guild or direct message reaction intents or both."
        )

    proc handleUpdate(m: Message, u: User, emoji: Emoji, exists: bool): bool =
        return msg.id == m.id and (user == nil or user.id == u.id)
    return discord
        .waitFor(MessageReactionAdd, handleUpdate)
        .await()
        .emj
