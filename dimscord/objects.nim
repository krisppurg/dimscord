## This contains every single discord objects
## All Optional fields in these object are:
##
## * Fields that cannot be assumed. such as bools
## * Optional fields for example embeds, which they may not be
##   present.
##
## Some may not be optional, but they can be assumable or always present.
##
##
## One of the most important objects is [Events] and is used to register events with help of macros.
## 
## .. raw:: html
##    <details>
##    <summary>Expand for more information</summary>
## .. code-block:: nim
##    # For interaction_create for instance
##    proc interaction_create(s: Shard, i: Interaction) {.event(discord).} =
##      ...
##    
##    # The {.event(discord).} pragma is a macro which rewrites the expression as this:
##    discord.events.interaction_create = proc interaction_create(s: Shard, i: Interaction) {.async.} =
##      ...
##    
##    # the event name is also case insensitive (except for first letter),
##    # thanks to Nim's flexibility so writing the following would be valid equivalent.
##    
##    proc interactionCreate(s: Shard, i: Interaction) {.event(discord).} =
##      ...
##    
##    # just don't forget the pragma, it also automatically adds in the {.async.} pragma
##    # hence why use of async/await inside proc is valid.
## .. raw:: html
##    </details>
## .

{.warning[HoleEnumConv]: off.}
{.warning[CaseTransition]: off.}

import options
import sequtils, strutils, strformat, jsony {.all.}
import tables, sets, typetraits

include objects/typedefs, objects/macros

template softAssertImpl(cond: bool, expr: string, msg="") =
    var message = block:
        if msg == "":
            "Condition not satisfied: "&"`"&expr&"`"
        else:
            msg
    if not cond:
        raise newException(RequesterError, message&" (`"&expr&"`)")

template softAssert*(cond: untyped, msg = "") =
    softAssertImpl(cond, astToStr(cond), msg)

proc newInteractionData*(
        content: string,
        embeds: seq[Embed],
        flags: set[MessageFlags],
        attachments: seq[Attachment],
        components: seq[MessageComponent],
        allowed_mentions: AllowedMentions,
        tts: Option[bool]
): InteractionCallbackDataMessage =
    result = InteractionCallbackDataMessage(
        content: content,
        embeds:  embeds,
        allowed_mentions: allowed_mentions,
        flags: flags,
        attachments: attachments,
        components: components,
        tts: tts
    )

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
                    emj: Emoji, exists: bool) {.async.} = discard,
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
            guild_audit_log_entry_create: proc (s: Shard, g: Guild,
                    e: AuditLogEntry) {.async.} = discard,
            guild_integrations_update: proc (s: Shard,
                    g: Guild) {.async.} = discard,
            integration_create: proc (s: Shard, u: User,
                    g: Guild) {.async.} = discard,
            integration_update: proc (s: Shard, u: User,
                    g: Guild) {.async.} = discard,
            integration_delete: proc (s: Shard, integ_id: string, g: Guild,
                    app_id: Option[string]) {.async.} = discard,
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
            voice_channel_effect_send: proc (s: Shard,
                    e: VoiceChannelEffectSend) {.async.} = discard,
            guild_soundboard_sound_create: proc (s: Shard,
                    ss: SoundboardSound) {.async.} = discard,
            guild_soundboard_sound_update: proc (s: Shard,
                    ss: SoundboardSound) {.async.} = discard,
            guild_soundboard_sound_delete: proc (s: Shard,
                    sound_id, guild_id: string) {.async.} = discard,
            guild_soundboard_sounds_update: proc (s: Shard,
                    guild_id: string,
                    soundboard_sounds: seq[SoundboardSound]) {.async.} = discard,
            soundboard_sounds: proc (s: Shard,
                    guild_id: string,
                    soundboard_sounds: seq[SoundboardSound]) {.async.} = discard,
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
                g: Guild, e: ModerationActionExecution) {.async.} = discard,
            message_poll_vote_add: proc(s: Shard, m: Message, u: User,
                    ans_id: int){.async.} = discard,
            message_poll_vote_remove: proc(s: Shard, m: Message, u: User,
                    ans_id: int){.async.} = discard,
            entitlement_create: proc(s: Shard, e: Entitlement){.async.} = discard,
            entitlement_update: proc(s: Shard, e: Entitlement){.async.} = discard,
            entitlement_delete: proc(s: Shard, e: Entitlement) {.async.} = discard
        ))

