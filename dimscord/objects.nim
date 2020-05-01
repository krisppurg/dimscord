import options, json, tables, constants
type
    Embed* = ref object
        title*: Option[string]
        `type`*: Option[string]
        description*: Option[string]
        url*: Option[string]
        timestamp*: Option[string]
        color*: Option[int]
        footer*: Option[EmbedFooter]
        image*: Option[EmbedImage]
        thumbnail*: Option[EmbedThumbnail]
        video*: Option[EmbedVideo]
        provider*: Option[EmbedProvider]
        author*: Option[EmbedAuthor]
        fields*: Option[seq[EmbedField]]
    EmbedThumbnail* = object
        url*: Option[string]
        proxy_url*: Option[string]
        height*: Option[int]
        width*: Option[int]
    EmbedVideo* = object
        url*: Option[string]
        height*: Option[int]
        width*: Option[int]
    EmbedImage* = object
        url*: Option[string]
        proxy_url*: Option[string]
        height*: Option[int]
        width*: Option[int]
    EmbedProvider* = object
        name*: Option[string]
        url*: Option[string]
    EmbedAuthor* = object
        name*: Option[string]
        url*: Option[string]
        icon_url*: Option[string]
        proxy_icon_url*: Option[string]
    EmbedFooter* = object
        text*: string
        icon_url*: Option[string]
        proxy_icon_url*: Option[string]
    EmbedField* = object
        name*: string
        value*: string
        inline*: Option[bool]
    MentionChannel* = ref object
        id*: string
        guild_id*: string
        kind*: int
        name*: string
    Message* = object
        id*: string
        channel_id*: string
        guild_id*: string ## Message.guild_id by default will be ""
        author*: User
        member*: Member ## Member will be nilable
        content*: string
        timestamp*: string
        edited_timestamp*: Option[string]
        tts*: bool
        mention_everyone*: bool
        mention_users*: seq[User]
        mention_roles*: seq[string]
        mention_channels*: seq[MentionChannel]
        attachments*: seq[Attachment]
        embeds*: seq[Embed]
        reactions*: Table[string, Reaction]
        nonce*: string ## It will always be a string, if it can be parsed as an int you can use parseInt from strutils.
        pinned*: bool
        webhook_id*: string
        kind*: int
        activity*: tuple[kind: int, party_id: string]
        application*: Application
        message_reference*: tuple[channel_id: string, message_id: string, guild_id: string]
        flags*: int
    User* = object
        id*: string
        username*: string
        discriminator*: string
        avatar*: Option[string]
        bot*: bool
        system*: bool
    Member* = object
        user*: User
        nick*: string
        roles*: seq[string]
        joined_at*: string
        presence*: Presence
        premium_since*: string
        voice_state*: Option[VoiceState]
        deaf*: bool
        mute*: bool
    Attachment* = object
        id*: string
        filename*: string
        size*: int
        url*: string
        proxy_url*: string
        height*: Option[int]
        width*: Option[int]
    Reaction* = object
        count*: int
        emoji*: Emoji
        reacted*: bool
    Emoji* = object
        id*: string
        name*: string
        user*: User
        roles*: seq[string]
        require_colons*: bool
        managed*: bool
        animated*: bool
    Application* = object
        id*: string
        cover_image*: string
        description*: string
        icon*: string
        name*: string
    RestApi* = ref object
        token*: string
        endpoints*: Table[string, Ratelimit]
        rest_ver*: int
    Ratelimit* = ref object
        reset*: int
        ratelimited*: bool
    UnavailableGuild* = object
        id*: string
        unavailable*: bool
    Ready* = object
        v*: int
        user*: User
        guilds*: seq[UnavailableGuild]
        session_id*: string
        shard*: Option[seq[int]]
    DMChannel* = ref object
        id*: string
        last_message_id*: string
        kind*: int
        recipients*: seq[User]
        messages*: Table[string, Message]
    GuildChannel* = ref object
        id*: string
        name*: string
        kind*: int
        parent_id*: Option[string]
        position*: int
        permission_overwrites*: Table[string, Overwrite]
        messages*: Table[string, Message]
        guild_id*: Option[string]
        nsfw*: bool
        topic*: string
        last_message_id*: string
        rate_limit_per_user*: int
        bitrate*: int
        user_limit*: int
    GameAssets* = object
        large_text*: string
        large_image*: string
        small_text*: string
        small_image*: string
    GameActivity* = object # A user game activity
        name*: string
        kind*: int
        url*: Option[string]
        created_at*: BiggestInt
        timestamps*: Option[tuple[start: BiggestInt, final: BiggestInt]]
        application_id*: Option[string]
        details*: Option[string]
        state*: Option[string]
        emoji*: Option[Emoji]
        party*: Option[tuple[id: string, size: string]]
        assets*: Option[GameAssets]
        secrets*: Option[tuple[join: string, spectate: string, match: string]]
        instance*: bool # Useful field if its instanced session
        flags*: int
    Presence* = object
        user*: User
        roles*: seq[string]
        game*: Option[GameActivity]
        guild_id*: string
        status*: string
        activities*: seq[GameActivity]
        client_status*: tuple[web: string, desktop: string, mobile: string]
        premium_since*: Option[string]
        nick*: Option[string]
    Guild* = ref object ## A guild object. All option fields are cached only fields or fields that cannot be assumed (e.g. permissions) or nilable
        id*: string
        name*: string
        icon*: Option[string]
        splash*: Option[string]
        discovery_splash*: Option[string]
        owner*: bool
        owner_id*: string
        permissions*: Option[int]
        region*: string
        afk_channel_id*: Option[string]
        afk_timeout*: Option[int] # thx yasmin from #api
        embed_enabled*: bool
        embed_channel_id*: string
        verification_level*: int
        default_message_notification*: int
        explicit_content_filter*: int
        roles*: Table[string, Role]
        emojis*: Table[string, Emoji]
        features*: seq[string]
        mfa_level*: int
        application_id*: Option[string]
        widget_enabled*: bool
        widget_channel_id*: Option[string]
        system_channel_id*: Option[string]
        joined_at*: Option[string]
        large*: Option[bool]
        unavailable*: Option[bool]
        member_count*: Option[int]
        voice_states*: Table[string, VoiceState]
        members*: Table[string, Member]
        channels*: Table[string, GuildChannel]
        presences*: Table[string, Presence]
        max_presences*: Option[int]
        max_members*: Option[int]
        vanity_url_code*: Option[string]
        description*: Option[string]
        banner*: Option[string]
        premium_tier*: int
        premium_subscription_count*: Option[int]
        preferred_locale*: string
    VoiceState* = object
        guild_id*: Option[string]
        channel_id*: Option[string]
        user_id*: string
        session_id*: string
        deaf*: bool
        mute*: bool
        self_deaf*: bool
        self_mute*: bool
        self_stream*: bool # owo whats this
        suppress*: bool
    Role* = object
        id*: string
        name*: string
        color*: int
        hoist*: bool
        position*: int
        permissions*: int
        managed*: bool
        mentionable*: bool
    GameStatus* = object
        name*: string
        kind*: int
        url*: Option[string]
    Overwrite* = object
        id*: string
        kind*: string
        allow*: int
        deny*: int
        permObj*: PermObj
    PermObj* = object
        allowed*: set[PermEnum]
        denied*: set[PermEnum]
        perms*: int
    PartialGuild* = object
        id*: string
        name*: string
        icon*: Option[string]
        splash*: Option[string]
    PartialChannel* = object
        id*: string
        name*: string
        kind*: int
    Invite* = object
        code*: string
        guild*: Option[PartialGuild]
        channel*: PartialChannel
        inviter*: Option[User]
        target_user*: Option[User]
        target_user_type*: Option[int]
        approximate_presence_count*: Option[int]
        approximate_member_count*: Option[int]
    InviteMetadata* = object
        code*: string
        guild_id*: Option[string]
        uses*: int
        max_uses*: int
        max_age*: int
        temporary*: bool
        created_at*: string
    TypingStart* = object
        channel_id*: string
        user_id*: string
        timestamp*: int
    GuildMembersChunk* = object
        members*: seq[Member]
        not_found*: seq[string]
        presences*: seq[Presence]
    GuildBan* = object
        user*: User
        reason*: Option[string]
    Webhook* = object
        id*: string
        kind*: int
        guild_id*: Option[string]
        channel_id*: string
        user*: Option[User]
        name*: Option[string]
        avatar*: Option[string]
        token*: Option[string]
    Integration* = object
        id*: string
        name*: string
        kind*: string
        enabled*: bool
        syncing*: bool
        role_id*: string
        enable_emoticons*: Option[bool]
        expire_behavior*: int
        expire_grace_period*: int
        user*: User
        account*: tuple[id: string, name: string]
        synced_at*: string

