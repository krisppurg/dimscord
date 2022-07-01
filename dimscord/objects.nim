## This contains every single discord objects
## All Optional fields in these object are:
##
## * Fields that cannot be assumed. such as bools
## * Optional fields for example embeds, which they may not be
##   present.
##   
## Some may not be optional, but they can be assumable or always present.

import options, json, tables, constants
import sequtils, strutils, jsony
import asyncdispatch
include objects/typedefs, objects/macros

proc newShard*(id: int, client: DiscordClient): Shard =
    result = Shard(
        id: id,
        client: client,
        cache: CacheTable(
            users: initTable[string, User](),
            guilds: initTable[string, Guild](),
            guildChannels: initTable[string, GuildChannel](),
            dmChannels: initTable[string, DMChannel]()
        ),
        retry_info: (ms: 1000, attempts: 0)
    )

proc newDiscordClient*(token: string;
        rest_mode = false;
        restVersion = 6): DiscordClient =
    ## Creates a Discord Client.
    var auth_token = token
    if not token.startsWith("Bot "):
        auth_token = "Bot " & token
    
    var apiVersion = restVersion
    when defined(discordv8) and not defined(discordv9):
        apiVersion = 8
    when defined(discordv9) and not defined(discordv8): 
        apiVersion = 9
    when defined(discordv8) and defined(discordv9):
        raise newException(Exception,
            "Both v8 and v9 are defined, please define either one of them only."
        )
    result = DiscordClient(
        token: auth_token,
        api: RestApi(
            token: auth_token,
            restVersion: apiVersion),
        max_shards: 1,
        restMode: rest_mode,
        events: Events(
            on_dispatch: proc (s: Shard, evt: string,
                    data: JsonNode) {.async.} = discard,
            on_ready: proc (s: Shard, r: Ready) {.async.} = discard,
            on_invalid_session: proc (s: Shard,
                    resumable: bool) {.async.} = discard,
            message_create: proc (s: Shard, m: Message) {.async.} = discard,
            message_delete: proc (s: Shard, m: Message,
                    exists: bool) {.async.} = discard,
            message_update: proc (s: Shard, m: Message,
                    o: Option[Message], exists: bool) {.async.} = discard,
            message_reaction_add: proc (s: Shard,
                    m: Message, u: User,
                    e: Emoji, exists: bool) {.async.} = discard,
            message_reaction_remove: proc (s: Shard, m: Message,
                    u: User, r: Reaction, exists: bool) {.async.} = discard,
            message_reaction_remove_all: proc (s: Shard, m: Message,
                    exists: bool) {.async.} = discard,
            message_reaction_remove_emoji: proc (s: Shard, m: Message,
                    e: Emoji, exists: bool) {.async.} = discard,
            message_delete_bulk: proc (s: Shard, m: seq[tuple[
                    msg: Message, exists: bool]]) {.async.} = discard,
            channel_create: proc (s: Shard, g: Option[Guild],
                    c: Option[GuildChannel],
                    d: Option[DMChannel]) {.async.} = discard,
            channel_update: proc (s: Shard, g: Guild,
                    c: GuildChannel,
                    o: Option[GuildChannel]) {.async.} = discard,
            channel_delete: proc (s: Shard, g: Option[Guild],
                    c: Option[GuildChannel],
                    d: Option[DMChannel]) {.async.} = discard,
            channel_pins_update: proc (s: Shard, cid: string,
                    g: Option[Guild],
                    last_pin: Option[string]) {.async.} = discard,
            presence_update: proc (s: Shard, p: Presence,
                    o: Option[Presence]) {.async.} = discard,
            typing_start: proc (s: Shard, t: TypingStart) {.async.} = discard,
            guild_emojis_update: proc (s: Shard, g: Guild,
                    e: seq[Emoji]) {.async.} = discard,
            guild_ban_add: proc (s: Shard, g: Guild,
                    u: User) {.async.} = discard,
            guild_ban_remove: proc (s: Shard, g: Guild,
                    u: User) {.async.} = discard,
            guild_integrations_update: proc (s: Shard,
                    g: Guild) {.async.} = discard,
            guild_member_add: proc (s: Shard, g: Guild,
                    m: Member) {.async.} = discard,
            guild_member_remove: proc (s: Shard, g: Guild,
                    m: Member) {.async.} = discard,
            guild_member_update: proc (s: Shard, g: Guild,
                    m: Member, o: Option[Member]) {.async.} = discard,
            guild_update: proc (s: Shard, g: Guild,
                    o: Option[Guild]) {.async.} = discard,
            guild_create: proc (s: Shard, g: Guild) {.async.} = discard,
            guild_delete: proc (s: Shard, g: Guild) {.async.} = discard,
            guild_members_chunk: proc (s: Shard, g: Guild,
                    m: GuildMembersChunk) {.async.} = discard,
            guild_role_create: proc (s: Shard, g: Guild,
                    r: Role) {.async.} = discard,
            guild_role_delete: proc (s: Shard, g: Guild,
                    r: Role) {.async.} = discard,
            guild_role_update: proc (s: Shard, g: Guild,
                    r: Role, o: Option[Role]) {.async.} = discard,
            invite_create: proc(s: Shard, i: InviteCreate) {.async.} = discard,
            invite_delete: proc (s: Shard, g: Option[Guild],
                    c, code: string) {.async.} = discard,
            user_update: proc (s: Shard, u: User) {.async.} = discard,
            voice_state_update: proc (s: Shard, v: VoiceState,
                    o: Option[VoiceState]) {.async.} = discard,
            voice_server_update: proc (s: Shard, g: Guild,
                    token: string,
                    e: Option[string]) {.async.} = discard,
            webhooks_update: proc (s: Shard, g: Guild,
                    c: GuildChannel) {.async.} = discard,
            on_disconnect: proc (s: Shard) {.async.} = discard,
            interaction_create: proc (s:Shard, i:Interaction){.async.} = discard,
            application_command_create: proc (s: Shard, g: Option[Guild],
                    a: ApplicationCommand) {.async.} = discard,
            application_command_update: proc(s: Shard, g: Option[Guild],
                    a: ApplicationCommand) {.async.} = discard,
            application_command_delete: proc (s: Shard,
                    g: Option[Guild], a: ApplicationCommand) {.async.} = discard,
            thread_create: proc (s: Shard, g: Guild,
                    c: GuildChannel) {.async.} = discard,
            thread_update: proc (s: Shard, g: Guild,
                    c:GuildChannel, o:Option[GuildChannel]){.async.} = discard,
            thread_delete: proc (s: Shard, g: Guild,
                    c: GuildChannel, exists: bool) {.async.} = discard,
            thread_list_sync: proc (s: Shard,
                    e: ThreadListSync) {.async.} = discard,
            thread_member_update: proc (s: Shard, g: Guild,
                    t: ThreadMember) {.async.} = discard,
            thread_members_update: proc (s: Shard,
                    e: ThreadMembersUpdate) {.async.} = discard,
            guild_scheduled_event_create: proc (
                    s: Shard, g: Guild,
                    e: GuildScheduledEvent) {.async.} = discard,
            guild_scheduled_event_delete: proc (
                    s: Shard, g: Guild,
                    e: GuildScheduledEvent) {.async.} = discard,
            guild_scheduled_event_update: proc (s: Shard,
                    g: Guild, e: GuildScheduledEvent,
                    o: Option[GuildScheduledEvent]
            ) {.async.} = discard,
            guild_scheduled_event_user_add: proc(
                    s: Shard, g: Guild,
                    e: GuildScheduledEvent, u: User) {.async.} = discard,
            guild_scheduled_event_user_remove: proc(s: Shard, g: Guild,
                    e: GuildScheduledEvent, u: User) {.async.} = discard,
        ))

