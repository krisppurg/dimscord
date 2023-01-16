## This contains every single discord objects
## All Optional fields in these object are:
##
## * Fields that cannot be assumed. such as bools
## * Optional fields for example embeds, which they may not be
##   present.
##   
## Some may not be optional, but they can be assumable or always present.

when (NimMajor, NimMinor, NimPatch) >= (1, 6, 0):
    {.warning[HoleEnumConv]: off.}
    {.warning[CaseTransition]: off.}

import options
import sequtils, strutils, jsony
import std/with
include objects/typedefs, objects/macros

macro enumElementsAsSet(enm: typed): untyped =
    result = newNimNode(nnkCurly).add(enm.getType[1][1..^1])

func fullSet*[T](U: typedesc[T]): set[T] {.inline.} =
    when T is Ordinal:
        {T.low..T.high}
    else: # Hole filled enum
        enumElementsAsSet(T)

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
        restVersion = 10): DiscordClient =
    ## Creates a Discord Client.
    var auth_token = token
    if not token.startsWith("Bot ") and not token.startsWith("Bearer "):
        auth_token = "Bot " & token
    
    var apiVersion = restVersion
    when defined(discordv9):
        apiVersion = 9

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
                    e: Option[string], initial: bool) {.async.} = discard,
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
            auto_moderation_rule_create: proc(s:Shard,
                g: Guild, r: AutoModerationRule) {.async.} = discard,
            auto_moderation_rule_update: proc(s: Shard,
                g: Guild, r: AutoModerationRule) {.async.} = discard,
            auto_moderation_rule_delete: proc(s: Shard,
                g: Guild, r: AutoModerationRule) {.async.} = discard,
            auto_moderation_action_execution: proc(s: Shard,
                g: Guild, e: ModerationActionExecution) {.async.} = discard
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
    var str: string
    try:
        parseHook(s, i, str)
    except:
        str = "0"
    v = cast[set[PermissionFlags]](str.parseBiggestInt)

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
            var str: string
            parseHook(s, i, str)
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
    if ChannelType(number) in fullSet(ChannelType):
        v = ChannelType number
    else:
        v = ctGuildText # just by default incase

proc renameHook(v: var MentionChannel, fieldName: var string) =
    if fieldName == "type":
        fieldName = "kind"

proc parseHook(s: string; i: var int; v: var set[ApplicationFlags]) {.used.} =
    var bint: BiggestInt
    try:
        parseHook(s, i, bint)
    except:
        bint = 0
    v = cast[set[ApplicationFlags]](bint)

proc parseHook(s: string; i: var int; v: var set[ChannelFlags]) {.used.} =
    var bint: BiggestInt
    try:
        parseHook(s, i, bint)
    except:
        bint = 0
    v = cast[set[ChannelFlags]](bint)

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

proc renameHook(s: var MessageInteraction, fieldName: var string) =
    if fieldName == "type":
        fieldName = "kind"

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

proc renameHook(v: var Presence, fieldName: var string) {.used.} =
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
        v: var Option[tuple[start, final: BiggestFloat]]) {.used.} =
    var table: Table[string, BiggestFloat]
    parseHook(s, i, table)
    v = some (
        start: table.getOrDefault("start", 0),
        final: table.getOrDefault("end", 0)
    )

proc renameHook(v: var Activity, fieldName: var string) {.used.} =
    if fieldName == "type":
        fieldName = "kind"

proc newActivity*(data: JsonNode): Activity =
    result = ($data).fromJson(Activity)

proc renameHook(v: var AuditLogEntry, fieldName: var string) {.used.} =
    if fieldName == "options":
        fieldName = "opts"

proc parseHook(s: string, i: var int, v: var Table[string, Role]) {.used.} =
    var roles: seq[Role]
    parseHook(s, i, roles)
    for role in roles:
        v[role.id] = role

proc parseHook(s: string, i: var int, v: var Table[string, Sticker]) {.used.} =
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

proc newAuditLogEntry*(data: JsonNode): AuditLogEntry =
    result = ($data).fromJson(AuditLogEntry)