proc `$`*(e: Emoji): string =
    result = if e.id != "": e.name & ":" & e.id else: e.name

proc `$`*(r: Reaction): string =
    result = $r

proc `+`*(p: PermObj): int =
    ## Sums up the total permissions.
    result = 0
    if p.allowed.len > 0:
        for it in p.allowed:
            result = result or it.int
    if p.denied.len > 0:
        for it in p.denied:
            result = result and (it.int - it.int - it.int)

proc `+`*(p: set[PermEnum]): int =
    ## Sums up the total permissions for a specific permission.
    result = 0
    for it in p:
        result = result or cast[int]({it})

proc permCheck*(perms: int, p: int): bool =
    ## Checks if the set of permissions has the specific permission.
    result = (perms and p) == p

proc permCheck*(perms: int, p: PermObj): bool =
    ## Just like permCheck, but with a PermObj.
    var allowed: Option[bool] = none(bool)
    var denied: Option[bool] = none(bool) 

    if p.allowed.len > 0:
        allowed = some(permCheck(perms, +(p.allowed)))
    if p.denied.len > 0:
        denied = some(permCheck(perms, +(p.denied)))

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

proc newInviteMetadata*(data: JsonNode): InviteMetadata =
    result = InviteMetadata(
        code: data["code"].str,
        uses: data["uses"].getInt(),
        max_uses: data["max_uses"].getInt(),
        max_age: data["max_age"].getInt(),
        temporary: data["temporary"].bval,
        created_at: data["created_at"].str
    )