proc parseHook*(s: string, i: var int, v: var set[UserFlags]) =
    var number: BiggestInt
    parseHook(s, i, number)
    v = cast[set[UserFlags]](number)

proc newUser*(data: JsonNode): User =
    result = ($data).fromJson(User)

proc postHook(p: var Presence) =
    if p.status == "": p.status = "offline"

    if p.client_status.web == "":
        p.client_status.web = "offline"
    if p.client_status.desktop == "":
        p.client_status.desktop = "offline"
    if p.client_status.mobile == "":
        p.client_status.mobile = "offline"

proc parseHook(s: string, i: var int, v: var set[ActivityFlags]) =
    var number: BiggestInt
    parseHook(s, i, number)
    v = cast[set[ActivityFlags]](number)

proc newPresence*(data: JsonNode): Presence =
    result = ($data).fromJson(Presence)

proc parseHook*(s: string, i: var int, v: var set[PermissionFlags]) =
    when defined(discordv8) or defined(discordv9):
        var str: string
        try:
            parseHook(s, i, str)
        except:
            str = "0"
        v = cast[set[PermissionFlags]](str.parseBiggestInt)
    else:
        var number: BiggestInt
        parseHook(s, i, number)
        v = cast[set[PermissionFlags]](number) # incase

proc newRole*(data: JsonNode): Role =
    result = ($data).fromJson(Role)
    if "tags" in data and "premium_subscriber" in data["tags"]:
        result.tags.get.premium_subscriber = some true