proc extractFieldName(s: string, i: var int): string =
    result = ""
    for idx in countdown(i-1, 0):
        let isQuote = s[idx] == "\""[0]
        if result == "":
            if isQuote: result = $s[idx-1] else: continue 
        else:
            if isQuote: return result[1..^1] else: result = s[idx-1] & result

proc logParser*(msg: string, s = "") =
    when defined(dimscordDebug):
        var finalmsg = "[JsonParser]: " & msg

        when defined(jsonyDumps):
            finalmsg &= "\n    JSON Dump: " & s
        else:
            finalmsg &= "\nFor more information define -d:jsonyDumps"

        echo finalmsg

proc parseHook[T](s: string, i: var int, v: var set[T]) =
    var data: JsonNode
    jsony.parseHook(s, i, data)

    case data.kind:
    of JString:
        try:
            v = cast[set[T]](data.str.parseInt)
        except:
            v = {}
    of JInt:
        v = cast[set[T]](data.num)
    else:
        v = {}

proc fromJson*[T](s: string, x: typedesc[T]): T =
    try:
        var i = 0
        parseHook(s, i, result)
    except jsony.JsonError:
        let message = getCurrentExceptionMsg()
        logParser(message, s)
        try:
            var offset = parseInt(message.split(' ')[^1])
            let fieldname = extractFieldName(s, offset)
            log(fmt"Error during JSON serialization - there's a type mismatch on field: '{fieldname}' inside {$x}")
            skipValue(s, offset)
        except:
            raise

proc parseHook(s: string, i: var int, v: var (int|float)) =
    var data: JsonNode
    parseHook(s, i, data)

    case data.kind:
    of JFloat:
        when v is float:
            v = data.fnum
        else:
            logParser(fmt"Expected integer but got float instead at offset: {$i}", s)
            v = -1
    of JInt:
        when v is int: v = data.num else: v = float(data.num)
    of JString:
        when v is int:
            try:
                v = parseInt(data.str)
            except:
                v = -1
        else:
            v = -1.0
    else:
        when v is float: v = -1.0 else: v = -1

proc parseHook[T: enum](s: string, i: var int, v: var T) =
    var data: JsonNode
    jsony.parseHook(s, i, data)

    if data.kind == JInt and data.getInt in ord(T.low)..ord(T.high):
        v = type(v)(data.getInt)
    else:
        var default = T.low
        if not (($default).contains("Unknown") or ($default).contains("None")):
            when v is ChannelType:
                default = ctGuildText
            else:
                default = T.high
        logParser(fmt"Error parsing enum {$T} - using default: {default}", s)

        skipValue(s, i)
        v = default

proc parseHook[T](s: string, i: var int, v: var seq[T]) =
    try:
        jsony.parseHook(s, i, v)
    except:
        logParser(fmt"Error parsing generic type {$type(v)} - using default: @[]", s)
        skipValue(s, i)
        v = @[]

proc parseHook(s: string, i: var int, v: var string) =
    try:
        jsony.parseHook(s, i, v)
    except:
        logParser(getCurrentExceptionMsg(), s)
        skipValue(s, i)
        v = ""

proc renameHook(s: var (object | ref object | tuple), fieldName: var string) =
    case fieldName:
    of "type":
        fieldName="kind"
    of "me": # Message
        fieldName="reacted"
    of "mentions": # Message
        fieldName="mention_users"

proc parseHook(s:string,i:var int,v:var (Option[string],Option[int])) {.used.} =
    var value: JsonNode
    parseHook(s, i, value)

    case value.kind:
    of JString:
        v = (some value.str, none int)
    of JInt:
        v = (none string, some value.getInt)
    else:
        v = (none string, none int)

proc parseHook(s:string,i:var int,v:var (Option[BiggestInt], Option[float])) {.used.} =
    var value: JsonNode
    parseHook(s, i, value)

    case value.kind:
    of JInt:
        v = (some value.num, none float)
    of JFloat:
        v = (none BiggestInt, some value.fnum)
    else:
        v = (none BiggestInt, none float)