proc `%`*(o: Overwrite): JsonNode =
    var json = %* {}
    json["id"] = % o.id
    json["type"] = % o.kind
    json["allow"] = % o.allow
    json["deny"] = % o.deny

    return json

proc newOverwrite*(data: JsonNode): Overwrite =
    result = Overwrite(
        id: data["id"].str,
        kind: data["type"].str,
        allow: data["allow"].getInt(),
        deny: data["deny"].getInt()
    )

    if result.allow != 0:
        result.permObj.perms = result.permObj.perms or result.allow
    if result.deny != 0:
        result.permObj.perms = result.permObj.perms and (result.deny - result.deny - result.deny)

proc newRole*(data: JsonNode): Role =
    result = Role(
        id: data["id"].str,
        name: data["name"].str,
        color: data["color"].getInt(),
        hoist: data["hoist"].bval,
        position: data["position"].getInt(),
        permissions: data["permissions"].getInt(),
        managed: data["managed"].bval,
        mentionable: data["mentionable"].bval
    )

proc newGuildChannel*(data: JsonNode): GuildChannel =
    result = GuildChannel(
        id: data["id"].str,
        name: data["name"].str,
        kind: data["type"].getInt(),
        position: data["position"].getInt())

    if data.hasKey("guild_id"):
        result.guild_id = some(data["guild_id"].str)

    if data["permission_overwrites"].elems.len > 0:
        for ow in data["permission_overwrites"].elems:
            result.permission_overwrites.add(ow["id"].str, newOverwrite(ow))

    case result.kind:
        of ctGuildText:
            result.rate_limit_per_user = data["rate_limit_per_user"]. getInt(0)

            if data["last_message_id"].kind != JNull:
                result.last_message_id = data["last_message_id"].str
                result.messages = initTable[string, Message]()
            if data.hasKey("nsfw"):
                result.nsfw = data["nsfw"].bval
            if data.hasKey("topic") and data["topic"].kind != JNull:
                result.topic = data["topic"].str
        of ctGuildNews:
            result.nsfw = data["nsfw"].bval
            result.topic = data["topic"].str
            result.last_message_id = data["last_message_id"].str
        of ctGuildVoice:
            result.bitrate = data["bitrate"]. getInt(0)
            result.user_limit = data["user_limit"]. getInt(0)
        else:
            discard

    if data.hasKey("parent_id") and data["parent_id"].kind != JNull:
        result.parent_id = some(data["parent_id"].str)
    if data.hasKey("guild_id") and data["guild_id"].kind != JNull:
       result.guild_id = some(data["guild_id"].str)