proc newHook(m: var Member) =
    m = Member()
    m.presence = Presence(
        status: "offline",
        clientStatus: (
            web: "offline",
            desktop: "offline",
            mobile: "offline"
        )
    )

proc postHook(m: var Member) =
    m.presence.user = m.user

proc newMember*(data: JsonNode): Member =
    result = ($data).fromJson(Member)

proc renameHook(v: var Overwrite, fieldName: var string) =
    if fieldName == "type":
        fieldName = "kind"

proc parseHook(s: string, i: var int, v: var set[MessageFlags]) =
    var number: BiggestInt
    parseHook(s, i, number)
    v = cast[set[MessageFlags]](number)

proc newOverwrite*(data: JsonNode): Overwrite =
    proc parseHook(s: string, i: var int, v: var int or string) =
        if s.contains("kind"):
            when defined(discordv8) or defined(discordv9):
                var str: string
                parseHook(s, i, str)
            except:
                var num: int
                parseHook(s, i, num)
    result = ($data).fromJson(Overwrite)

proc parseHook(s: string, i: var int, v: var Table[string, Overwrite]) =
    var overwrites: seq[Overwrite]
    parseHook(s, i, overwrites)
    for o in overwrites:
        v[o.id] = o

proc renameHook(v: var GuildChannel, fieldName: var string) =
    if fieldName == "type":
        fieldName = "kind"

proc parseHook(s: string, i: var int, v: var ChannelType) =
    var number: int
    parseHook(s, i, number)
    try:
        v = ChannelType number
    except:
        v = ctGuildText # just by default incase

proc renameHook(v: var MentionChannel, fieldName: var string) =
    if fieldName == "type":
        fieldName = "kind"

proc renameHook(v: var Embed, fieldName: var string) =
    if fieldName == "type":
        fieldName = "kind"

proc renameHook(s: var Message, fieldName: var string) =
    case fieldName:
    of "type":
        fieldName = "kind"
    of "mentions":
        fieldName = "mention_users"
    else:
        discard

proc renameHook(s: var tuple[kind: int, party_id: string];
    fieldName: var string) =
    if fieldName == "type":
        fieldName = "kind"

proc renameHook(s: var Reaction, fieldName: var string) =
    if fieldName == "me":
        fieldName = "reacted"

proc parseHook(s: string, i: var int, v: var Table[string, tuple[id, name: string, format_type: MessageStickerFormat]]) =
    var stickers: seq[tuple[
        id, name: string,
        format_type: MessageStickerFormat
    ]]
    parseHook(s, i, stickers)
    for s in stickers:
        v[s.id] = s

proc parseHook(s: string, i: var int, v: var Table[string, Reaction]) =
    var reactions: seq[Reaction]
    parseHook(s, i, reactions)
    for r in reactions:
        v[$r.emoji] = r

proc newMessage*(data: JsonNode): Message =
    result = data.`$`.fromJson(Message)

proc newGuildChannel*(data: JsonNode): GuildChannel =
    result = ($data).fromJson(GuildChannel)

proc newReaction*(data: JsonNode): Reaction =
    result = ($data).fromJson(Reaction)

proc newApplication*(data: JsonNode): Application =
    result = ($data).fromJson(Application)

proc renameHook(v: var PartialChannel, fieldName: var string) =
    if fieldName == "type":
        fieldName = "kind"

proc renameHook(v: var Webhook, fieldName: var string) =
    if fieldName == "type":
        fieldName = "kind"

proc renameHook(v: var Presence, fieldName: var string) =
    if fieldName == "game":
        fieldName = "activity"

proc parseHook(s: string, i: var int, v: var BiggestFloat) =
    var data: JsonNode
    parseHook(s, i, data)
    if data.kind == JInt:
        v = toBiggestFloat data.num
    elif data.kind == JInt:
        v = BiggestFloat data.fnum