proc parseHook(s: string, i: var int;
        v: var seq[tuple[label, url: string]]) {.used.} =
    var data: JsonNode
    parseHook(s, i, data)
    for btn in data:
        if btn.kind == JString:
            v.add (label: btn.getStr, url: "")
        elif btn.kind == JObject:
            v.add (label: btn{"label"}.getStr, url: btn{"url"}.getStr)

proc postHook(p: var Presence) =
    if p.status == "": p.status = "offline"

    if p.client_status.web == "":
        p.client_status.web = "offline"
    if p.client_status.desktop == "":
        p.client_status.desktop = "offline"
    if p.client_status.mobile == "":
        p.client_status.mobile = "offline"

proc postHook(m: var Message) =
    if m.member.isSome:
        if m.member.get.user == nil and m.author != nil:
            m.member.get.user = m.author
            m.member.get.presence.user = m.author
        if m.member.get.presence.guild_id == "":
            m.member.get.presence.guild_id = m.guild_id.get

proc parseHook*(s: string, i: var int, v: var OverwriteType) =
    var data: JsonNode
    parseHook(s, i, data)
    case data.kind:
    of JString: # audit log options
        v = OverwriteType parseInt(data.str)
    of JInt:
        v = OverwriteType data.getInt
    else: discard

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
    if m.user != nil: m.presence.user = m.user
    if m.presence.guild_id == "" and m.guild_id != "":
        m.presence.guild_id = m.guild_id

proc parseHook(s: string, i: var int, v: var Table[string, Overwrite]) =
    var overwrites: seq[Overwrite]
    parseHook(s, i, overwrites)
    for o in overwrites:
        v[o.id] = o

proc parseHook(s: string, i: var int,
    v: var Table[string, tuple[
        id, name: string,
        format_type: MessageStickerFormat]]) =

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

proc parseHook(s: string, i: var int;
    v: var Table[ApplicationIntegrationType, ApplicationIntegrationTypeConfig]) =
    var data: JsonNode
    parseHook(s, i, data)
    for k, val in data.fields:
        v[ApplicationIntegrationType(parseInt(k))] = ($val).fromJson(
            ApplicationIntegrationTypeConfig)

proc parseHook(s: string, i: var int, v: var Table[string, Attachment]) =
    if s[i] == '{': # this is for ResolvedData object, we'll need to check first char if it's an object.
        jsony.parseHook(s, i, v)
    else:
        var attachments: seq[Attachment]
        parseHook(s, i, attachments)
        for a in attachments:
            v[a.id] = a

proc parseHook(s: string, i: var int, v: var Table[string, Message]) =
    if s[i] == '{': # this is for ResolvedData object, we'll need to check first char if it's an object.
        jsony.parseHook(s, i, v)
    else:
        var msgs: seq[Message]
        parseHook(s, i, msgs)
        for m in msgs:
            v[m.id] = m

proc parseHook(s: string, i: var int;
        v: var Option[tuple[start, final: BiggestFloat]]) {.used.} =
    var table: Table[string, BiggestFloat]
    parseHook(s, i, table)
    v = some (
        start: table.getOrDefault("start", 0),
        final: table.getOrDefault("end", 0)
    )

proc newActivity*(data: JsonNode): Activity =
    result = ($data).fromJson(Activity)

proc newRole*(data: JsonNode): Role =
    result = ($data).fromJson(Role)
    if "tags" in data:
        let tag = data["tags"]
        result.tags.get.premium_subscriber = some "premium_subscriber" in tag
        result.tags.get.available_for_purchase = some(
            "available_for_purchase" in tag)
        result.tags.get.guild_connections = some "guild_connections" in tag

proc parseHook(s: string, i: var int, v: var Table[string, Role]) {.used.} =
    if s[i] == '{': # this is for ResolvedData object, we'll need to check first char if it's an object.
        jsony.parseHook(s, i, v)
    else:
        var roles: seq[JsonNode]
        parseHook(s, i, roles)
        for role in roles:
            v[role["id"].str] = newRole role

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
            break

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
            if "options" in data:
                a.options = some ($data["options"]).fromJson AuditLogOptions
        else:
            discard