proc newRestApi*(token: string, rest_ver: int): RestApi =
    result = RestApi(token: token)
    result.rest_ver = rest_ver
    result.endpoints = initTable[string, Ratelimit]()

proc newUser*(data: JsonNode): User =
    result = User(
        id: data["id"].str,
        username: if data.hasKey("username"): data["username"].str else: "",
        discriminator: if data.hasKey("discriminator"): data["discriminator"].str else: "",
        bot: data{"bot"}.getBool,
        system: data{"system"}.getBool
    )
    if data.hasKey("avatar") and data["avatar"].kind != JNull:
        result.avatar = some(data["avatar"].str)

proc newWebhook*(data: JsonNode): Webhook =
    result = Webhook(
        id: data["id"].str,
        kind: data["type"].getInt(),
        channel_id: data["channel_id"].str)
    
    if data.hasKey("guild_id"):
        result.guild_id = some(data["guild_id"].str)
    if data.hasKey("user"):
        result.user = some(newUser(data["user"]))
    if data.hasKey("token"):
        result.token = some(data["token"].str)
    if data["name"].kind != JNull:
        result.name = some(data["name"].str)
    if data["avatar"].kind != JNull:
        result.avatar = some(data["avatar"].str)

proc newGuildBan*(data: JsonNode): GuildBan =
    result = GuildBan(user: newUser(data["user"]))
    if data["reason"].kind != JNull:
        result.reason = some(data["reason"].str)

proc newDMChannel*(data: JsonNode): DMChannel =
    result = DMChannel(
        id: data["id"].str,
        kind: data["type"].getInt(),
        messages: initTable[string, Message]()
    )
    result.recipients = @[]
    for r in data["recipients"].elems:
        result.recipients.add(newUser(r))

proc newInvite*(data: JsonNode): Invite =
    result = Invite(code: data["code"].str, channel: PartialChannel(
        id: data["channel"]["id"].str,
        kind: data["channel"]["type"].getInt(),
        name: data["channel"]["name"].str))

    if data.hasKey("guild"):
        result.guild = some(data["guild"].to(PartialGuild))
    if data.hasKey("inviter"):
        result.inviter = some(newUser(data["inviter"]))

    if data.hasKey("target_user"):
        result.target_user = some(newUser(data["inviter"]))
    if data.hasKey("target_user_type"):
        result.target_user_type = some(data["target_user_type"].getInt())
    if data.hasKey("approximate_presence_count"):
        result.approximate_presence_count = some(data["approximate_presence_count"].getInt())
    if data.hasKey("approximate_member_count"):
        result.approximate_member_count = some(data["approximate_member_count"].getInt())