proc parseHook(s: string, i: var int;
        v: var Option[tuple[start, final: BiggestFloat]]) =
    var table: Table[string, BiggestFloat]
    parseHook(s, i, table)
    v = some (
        start: table.getOrDefault("start", 0),
        final: table.getOrDefault("end", 0)
    )

proc renameHook(v: var Activity, fieldName: var string) =
    if fieldName == "type":
        fieldName = "kind"

proc newActivity*(data: JsonNode): Activity =
    result = ($data).fromJson(Activity)

proc renameHook(v: var AuditLogEntry, fieldName: var string) =
    if fieldName == "options":
        fieldName = "opts"

proc parseHook(s: string, i: var int, v: var Table[string, Role]) =
    var roles: seq[Role]
    parseHook(s, i, roles)
    for role in roles:
        v[role.id] = role

proc parseHook(s: string, i: var int, v: var Table[string, Sticker]) =
    var stickers: seq[Sticker]
    parseHook(s, i, stickers)
    for sticker in stickers:
        v[sticker.id] = sticker

proc parseHook(s: string, i: var int, v: var Table[string, StageInstance]) =
    var stages: seq[StageInstance]
    parseHook(s, i, stages)
    for stage in stages:
        v[stage.id] = stage

proc parseHook(s: string, i: var int, v: var Table[string, GuildScheduledEvent]) =
    var events: seq[GuildScheduledEvent]
    parseHook(s, i, events)
    for event in events:
        v[event.id] = event

proc parseHook(s: string, i: var int, v: var Table[string, Emoji]) =
    var emojis: seq[Emoji]
    parseHook(s, i, emojis)
    for emoji in emojis:
        v[emoji.id.get] = emoji

proc `[]=`(obj: ref object, fld: string, val: JsonNode) =
    for name, field in obj[].fieldPairs:
        if name == fld:
            field = ($val).fromJson(typeof(field))

proc newAuditLogChangeValue(data: JsonNode, key: string): AuditLogChangeValue =
    case data.kind:
    of JString:
        result = AuditLogChangeValue(kind: alcString)
        result.str = data.str
    of JInt:
        result = AuditLogChangeValue(kind: alcInt)
        result.ival = data.getInt
    of JBool:
        result = AuditLogChangeValue(kind: alcBool)
        result.bval = data.bval
    of JArray:
        if key in ["$add", "$remove"]:
            result = AuditLogChangeValue(kind: alcRoles)
            result.roles = data.elems.mapIt(
                it.`$`.fromJson tuple[id, name: string]
            )
        elif "permission_overwrites" in key:
            result = AuditLogChangeValue(kind: alcOverwrites)
            result.overwrites = ($data).fromJson seq[Overwrite]
    else:
        discard

proc parseHook(s: string, i: var int, a: var AuditLogEntry) =
    var data: JsonNode

    parseHook(s, i, data)
    a = AuditLogEntry()

    for k, val in data.pairs:
        case val.kind:
        of JBool, JInt, JFloat, JString:
            a[k] = val
        of JArray:
            if k == "changes":
                for c in val.elems:
                    if "new_value" in c:
                        a.after[c["key"].str] = newAuditLogChangeValue(
                            c["new_value"],
                            c["key"].str
                        )
                    if "old_value" in c:
                        a.before[c["key"].str] = newAuditLogChangeValue(
                            c["old_value"],
                            c["key"].str
                        )
            else:
                a[k] = val # incase
        of JObject:
            if "opts" in data:
                a.opts = some ($data["opts"]).fromJson AuditLogOptions
        else:
            discard

proc newIntegration*(data: JsonNode): Integration =
    result = ($data).fromJson(Integration)

proc newAuditLogEntry(data: JsonNode): AuditLogEntry =
    result = ($data).fromJson(AuditLogEntry)

proc newWebhook*(data: JsonNode): Webhook =
    result = ($data).fromJson(Webhook)

proc newAuditLog*(data: JsonNode): AuditLog =
    result = ($data).fromJson(AuditLog)

proc newVoiceState*(data: JsonNode): VoiceState =
    result = ($data).fromJson(VoiceState)

proc renameHook(v: var Guild, fieldName: var string) =
    when not defined(discordv9):
        if fieldName == "region":
            fieldName = "rtc_region"

proc parseHook(s: string, i: var int, v: var set[SystemChannelFlags]) =
    var number: BiggestInt
    parseHook(s, i, number)
    v = cast[set[SystemChannelFlags]](number)