proc newPresence*(data: JsonNode): Presence =
    if data{"activities"}.getElems != @[]:
        for act in data["activities"].getElems:
            let keycheck = "application_id" in act
            if keycheck and act["application_id"].kind == JInt:
                act["application_id"] = %($act["application_id"].getInt)
    result = ($data).fromJson(Presence)

proc parseHook(s: string, i: var int, g: var Guild) =
    var data: JsonNode
    parseHook(s, i, data)

    g = new Guild
    g.id = data["id"].str # just in case

    for v in data{"members"}.getElems:
        v["guild_id"] = %*g.id
        let member = v.`$`.fromJson Member
        g.members[member.user.id] = member

    for k, val in data.pairs:
        case val.kind:
        of JBool, JInt, JFloat, JString, JObject:
            g[k] = val
        of JArray:
            case k:
            of "voice_states":
                for v in val.getElems:
                    let state = v.`$`.fromJson(VoiceState)

                    g.members[state.user_id].voice_state = some state
                    g.voice_states[state.user_id] = state
            of "threads":
                for v in val.getElems:
                    v["guild_id"] = %g.id
                    g.threads[v["id"].str] = v.`$`.fromJson(GuildChannel)
            of "channels":
                for v in val.getElems:
                    v["guild_id"] = %g.id
                    g.channels[v["id"].str] = v.`$`.fromJson(GuildChannel)
            of "presences":
                for v in val.getElems:
                    v["guild_id"] = %g.id
                    let p = newPresence(v)

                    if p.user.id in g.members:
                        g.members[p.user.id].presence = p
                    g.presences[p.user.id] = p
            else:
                if k != "members":
                    g[k] = val
        else:
            discard

proc newMember*(data: JsonNode): Member =
    result = ($data).fromJson(Member)

proc newOverwrite*(data: JsonNode): Overwrite =
    result = ($data).fromJson(Overwrite)

proc newUser*(data: JsonNode): User =
    result = ($data).fromJson(User)

proc newMessage*(data: JsonNode): Message =
    result = data.`$`.fromJson(Message)

proc newGuildChannel*(data: JsonNode): GuildChannel =
    result = ($data).fromJson(GuildChannel)

proc newReaction*(data: JsonNode): Reaction =
    result = ($data).fromJson(Reaction)

proc newApplication*(data: JsonNode): Application =
    result = ($data).fromJson(Application)

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
        of acotMentionable:
            result.mention_id = value.getStr
        of acotAttachment:
            result.aval       = value.getStr
        of acotNumber:
            result.fval       = value.getFloat
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

proc parseHook(s: string, i: var int, v: var MessageComponentType) =
    var data: int
    parseHook(s, i, data)
    try:
        v = MessageComponentType(data)
    except:
        v = mctNone

proc parseHook(s: string, i: var int, v: var MessageComponent) =
    var data: JsonNode
    parseHook(s, i, data)

    v = MessageComponent(
        kind: ($data["type"].getInt).fromJson(MessageComponentType)
    )
    data.delete("type") # we dont want any potential rewrites if type is at end instead of start

    for k, val in data.fields:
        var field = k
        case v.kind:
        of mctTextInput:
            if k == "style": field = "input_style"
        of mctSection:
            if k == "components": field = "sect_components"
        else: discard

        v[field] = val

proc parseHook(s: string, i: var int, v: var ApplicationCommandType) =
    var number: int
    parseHook(s, i, number)
    try:
        v = ApplicationCommandType number
    except:
        v = atSlash # just by default incase