proc newReady*(data: JsonNode): Ready =
    result = Ready(
        v: data["v"].getInt(),
        user: newUser(data["user"]),
        guilds: @[],
        session_id: data["session_id"].str
    )

    if data["guilds"].elems.len > 0:
        for guild in data["guilds"].elems:
            result.guilds.add(UnavailableGuild(id: guild["id"].str, unavailable: guild["unavailable"].bval))

    if data.hasKey("shard"):
        result.shard = some(newSeq[int]())

        for s in data["shard"].elems:
            get(result.shard).add(s.getInt())

proc newAttachment(data: JsonNode): Attachment =
    result = Attachment(
        id: data["id"].str,
        filename: data["filename"].str,
        size: data["size"].getInt(),
        url: data["url"].str,
        proxy_url: data["proxy_url"].str,
    )
    if data.hasKey("height"):
        result.height = some(data["height"].getInt())
    if data.hasKey("width"):
        result.width = some(data["width"].getInt())

proc newVoiceState*(data: JsonNode): VoiceState =
    result = VoiceState(
        user_id: data["user_id"].str,
        session_id: data["session_id"].str,
        deaf: data["deaf"].bval,
        mute: data["mute"].bval,
        self_deaf: data["self_deaf"].bval,
        self_mute: data["self_mute"].bval,
        suppress: data["suppress"].bval
    )
    if data.hasKey("self_stream"):
        result.self_stream = data["self_stream"].bval
    if data.hasKey("guild_id"):
        result.guild_id = some(data["guild_id"].str)
    if data.hasKey("channel_id") and data["channel_id"].kind != JNull:
        result.channel_id = some(data["channel_id"].str)

proc newEmoji*(data: JsonNode): Emoji =
    result = Emoji(
        name: data["name"].str
    )

    if data.hasKey("roles"):
        result.roles = @[]
        for r in data["roles"].elems:
            result.roles.add(r.str)

    if data.haskey("id") and data["id"].kind != JNull:
        result.id = data["id"].str

    if data.hasKey("user"):
        result.user = newUser(data["user"])
    if data.hasKey("require_colons"):
        result.require_colons = data["require_colons"].bval
    if data.hasKey("managed"):
        result.managed = data["managed"].bval
    if data.hasKey("animated"):
        result.animated = data["animated"].bval

proc newGameActivity*(data: JsonNode): GameActivity =
    result = GameActivity(
        name: data["name"].str,
        kind: data["type"].getInt(),
        created_at: data["created_at"].num
    )
    if data.hasKey("url") and data["url"].kind != JNull:
        result.url = some(data["url"].str)
    
    if data.hasKey("timestamps"):
        result.timestamps = some((start: toBiggestInt(0), final: toBiggestInt(0)))
        if data["timestamps"].hasKey("start"):
            get(result.timestamps).start = data["timestamps"]["start"].num
        if data["timestamps"].hasKey("end"):
            get(result.timestamps).final = data["timestamps"]["end"].num
    
    if data.hasKey("application_id"):
        result.application_id = some(data["application_id"].str)
    if data.hasKey("details") and data["details"].kind != JNull:
        result.details = some(data["details"].str)
    if data.hasKey("state") and data["state"].kind != JNull:
        result.state = some(data["state"].str)
    if data.hasKey("emoji"):
        result.emoji = some(newEmoji(data["emoji"]))
    if data.hasKey("party"):
        result.party = some((id: "", size: ""))
        if data["party"].hasKey("size"):
            result.party = some((
                id: data["party"]{"id"}.getStr(""),
                size: data["party"]{"size"}.getStr("")
            ))

    if data.hasKey("assets"):
        result.assets = some(GameAssets())
        if data["assets"].hasKey("small_text"):
            get(result.assets).small_text = data["assets"]["small_text"].str
        if data["assets"].hasKey("small_image"):
            get(result.assets).small_image = data["assets"]["small_image"].str
        if data["assets"].hasKey("large_text"):
            get(result.assets).large_text = data["assets"]["large_text"].str
        if data["assets"].hasKey("large_image"):
            get(result.assets).large_image = data["assets"]["large_image"].str

    if data.hasKey("secrets"):
        result.secrets = some((join: "", spectate: "", match: ""))
        if data["secrets"].hasKey("join"):
            get(result.secrets).join = data["secrets"].str
        if data["secrets"].hasKey("spectate"):
            get(result.secrets).spectate = data["spectate"].str
        if data["secrets"].hasKey("match"):
            get(result.secrets).match = data["match"].str

    if data.hasKey("instance"):
        result.instance = data["instance"].bval
    if data.hasKey("flags"):
        result.flags = data["flags"].getInt()