proc newWebhook*(data: JsonNode): Webhook =
    result = ($data).fromJson(Webhook)

proc newAuditLog*(data: JsonNode): AuditLog =
    result = ($data).fromJson(AuditLog)

proc newVoiceState*(data: JsonNode): VoiceState =
    result = ($data).fromJson(VoiceState)

proc renameHook(v: var Guild, fieldName: var string) {.used.} =
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

proc parseHook(s: string;
    i: var int;
    v: var tuple[id: string, flags: set[ApplicationFlags]]
) =
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
    result = data.`$`.fromJson(InviteMetadata)

proc updateMessage*(m: Message, data: JsonNode): Message =
    result = m

    with result:
        mention_users = data{"mentions"}.getElems.map(newUser)
        attachments = data{"attachments"}.getElems.map(newAttachment)
        embeds = data{"embeds"}.getElems.mapIt(it.`$`.fromJson(Embed))
    if result.referenced_message.isSome and "referenced_message" in data:
        result.referenced_message = some data["referenced_message"].newMessage
    if result.messageReference.isSome:
        if "message_reference"in data and data["message_reference"].kind!=JNull:
            result.message_reference = some ($data{"message_reference"}).fromJson(
                MessageReference
            )

    with data:
        keyCheckStr(result, content, timestamp)
        keyCheckOptStr(result, edited_timestamp, guild_id, nonce)
        keyCheckBool(result, mention_everyone, pinned, tts)

    if "type" in data and data["type"].kind != JNull:
        if MessageType(data["type"].getInt) in fullSet(MessageType):
            result.kind = MessageType data["type"].getInt
        else:
            result.kind = mtDefault

    if "flags" in data and data["flags"].kind != JNull:
        result.flags = cast[set[MessageFlags]](data["flags"].getInt)
    if "author" in data:
        result.author = data["author"].newUser
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

proc parseHook(s: string, i: var int,v: var (Option[string], Option[int]))=
    var value: JsonNode
    parseHook(s, i, value)

    case value.kind:
    of JString:
        v = (some value.str, none int)
    of JInt:
        v = (none string, some value.getInt)
    else: discard

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
        of acotMentionable:
            result.mention_id = value.getStr
        of acotAttachment:
            result.aval       = value.getStr
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

proc parseHook(s: string, i: var int;
    v: var Table[string, ApplicationCommandInteractionDataOption]
) =
    var data: seq[JsonNode]
    parseHook(s, i, data)
    for o in data:
        v[o["name"].str] = newApplicationCommandInteractionDataOption(o)

proc renameHook(v: var ApplicationCommandInteractionData,
    fieldName: var string) {.used.} =
    if fieldName == "type":
        fieldName = "kind"

proc renameHook(v: var ApplicationCommandInteractionDataOption,
    fieldName: var string) {.used.} =
    if fieldName == "type":
        fieldName = "kind"

proc renameHook(v: var MessageComponent, fieldName: var string) {.used.} =
    if fieldName == "type":
        fieldName = "kind"

proc parseHook(s: string, i: var int, v: var MessageComponentType) =
    var number: int
    parseHook(s, i, number)
    try:
        v = MessageComponentType number
    except:
        v = MessageComponentType 1

proc parseHook(s: string, i: var int, v: var ApplicationCommandType) =
    var number: int
    parseHook(s, i, number)
    try:
        v = ApplicationCommandType number
    except:
        v = atSlash # just by default incase

proc renameHook(v: var ResolvedChannel, fieldName: var string) {.used.} =
    if fieldName == "type":
        fieldName = "kind"