proc parseHook(s: string, i: var int, g: var Guild) =
    var data: JsonNode
    parseHook(s, i, data)

    g = new Guild
    g.id = data["id"].str # just in case

    for v in data{"members"}.getElems:
        let member = v.newMember
        g.members[member.user.id] = member

    for k, val in data.pairs:
        case val.kind:
        of JBool, JInt, JFloat, JString, JObject:
            g[k] = val
        of JArray:
            case k:
            of "voice_states":
                for v in val.getElems:
                    let state = v.newVoiceState

                    g.members[state.user_id].voice_state = some state
                    g.voice_states[state.user_id] = state
            of "threads":
                for v in val.getElems:
                    v["guild_id"] = %g.id
                    g.threads[v["id"].str] = v.newGuildChannel
            of "channels":
                for v in val.getElems:
                    v["guild_id"] = %g.id
                    g.channels[v["id"].str] = v.newGuildChannel
            of "presences":
                for v in val.getElems:
                    v["guild_id"] = %g.id
                    let p = v.newPresence

                    if p.user.id in g.members:
                        g.members[p.user.id].presence = p
                    g.presences[p.user.id] = p
            else:
                if k != "members":
                    g[k] = val
        else:
            discard

proc newGuild*(data: JsonNode): Guild =
    result = ($data).fromJson(Guild)

proc newGuildBan*(data: JsonNode): GuildBan =
    result = ($data).fromJson(GuildBan)

proc newDMChannel*(data: JsonNode): DMChannel = # rip dmchannels
    result = ($data).fromJson(DMChannel)

proc newStageInstance*(data: JsonNode): StageInstance =
    result = ($data).fromJson(StageInstance)

proc newEmoji*(data: JsonNode): Emoji =
    result = ($data).fromJson(Emoji)

proc newInvite*(data: JsonNode): Invite =
    result = ($data).fromJson(Invite)

proc newInviteCreate*(data: JsonNode): InviteCreate =
    result = ($data).fromJson(InviteCreate)

proc parseHook(s: string, i: var int, v: var tuple[id: string, flags: set[ApplicationFlags]]) =
    var table: Table[string, JsonNode]
    parseHook(s, i, table)
    v.id = table["id"].str
    v.flags = cast[set[ApplicationFlags]](table["flags"].num)

proc newReady*(data: JsonNode): Ready =
    result = ($data).fromJson(Ready)

proc newAttachment(data: JsonNode): Attachment =
    result = ($data).fromJson(Attachment)

proc newTypingStart*(data: JsonNode): TypingStart =
    result = ($data).fromJson(TypingStart)

proc newGuildMembersChunk*(data: JsonNode): GuildMembersChunk =
    result = ($data).fromJson(GuildMembersChunk)

proc newGuildPreview*(data: JsonNode): GuildPreview =
    result = ($data).fromJson(GuildPreview)

proc newInviteMetadata*(data: JsonNode): InviteMetadata =
    result = InviteMetadata(
        code: data["code"].str,
        uses: data["uses"].getInt,
        max_uses: data["max_uses"].getInt,
        max_age: data["max_age"].getInt,
        temporary: data["temporary"].bval,
        created_at: data["created_at"].str
    )

proc updateMessage*(m: Message, data: JsonNode): Message =
    result = m

    result.mention_users = data{"mentions"}.getElems.map(newUser)
    result.attachments = data{"attachments"}.getElems.map(newAttachment)
    result.embeds = data{"embeds"}.getElems.mapIt(it.to(Embed))

    if "type" in data and data["type"].kind != JNull:
        result.kind = MessageType data["type"].getInt
    if "flags" in data and data["flags"].kind != JNull:
        result.flags = cast[set[MessageFlags]](data["flags"].getInt)

    data.keyCheckStr(result, content, timestamp)
    data.keyCheckOptStr(result, edited_timestamp, guild_id)
    data.keyCheckBool(result, mention_everyone, pinned, tts)

    if "author" in data:
        result.author = newUser(data["author"])
    if "activity" in data:
        let activity = data["activity"]

        result.activity = some (
            kind: activity["type"].getInt,
            party_id: activity{"party_id"}.getStr
        )

    if "application" in data:
        result.application = some data["application"].newApplication

proc newSticker*(data: JsonNode): Sticker =
    result = ($data).fromJson(Sticker)