proc newPresence*(data: JsonNode): Presence =
    result = Presence(
        user: newUser(data["user"]),
        roles: @[],
        status: data["status"].str,
        activities: @[],
        client_status: (web: "offline", desktop: "offline", mobile: "offline"))

    if data.hasKey("guild_id"):
        result.guild_id = data["guild_id"].str
    if data.hasKey("roles") and data["roles"].elems.len > 0:
        for role in data["roles"]:
            result.roles.add(role.str)
    if data["activities"].elems.len > 0:
        for activity in data["activities"].elems:
            result.activities.add(newGameActivity(activity))

    if data["game"].kind != JNull:
        result.game = some(newGameActivity(data["game"]))

    if data["client_status"].hasKey("desktop"):
        result.client_status.desktop = data["client_status"]["desktop"].str
    if data["client_status"].hasKey("web"):
        result.client_status.web = data["client_status"]["web"].str
    if data["client_status"].hasKey("mobile"):
        result.client_status.mobile = data["client_status"]["mobile"].str

    if data.hasKey("nick") and data["nick"].kind != JNull:
        result.nick = some(data["nick"].str)
    if data.hasKey("premium_since") and data["premium_since"].kind != JNull:
        result.premium_since = some(data["premium_since"].str)

proc newMember*(data: JsonNode): Member =
    result = Member(
        joined_at: data["joined_at"].str,
        deaf: data["deaf"].bval,
        mute: data["mute"].bval
    )

    if data.hasKey("user") and data["user"].kind != JNull:
        result.user = newUser(data["user"])

    if data.hasKey("roles"):
        result.roles = @[]
        for r in data["roles"].elems:
            result.roles.add(r.str)

    if data.hasKey("nick") and data["nick"].kind != JNull:
        result.nick = data["nick"].str
    if data.hasKey("premium_since") and data["premium_since"].kind != JNull:
        result.premium_since = data["premium_since"].str

    result.presence = Presence(status: "offline", client_status: ("offline", "offline", "offline"))

proc newReaction*(data: JsonNode): Reaction =
    result = Reaction(count: data["count"].getInt(), emoji: newEmoji(data["emoji"]), reacted: data["me"].bval)

proc update*(m: Message, data: JsonNode): Message =
    result = m
    if data.hasKey("type"):
        result.kind = data["type"].getInt()
    if data.hasKey("author"):
        result.author = newUser(data["author"])
    if data.hasKey("flags"):
        result.flags = data["flags"].getInt()
    if data.hasKey("content"):
        result.content = data["content"].str
    if data.hasKey("mention_everyone"):
        result.mention_everyone = data["mention_everyone"].bval
    if data.hasKey("edited_timestamp") and data["edited_timestamp"].kind != JNull:
        result.edited_timestamp = some(data["edited_timestamp"].str)

    if data.hasKey("pinned"):
        result.pinned = data["pinned"].bval
    if data.hasKey("mentions"):
        result.mention_users = @[]
    
        for usr in data["mentions"].elems:
            result.mention_users.add(newUser(usr))

    if data.hasKey("tts"):
        result.tts = data["tts"].bval

    if data.hasKey("attachments"):
        result.attachments = @[]

        for attach in data["attachments"].elems:
            result.attachments.add(newAttachment(attach))

    if data.hasKey("embeds") and data["embeds"].len > 0:
        result.embeds = @[]

        for embed in data["embeds"].elems:
            result.embeds.add(embed.to(Embed))

    if data.hasKey("activity"):
        var activity = data["activity"]

        result.activity = (kind: activity["type"].getInt(), party_id: "")
        if activity.hasKey("party_id"):
            result.activity.party_id = activity["party_id"].str

    if data.hasKey("application"):
        var app = data["application"]
    
        result.application = Application(
            id: app["id"].str,
            description: app["description"].str,
            icon: if app["icon"].kind != JNull: app["icon"].str else: "",
            name: app["name"].str
        )