proc parseHook(s: string, n: var int, a: var ApplicationCommandInteractionData) =
    var data: JsonNode
    parseHook(s, n, data)

    if "component_type" in data:
        a = ApplicationCommandInteractionData(
            interactionType: idtMessageComponent,
            component_type: MessageComponentType data["component_type"].getInt 1,
            custom_id: data["custom_id"].str
        )
        # if a.component_type == SelectMenu:
        #     a.values = val["values"].getElems.mapIt(it.str)
        data.delete("component_type")
    else:
        if "custom_id" in data:
            a = ApplicationCommandInteractionData(
                interaction_type: idtModalSubmit,
                custom_id: data["custom_id"].str
            )
        else:
            a = ApplicationCommandInteractionData(
                interaction_type: idtApplicationCommand,
                kind: ($data["type"]).fromJson(ApplicationCommandType)
            )

            a.resolved=ApplicationCommandResolution(kind: a.kind)
            if "resolved" in data:
                for key, values in data["resolved"].getFields.pairs:
                    case key:
                    of "users":
                        for k, v in values.pairs:
                            a.resolved.users[k] = ($v).fromJson User
                    of "attachments":
                        for k, v in values.pairs:
                            a.resolved.attachments[k] = ($v).fromJson Attachment
                    else: discard

                    if a.kind == atUser:
                        case key:
                        of "members":
                            for k, v in values.pairs:
                                a.resolved.members[k] = ($v).fromJson Member
                        of "roles":
                            for k, v in values.pairs:
                                a.resolved.roles[k] = ($v).fromJson Role
                        else: discard

                    if a.kind == atMessage:
                        case key:
                        of "channels":
                            for k, v in values.pairs:
                                a.resolved.channels[k] = ($v).fromJson(
                                    ResolvedChannel
                                )
                        of "messages":
                            for k, v in values.pairs:
                                a.resolved.messages[k] = ($v).fromJson Message
                        else: discard

    for k, val in data.pairs:
        case val.kind:
        of JBool, JInt, JFloat, JString, JObject, JArray:
            if k != "resolved": a[k] = val
        else:
            discard
    if a.interaction_type == idtModalSubmit: a.component_type = TextInput

proc renameHook(v: var Interaction, fieldName: var string) {.used.} =
    if fieldName == "type":
        fieldName = "kind"

proc renameHook(v: var ApplicationCommandPermission, fieldName: var string) {.used.} =
    if fieldName == "type":
        fieldName = "kind"

proc renameHook(v: var ApplicationCommandOption, fieldName: var string) {.used.} =
    if fieldName == "type":
        fieldName = "kind"

proc renameHook(v: var ApplicationCommand, fieldName: var string) {.used.} =
    if fieldName == "type":
        fieldName = "kind"

proc newApplicationCommandInteractionData*(
    data: JsonNode
): ApplicationCommandInteractionData =
    result = data.`$`.fromJson(ApplicationCommandInteractionData)

proc newInteraction*(data: JsonNode): Interaction =
    result = data.`$`.fromJson(Interaction)

proc newApplicationCommandOption*(data: JsonNode): ApplicationCommandOption =
    result = data.`$`.fromJson(ApplicationCommandOption)

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
    result = data.`$`.fromJson ApplicationCommandPermission

proc newGuildApplicationCommandPermissions*(
    data: JsonNode
): GuildApplicationCommandPermissions =
    result = data.`$`.fromJson GuildApplicationCommandPermissions

proc newApplicationCommand*(data: JsonNode): ApplicationCommand =
    result = data.`$`.fromJson ApplicationCommand

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
    if comp.disabled.isSome:
        result["disabled"] = %comp.disabled.get
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
        of SelectMenu, UserSelect, RoleSelect, MentionableSelect, ChannelSelect:
            result["custom_id"] =   %comp.custom_id.get
            result["options"] =     %comp.options
            result["placeholder"] = %comp.placeholder
            result["min_values"] =  %comp.minValues
            result["max_values"] =  %comp.maxValues
            if comp.channel_types.len > 0:
                result["channel_types"] = newJArray()
                for channel_type in comp.channel_types:
                    result["channel_types"] &= %channel_type.ord
        of TextInput:
            result["custom_id"] =   %comp.custom_id.get
            result["placeholder"] =    %comp.placeholder
            result["style"] =          %int comp.input_style.get
            result["label"] =          %comp.input_label.get
            if comp.value.isSome:
                result["value"] =      %comp.value.get
            if comp.required.isSome:
                result["required"] =   %comp.required.get
            if comp.min_length.isSome:
                result["min_length"] = %comp.min_length.get
            if comp.max_length.isSome:
                result["max_length"] = %comp.max_length.get