proc newStickerPack*(data: JsonNode): StickerPack =
    result = ($data).fromJson(StickerPack)

proc newGuildTemplate*(data: JsonNode): GuildTemplate =
    result = ($data).fromJson(GuildTemplate)

proc newApplicationCommandInteractionDataOption(
    data: JsonNode
): ApplicationCommandInteractionDataOption =
    result = ApplicationCommandInteractionDataOption(
        kind: ApplicationCommandOptionType data["type"].getInt
    )
    result.name = data["name"].getStr
    if result.kind notin {acotSubCommand, acotSubCommandGroup}:
        # SubCommands/Groups don't have a value
        let value = data["value"]
        case result.kind
        of acotBool:
            result.bval       = value.bval
        of acotInt:
            result.ival       = value.getBiggestInt
        of acotStr:
            result.str        = value.getStr
        of acotUser:
            result.user_id    = value.getStr
        of acotChannel:
            result.channel_id = value.getStr
        of acotRole:
            result.role_id    = value.getStr
        else: discard
        if "focused" in data: result.focused = some data{"focused"}.getBool
    else:
        # Convert the array of sub options into a key value table
        result.options = toTable data{"options"}
            .getElems
            .mapIt((
                it["name"].str,
                newApplicationCommandInteractionDataOption(it)
            ))
        # Nice trick, ire.

proc newApplicationCommandInteractionData*(
    data: JsonNode
): ApplicationCommandInteractionData =
    if "component_type" in data:
        result = ApplicationCommandInteractionData(
            interactionType: idtMessageComponent,
            component_type: MessageComponentType data["component_type"].getInt 1,
            custom_id: data["custom_id"].str
        )
        if result.component_type == SelectMenu:
            result.values = data["values"].getElems.mapIt(it.str)
    else:
        result = ApplicationCommandInteractionData(
            interactionType: idtApplicationCommand,
            id: data["id"].str,
            name: data["name"].str,
            kind: ApplicationCommandType data{"type"}.getInt
        )
        case result.kind:
        of atSlash:
            for option in data{"options"}.getElems:
                result.options[option["name"].str] =
                    newApplicationCommandInteractionDataOption(option)
        of atUser, atMessage:
            result.target_id = data["target_id"].str
            # Set the resolution kind to be the same as the interaction
            # data kind, saves the user needing to user options when it
            # isn't necessary
            var resolution = ApplicationCommandResolution(kind: result.kind)
            let resolvedJson = data["resolved"]
            if result.kind == atUser:
                # Get users
                for id, jsonData in resolvedJson{"users"}:
                    resolution.users[id] = newUser(jsonData)
                # Get members
                for id, jsonData in resolvedJson{"members"}:
                    resolution.members[id] = newMember(jsonData)
            else: # result.kind will equal atMessage
                # Get messages
                for id, jsonData in resolvedJson{"messages"}:
                    resolution.messages[id] = newMessage(jsonData)
            result.resolved = resolution
        else:
            discard

proc newInteraction*(data: JsonNode): Interaction =
    result = Interaction(
        id: data["id"].str,
        kind: InteractionType data["type"].getInt,
        token: data["token"].str,
        version: data["version"].getInt
    )
    data.keyCheckOptStr(result, channel_id, guild_id)

    if "member" in data and data["member"].kind != JNull:
        result.member = some data["member"].newMember
    if "user" in data and data["user"].kind != JNull:
        result.user = some data["user"].newUser
    if "message" in data and data["message"].kind != JNull:
        result.message = some data["message"].newMessage
    if "data" in data and data["data"].kind != JNull: # nice
        result.data = some newApplicationCommandInteractionData(data["data"])

proc newApplicationCommandOption*(data: JsonNode): ApplicationCommandOption =
    result = ApplicationCommandOption(
        kind: ApplicationCommandOptionType data["type"].getInt,
        name: data["name"].str,
        description: data["description"].str,
        choices: data{"choices"}.getElems.map(
            proc (x: JsonNode): ApplicationCommandOptionChoice =
                result = ApplicationCommandOptionChoice(
                    name: x["name"].str)
                if x["value"].kind == JInt:
                    result.value[1] = some x["value"].getInt # this is 
                if x["value"].kind == JString: # a tuple btw
                    result.value[0] = some x["value"].str
        ),
        options: data{"options"}.getElems.map newApplicationCommandOption
    )
    data.keyCheckOptBool(result, required)