proc parseHook(s: string, n: var int, a: var ApplicationCommandInteractionData) =
    var data: JsonNode
    parseHook(s, n, data)

    if "component_type" in data:
        a = ApplicationCommandInteractionData(
            interaction_type: idtMessageComponent,
            component_type: ($data["component_type"]).fromJson(
                MessageComponentType),
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

        a.resolved=ResolvedData()
        if "resolved" in data:
            for key, values in data["resolved"].getFields.pairs:
                case key:
                of "users":
                    for k, v in values.pairs:
                        a.resolved.users[k] = v.newUser
                of "attachments":
                    for k, v in values.pairs:
                        a.resolved.attachments[k] = v.newAttachment
                of "members":
                    for k, v in values.pairs:
                        a.resolved.members[k] = v.newMember
                of "roles":
                    for k, v in values.pairs:
                        a.resolved.roles[k] = v.newRole
                of "channels":
                    for k, v in values.pairs:
                        a.resolved.channels[k] = ($v).fromJson(
                            ResolvedChannel
                        )
                of "messages":
                    for k, v in values.pairs:
                        a.resolved.messages[k] = v.newMessage
                else: discard

    for k, val in data.pairs:
        case val.kind:
        of JBool, JInt, JFloat, JString, JObject, JArray:
            if k != "resolved": a[k] = val
        else:
            discard
    if a.interaction_type == idtModalSubmit: a.component_type = mctTextInput

proc newEntitlement*(data: JsonNode): Entitlement = 
    result = data.`$`.fromJson(Entitlement)

proc newApplicationCommandInteractionData*(
    data: JsonNode
): ApplicationCommandInteractionData =
    result = data.`$`.fromJson(ApplicationCommandInteractionData)

proc newInteraction*(data: JsonNode): Interaction =
    let memcheck = "member" in data and data["member"].kind != JNull
    if "guild_id" in data and memcheck:
        data["member"]["guild_id"] = data["guild_id"]

    result = data.`$`.fromJson(Interaction)

proc newApplicationCommandOption*(data: JsonNode): ApplicationCommandOption =
    result = data.`$`.fromJson(ApplicationCommandOption)

proc `%%*`*(a: ApplicationCommandOption): JsonNode =
    result = %*{"type": int a.kind, "name": a.name,
                "description": a.description,
                "required": %(a.required.get false),
                "autocomplete": %a.autocomplete
    }
    if a.name_localizations.isSome:
        result["name_localizations"] = %*a.name_localizations
    if a.description_localizations.isSome:
        result["description_localizations"] = %*a.description_localizations

    if a.choices.len > 0:
        result["choices"] = %a.choices.map(
            proc (x: ApplicationCommandOptionChoice): JsonNode =
                let json = %*{"name": %x.name}
                if x.name_localizations.isSome:
                    json["name_localizations"] = %*x.name_localizations
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
    softassert a.name.len in 1..32
    # This ternary is needed so that the enums can stay similar to
    # the discord api

    # <TODO> PLEASE CLEAN UP THE CODE -> im postponing this cause ibr code cleanup is for later
    # if anyone cares enough to read this :<

    let commandKind = if a.kind == atNothing: atSlash else: a.kind
    result = %*{
        "name": a.name,
        "type": commandKind.ord
    }
    if a.contexts.isSome:
        result["contexts"] = %a.contexts.get.mapIt(ord it)
    if a.integration_types.isSome:
        result["integration_types"] = %a.integration_types.get.mapIt(ord it)
    if a.nsfw.isSome: result["nsfw"] = %*a.nsfw.get
    if a.name_localizations.isSome:
        result["name_localizations"] = %*a.name_localizations
    if commandKind == atSlash:
        softassert a.description.len in 1..100
        result["description"] = %a.description
        if a.description_localizations.isSome:
            result["description_localizations"] = %*a.description_localizations
        if a.options.len > 0: result["options"] = %(a.options.map(
            proc (x: ApplicationCommandOption): JsonNode =
                %%*x
        ))
    result["default_permission"] = %a.default_permission
    if a.default_member_permissions.isSome:
        result["default_member_permissions"] = %(
            $cast[int](a.default_member_permissions.get)
        )
    if a.dm_permission.isSome:
        result["dm_permission"] = %a.dm_permission.get

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

proc `%`*(t: TextDisplay): JsonNode =
    result = %*{
        "type": ord t.kind,
        "content": t.content
    }
    result.loadOpts(t, id)

proc `%`(option: SelectMenuOption): JsonNode =
    result = %* {
        "label": option.label,
        "value": option.value,
        "description": option.description,
        "default": option.default.get false
    }
    if option.emoji.isSome:
        result["emoji"] = option.emoji.get.toPartial

proc `%`*(p: ApplicationCommandPermission): JsonNode =
    %*{"id": %p.id,
       "type": %ord p.kind,
       "permission": %p.permission}

proc `%`*(d: tuple[id, kind: string]): JsonNode = %*{"id": d.id, "type": d.kind}

proc `%`*(t: tuple[
        channel_id: string, duration_seconds: int,
        custom_message: Option[string]
    ]): JsonNode =
    result = %*{
        "channel_id":t.channel_id,
        "duration_seconds":t.duration_seconds,
    }
    if t.custom_message.isSome: result["custom_message"] = %t.custom_message.get

proc `%`*(tm: tuple[keyword_filter: seq[string], presets: seq[int]]): JsonNode =
    %*{"keyword_filter":tm.keyword_filter,"presets":tm.presets}

proc `%`*(o: tuple[sku_id, asset: string]): JsonNode =
    %*{"sku_id": o.sku_id, "asset": o.asset}

proc `%`*(o: tuple[nameplate: Nameplate]): JsonNode =
    %*{"nameplate": %o.nameplate}# this is to shut the compiler up

proc `%`*(o: Overwrite): JsonNode =
    %*{"id": o.id,
        "type": %o.kind,
        "allow": %cast[int](o.allow),
        "deny": %cast[int](o.deny)}

proc `%`*[T: enum](flags: set[T]): JsonNode =
    when flags is not set[PermissionFlags]:
        %cast[int](flags)
    else:
        %($cast[int](flags))

proc `%`*(r: (MessageReferenceType | InteractionContextType |
        ApplicationIntegrationType)): JsonNode =
    %(ord r)

proc `+`(a, b: JsonNode): JsonNode =
    result = %*{}
    for k, v in a.pairs:
        result[k] = v
    for k, v in b.pairs:
        result[k] = v

proc `&=`(a: var JsonNode, b: JsonNode) =
    a = a+b

proc `%%*`*(comp: MessageComponent): JsonNode =
    # Fyi, it's named that because originally it was meant to avoid conflicts with json but now since there is no conflicts,
    # I thought I'd just keep it as it is and make a `%` that would redirect the proc.
    result = %*{"type": comp.kind.ord}

    result.loadOpts(comp, spoiler, placeholder,
        disabled, id, label, description,
        custom_id, min_values, max_values, required)

    case comp.kind:
    of mctNone, mctFileUpload: discard
    of mctActionRow, mctContainer:
        result["components"] = %comp.components.mapIt(%%*it)
        result.loadOpts(comp, accent_color)
    of mctButton:
        result &= %*{"style": comp.style.ord}
        
        result.loadOpts(comp, url, sku_id)
        if comp.emoji.isSome:
            result["emoji"]     = comp.emoji.get.toPartial
    of mctSelectMenu, mctUserSelect, mctRoleSelect, mctMentionableSelect, mctChannelSelect:
        result &= %*{"options":     comp.options,
                    "placeholder": comp.placeholder,
                    "channel_types": comp.channel_types.mapIt(it.ord),
                    "default_values": comp.default_values.mapIt(%it)}
    of mctTextInput:
        result &= %*{"placeholder": comp.placeholder,
                     "style":       ord comp.input_style.get}

        result.loadOpts(comp, value, required, min_length, max_length)
    of mctThumbnail:
        result &= %*{"media": %comp.media}
    of mctSection:
        result &= %*{"components": comp.sect_components.mapIt(%it),
                     "accessory": %%*comp.accessory}
    of mctMediaGallery: result["items"] = %comp.items.mapIt(%it)
    of mctFile:
        result &= %*{"file": %comp.file,
                     "name": comp.name,
                     "size": comp.size}
    of mctSeparator: result.loadOpts(comp, divider, spacing)
    of mctTextDisplay: result["content"] = %comp.content
    of mctLabel:
        result &= %*{"component": %%*comp.component}

proc `%`*(m: MessageComponent): JsonNode = %%*m

proc `%`*(m: InteractionCallbackDataMessage): JsonNode =
    result = %*{
        "content": m.content,
        "embeds": %m.embeds.mapIt(%it),
        "allowed_mentions": %m.allowed_mentions,
        "flags": %m.flags,
        "attachments": %m.attachments,
        "components": %m.components.mapIt(%%*it)
    }
    result.loadOpts(m, tts)