proc newMessage*(data: JsonNode): Message = # this thing was the 2nd object structure I've done on this library and that took me some effort
    result = Message(
        id: data["id"].str,
        channel_id: data["channel_id"].str,
        content: data["content"].str,
        timestamp: data["timestamp"].str,
        tts: data["tts"].bval,
        mention_everyone: data["mention_everyone"].bval,
        edited_timestamp: if data{"edited_timestamp"}.getStr != "": some(data["edited_timestamp"].str) else: none(string),
        pinned: data["pinned"].bval,
        kind: data["type"].getInt(),
        flags: data["flags"].getInt()
    )

    if data.hasKey("mention_roles"):
        result.mention_roles = @[]

        for r in data["mention_roles"].elems:
            result.mention_roles.add(r.str)

    if data.hasKey("guild_id") and data["guild_id"].kind != JNull:
        result.guild_id = data["guild_id"].str
    if data.hasKey("author"):
        result.author = newUser(data["author"])
    if data.hasKey("member") and data["member"].kind != JNull:
        result.member = newMember(data["member"])

    if data.hasKey("mentions"):
        result.mention_users = @[]
    
        for usr in data["mentions"].elems:
            result.mention_users.add(newUser(usr))
    if data.hasKey("mention_channels"):
        result.mention_channels = @[]
    
        for chan in data["mention_channels"].elems:
            result.mention_channels.add(MentionChannel(
                id: chan["id"].str,
                guild_id: chan["guild_id"].str,
                kind: chan["type"].getInt(),
                name: chan["name"].str
            ))
    if data.hasKey("attachments"):
        result.attachments = @[]

        for attach in data["attachments"].elems:
            result.attachments.add(newAttachment(attach))
    if data.hasKey("embeds"):
        result.embeds = @[]

        for embed in data["embeds"].elems:
            result.embeds.add(embed.to(Embed))
    if data.hasKey("reactions"):
        result.reactions = initTable[string, Reaction]()

        for reaction in data["reactions"].elems:
            var rtn = newReaction(reaction)
            result.reactions.add($rtn.emoji, rtn)

    if data.hasKey("nonce"):
        result.nonce = data["nonce"].getStr("")
    if data.hasKey("webhook_id"):
        result.webhook_id = data["webhook_id"].str

    if data.hasKey("activity"):
        var activity = data["activity"]

        result.activity = (kind: activity["type"].getInt(), party_id: "")
        if activity.hasKey("party_id"):
            result.activity.party_id = activity["party_id"].str

    if data.hasKey("application"):
        var app = data["application"]

        result.application = Application(
            id: app["id"].str,
            description: app["description"].str,
            icon: if app["icon"].kind != JNull: app["icon"].str else: "",
            name: app["name"].str
        )

        if app.hasKey("cover_image"):
            result.application.cover_image = app["cover_image"].str

    if data.hasKey("message_reference"):
        var reference = data["message_reference"]
        result.message_reference = (channel_id: reference["channel_id"].str, message_id: "", guild_id: "")

        if reference.hasKey("message_id"):
            result.message_reference.message_id = reference["message_id"].str
        if reference.hasKey("guild_id") and reference["guild_id"].kind != JNull:
            result.message_reference.guild_id = reference["guild_id"].str