proc `%%*`*(a: ApplicationCommandOption): JsonNode =
    result = %*{"type": int a.kind, "name": a.name,
                "description": a.description,
                "required": %(a.required.get false),
                "autocomplete": %a.autocomplete
    }

    if a.choices.len > 0:
        result["choices"] = %a.choices.map(
            proc (x: ApplicationCommandOptionChoice): JsonNode =
                let json = %*{"name": %x.name}
                if x.value[0].isSome:
                    json["value"] = %x.value[0]
                if x.value[1].isSome:
                    json["value"] = %x.value[1]
                return json
        )
    if a.options.len > 0:
        result["options"] = %a.options.map(
            proc (x: ApplicationCommandOption): JsonNode =
                return %%*x # avoid conflicts with json
        )

proc `%%*`*(a: ApplicationCommand): JsonNode =
    assert a.name.len in 3..32
    # This ternary is needed so that the enums can stay similar to
    # the discord api
    let commandKind = if a.kind == atNothing: atSlash else: a.kind
    result = %*{
        "name": a.name,
        "type": commandKind.ord
    }
    if commandKind == atSlash:
        assert a.description.len in 1..100
        result["description"] = %a.description
        if a.options.len > 0: result["options"] = %(a.options.map(
            proc (x: ApplicationCommandOption): JsonNode =
                %%*x
        ))
    result["default_permission"] = %a.default_permission

proc newApplicationCommandPermission*(
    data: JsonNode
): ApplicationCommandPermission =
    result = ApplicationCommandPermission(
        id: data["id"].str,
        kind: ApplicationCommandPermissionType data["type"].getInt,
        permission: data["permission"].getBool true
    )

proc newGuildApplicationCommandPermissions*(
    data: JsonNode
): GuildApplicationCommandPermissions =
    result = GuildApplicationCommandPermissions(
        id: data["id"].str,
        application_id: data["application_id"].str,
        guild_id: data["guild_id"].str
    )
    result.permissions = data{"permissions"}.getElems.map(
        newApplicationCommandPermission
    )

proc newApplicationCommand*(data: JsonNode): ApplicationCommand =
    result = ApplicationCommand(
        id: data["id"].str,
        kind: ApplicationCommandType data["type"].getInt,
        application_id: data["application_id"].str,
        name: data["name"].str,
        description: data["description"].str,
        options: data{"options"}.getElems.map newApplicationCommandOption,
        default_permission: data{"default_permission"}.getBool true
    )

proc toPartial(emoji: Emoji): JsonNode =
    ## Creates a partial emoji from an Emoji object
    result = %* { # create partial emoji
        "name": emoji.name,
        "id": emoji.id,
        "animated": emoji.animated
    }

proc `%`(option: SelectMenuOption): JsonNode =
    result = %* {
        "label": option.label,
        "value": option.value,
        "description": option.description,
        "default": option.default.get false
    }
    if option.emoji.isSome:
        result["emoji"] = option.emoji.get.toPartial

proc `%`*(permission: ApplicationCommandPermission): JsonNode =
    result = %*{
        "id": %permission.id,
        "type": %ord permission.kind,
        "permission": %permission.permission
    }

proc `%%*`*(comp: MessageComponent): JsonNode =
    result = %*{"type": comp.kind.ord}
    case comp.kind:
        of None: discard
        of ActionRow:
            result["components"] = newJArray()
            for child in comp.components:
                result["components"] &= %%* child
        of Button:
            result["custom_id"] =   %comp.custom_id.get
            result["label"] =       %comp.label
            result["style"] =       %comp.style.ord
            result["url"] =         %comp.url
            if comp.emoji.isSome:
                result["emoji"] =   comp.emoji.get.toPartial
        of SelectMenu:
            result["custom_id"] =   %comp.custom_id.get
            result["options"] =     %comp.options
            result["placeholder"] = %comp.placeholder
            result["min_values"] =  %comp.minValues
            result["max_values"] =  %comp.maxValues
        of TextInput:
            result["placeholder"] =    %comp.placeholder
            result["style"] =          %int comp.input_style
            result["label"] =          %comp.input_label
            if comp.value.isSome:
                result["value"] =      %comp.value.get
            if comp.required.isSome:
                result["required"] =   %comp.required.get
            if comp.min_length.isSome:
                result["min_length"] = %comp.min_length.get
            if comp.max_length.isSome:
                result["max_length"] = %comp.max_length.get