proc newGuild*(data: JsonNode): Guild =
    result = Guild(
        id: data["id"].str,
        name: data["name"].str,
        owner: data{"owner"}.getBool,
        owner_id: data["owner_id"].str,
        region: data["region"].str,
        embed_enabled: data{"embed_enabled"}.getBool,
        verification_level: data["verification_level"].getInt(),
        explicit_content_filter: data["explicit_content_filter"].getInt(),
        default_message_notification: data["default_message_notifications"].getInt(),
        roles: initTable[string, Role](),
        emojis: initTable[string, Emoji](),
        voice_states: initTable[string, VoiceState](),
        members: initTable[string, Member](),
        channels: initTable[string, GuildChannel](),
        presences: initTable[string, Presence](),
        mfa_level: data["mfa_level"].getInt(),
        premium_tier: data["premium_tier"].getInt(),
        preferred_locale: data["preferred_locale"].str)

    if data.hasKey("afk_timeout"):
        result.afk_timeout = some(data["afk_timeout"].getInt())
    if data.hasKey("permissions"):
        result.permissions = some(data["permissions"].getInt()) 

    if data.hasKey("widget_channel_id"):
        result.widget_channel_id = some(data["widget_channel_id"].str)
    if data.hasKey("joined_at"):
        result.joined_at = some(data["joined_at"].str)
    if data.hasKey("large"):
        result.large = some(data["large"].bval)
    if data.hasKey("unavailable"):
        result.unavailable = some(data["unavailable"].bval)
    if data.hasKey("member_count"):
        result.member_count = some(data["member_count"].getInt())
    if data.hasKey("premium_subscription_count"):
        result.premium_subscription_count = some(data["premium_subscription_count"].getInt())

    if data.hasKey("max_presences") and data["max_presences"].kind != JNull:
        result.max_presences = some(data["max_presences"].getInt())
    if data.hasKey("embed_channel_id") and data["embed_channel_id"].kind != JNull:
        result.embed_channel_id = data["embed_channel_id"].str

    if data["icon"].kind != JNull:
        result.icon = some(data["icon"].str)
    if data["splash"].kind != JNull:
        result.splash = some(data["splash"].str)
    if data["afk_channel_id"].kind != JNull:
        result.afk_channel_id = some(data["afk_channel_id"].str)
    if data["application_id"].kind != JNull:
        result.application_id = some(data["application_id"].str)
    if data["system_channel_id"].kind != JNull:
        result.system_channel_id = some(data["system_channel_id"].str)
    if data["vanity_url_code"].kind != JNull:
        result.vanity_url_code = some(data["vanity_url_code"].str)
    if data.hasKey("description") and data["description"].kind != JNull:
        result.description = some(data["description"].str)
    if  data.hasKey("banner") and data["banner"].kind != JNull:
        result.banner = some(data["banner"].str)
    if data["discovery_splash"].kind != JNull:
        result.discovery_splash = some(data["discovery_splash"].str)

    if data.hasKey("members") and data["members"].elems.len > 0:
        for m in data["members"].elems:
            result.members.add(m["user"]["id"].str, newMember(m))

    if data.hasKey("voice_states") and data["voice_states"].elems.len > 0:
        for vs in data["voice_states"].elems:
            let state = newVoiceState(vs)

            result.members[vs["user_id"].str].voice_state = some(state)
            result.voice_states.add(vs["user_id"].str, state)

    if data.hasKey("channels") and data["channels"].elems.len > 0:
        for c in data["channels"].elems:

            result.channels.add(c["id"].str, newGuildChannel(c))

    if data.hasKey("presences") and data["presences"].elems.len > 0:
        for p in data["presences"].elems:
            let presence = newPresence(p)
            let uid = presence.user.id

            result.members[uid].presence = presence
            result.presences.add(uid, presence)

    if data["roles"].elems.len > 0:
        for r in data["roles"].elems:
            result.roles.add(r["id"].str, newRole(r))
    if data["emojis"].elems.len > 0:
        for e in data["emojis"].elems:
            result.emojis.add(e["id"].str, newEmoji(e))