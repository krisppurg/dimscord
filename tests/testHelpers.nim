# dimscord/tests/helpers_test.nim
import unittest
import asyncdispatch
import options, tables
import json
import ../dimscord/objects
import ../dimscord/constants
import ../dimscord/restapi
import ../dimscord/helpers

# Mock data for testing
let mockString = "mock_id"
let mockInt = 42
let mockOptionString = some("mock_option")
let mockOptionInt = some(42)
let mockOptionBool = some(true)
let mockSeqString = @["mock1", "mock2"]
let mockTableString = {"en-US": some("mock_value")}.toTable()
let mockEmbed = Embed(title: some("Test Embed"))
let mockAttachment = Attachment(id: "123", filename: "test.txt")
let mockComponent = MessageComponent(kind: MessageComponentType.Button, custom_id: some("mock_button"))
let mockFile = DiscordFile(name: "test.txt", body: "")
let mockAllowedMentions = AllowedMentions(parse: @[])
let mockPermObj = PermObj(allowed: {}, denied: {})
let mockEmoji = Emoji(id: some("123"), name: some("mock_emoji"))
let mockSticker = Sticker(id: "123", name: "mock_sticker")
let mockApplicationCommand = ApplicationCommand.default()
let mockApplicationCommandOption = ApplicationCommandOption(
  kind: ApplicationCommandOptionType.acotNothing,
  name: "mock_option",
  description: "mock description",
)

# Mock objects
var mockMessage = Message(id: "123", channel_id: "456", content: "test message")
var mockChannel = GuildChannel(
  id: "123", name: "test-channel", guild_id: "456",
  kind: ChannelType.ctGuildText
)
var mockGuildScheduledEvent = GuildScheduledEvent(id: "123", guild_id: "456")
var mockStageInstance = StageInstance.default()
var mockSomeChannel: SomeChannel = mockChannel # todo
var mockGuild = new Guild
var mockInvite = Invite(code: "mock_code", guild: some(PartialGuild(id: "123", icon: some "test-icon", splash: some "456")))
var mockMember = Member(
  user: User(id: "123", username: "testuser"), guild_id: "456",
      nick: some "testnick"
)
var mockRole = Role(id: "123", name: "test-role",
    permissions: PermissionFlags.fullSet)
var mockUser = new User
var mockApplication = Application.default()
var mockInteraction = Interaction(
  id: "123",
  application_id: "456",
  token: "mock_token",
  kind: InteractionType.itApplicationCommand,
)
var mockAutoModRule = AutoModerationRule.default()
var mockIntegration = Integration.default()

let discord {.mainClient.} = newDiscordClient("mock")

suite "Channel Helpers Tests":
  test "pin template":
    check:
      compiles(mockMessage.pin())
      compiles(mockMessage.pin("test reason"))

  test "unpin template":
    check:
      compiles(mockMessage.unpin())
      compiles(mockMessage.unpin("test reason"))

  test "getPins template":
    check:
      compiles(mockChannel.getPins())

  test "deleteChannel template":
    check:
      compiles(mockChannel.deleteChannel())
      compiles(mockChannel.deleteChannel("test reason"))

  test "getInvites template":
    check:
      compiles(mockChannel.getInvites())

  test "getWebhooks template":
    check:
      compiles(mockChannel.getWebhooks())

  test "newThread template":
    check:
      compiles(mockChannel.newThread("test-thread"))
      compiles(mockChannel.newThread("test-thread", auto_archive_duration = 60))
      compiles(
        mockChannel.newThread("test-thread",
            kind = ChannelType.ctGuildPrivateThread)
      )
      compiles(mockChannel.newThread("test-thread", invitable = mockOptionBool))
      compiles(mockChannel.newThread("test-thread", reason = "test reason"))

  test "createStageInstance template":
    check:
      compiles(mockChannel.createStageInstance("test topic"))
      compiles(mockChannel.createStageInstance("test topic", "test reason"))
      compiles(mockChannel.createStageInstance("test topic", "test reason", privacy = 0))
      compiles(mockChannel.createStageInstance("test topic", "test reason", privacy = 1))

  test "edit template":
    check:
      compiles(mockChannel.edit(name = some "test"))
      compiles(mockChannel.edit(parent_id = some "test"))
      compiles(mockChannel.edit(topic = some "test"))
      compiles(mockChannel.edit(rtc_region = some "test"))
      compiles(mockChannel.edit(default_auto_archive_duration = some 60))
      compiles(mockChannel.edit(video_quality_mode = some 1))
      compiles(mockChannel.edit(flags = some {cfPinned}))
      compiles(mockChannel.edit(available_tags = some(@[default(ForumTag)])))
      compiles(
        mockChannel.edit(default_reaction_emoji = some default(DefaultForumReaction))
      )
      compiles(mockChannel.edit(default_sort_order = some 1))
      compiles(mockChannel.edit(default_forum_layout = some 1))
      compiles(mockChannel.edit(rate_limit_per_user = some range[0..21600](0)))
      compiles(mockChannel.edit(default_thread_rate_limit_per_user = some range[0..21600](0)))
      compiles(mockChannel.edit(bitrate = some range[8000..128000](8000)))
      compiles(mockChannel.edit(user_limit = some range[0..99](0)))
      compiles(mockChannel.edit(position = some 0))
      compiles(mockChannel.edit(permission_overwrites = some(@[default(Overwrite)])))
      compiles(mockChannel.edit(nsfw = some true))
      compiles(mockChannel.edit(reason = "test reason"))

  test "createChannel template":
    check:
      compiles(mockGuild.createChannel("test-channel"))
      compiles(mockGuild.createChannel("test-channel", kind = 0))
      compiles(mockGuild.createChannel("test-channel", parent_id = some "test"))
      compiles(mockGuild.createChannel("test-channel", topic = some "test"))
      compiles(mockGuild.createChannel("test-channel", rtc_region = some "test"))
      compiles(mockGuild.createChannel("test-channel", nsfw = some true))
      compiles(mockGuild.createChannel("test-channel", position = some 0))
      compiles(mockGuild.createChannel("test-channel",video_quality_mode = some 1))
      compiles(mockGuild.createChannel("test-channel",default_sort_order = some 1))
      compiles(mockGuild.createChannel("test-channel",default_forum_layout = some 1))
      compiles(mockGuild.createChannel("test-channel", default_thread_rate_limit_per_user = some 0))
      compiles(mockGuild.createChannel("test-channel", available_tags = some(@[default(ForumTag)])))
      compiles(mockGuild.createChannel("test-channel", default_reaction_emoji = some default(DefaultForumReaction)))
      compiles(mockGuild.createChannel("test-channel", rate_limit_per_user = some range[0..21600](0)))
      compiles(mockGuild.createChannel("test-channel", bitrate = some range[8000..128000](8000)))
      compiles(mockGuild.createChannel("test-channel", user_limit = some range[0..99](0)))
      compiles(mockGuild.createChannel("test-channel", permission_overwrites = some(@[default(Overwrite)])))
      compiles(mockGuild.createChannel("test-channel", reason = "test reason"))

  test "createInvite template":
    check:
      compiles(mockChannel.createInvite())
      compiles(mockChannel.createInvite(max_age = 86400))
      compiles(mockChannel.createInvite(max_uses = 0))
      compiles(mockChannel.createInvite(temporary = false))
      compiles(mockChannel.createInvite(unique = false))
      compiles(mockChannel.createInvite(target_user = some "test"))
      compiles(mockChannel.createInvite(target_user_id = some "test"))
      compiles(mockChannel.createInvite(target_application_id = some "test"))
      compiles(mockChannel.createInvite(target_type = some ittStream))
      compiles(mockChannel.createInvite(reason = "test reason"))

  test "delete invite template":
    check:
      compiles(mockInvite.delete("test reason"))

  test "editStageInstance template":
    check:
      compiles(mockStageInstance.editStageInstance(topic = "test"))
      compiles(mockStageInstance.editStageInstance(topic = "test", privacy = some 0))
      compiles(mockStageInstance.editStageInstance(topic = "test", reason = "test reason"))

  test "deleteStageInstance template":
    check:
      compiles(deleteStageInstance("test_id", reason = "test reason"))
      compiles(mockStageInstance.deleteStageInstance(reason = "test reason"))

suite "Guild Helpers Tests":
  test "beginPrune template":
    check:
      compiles(mockGuild.beginPrune())
      compiles(mockGuild.beginPrune(days = 7))
      compiles(mockGuild.beginPrune(include_roles = mockSeqString))
      compiles(mockGuild.beginPrune(compute_prune_count = true))

  test "getPruneCount template":
    check:
      compiles(mockGuild.getPruneCount(7))

  test "editMFA template":
    check:
      compiles(mockGuild.editMFA(MFALevel.mfaNone))
      compiles(mockGuild.editMFA(MFALevel.mfaNone, "test reason"))

  test "delete template":
    check:
      compiles(mockGuild.delete())

  test "edit template":
    check:
      compiles(mockGuild.edit())
      compiles(mockGuild.edit(name = some "test"))
      compiles(mockGuild.edit(description = some "test"))
      compiles(mockGuild.edit(region = some "test"))
      compiles(mockGuild.edit(afk_channel_id = some "test"))
      compiles(mockGuild.edit(icon = some "test"))
      compiles(mockGuild.edit(discovery_splash = some "test"))
      compiles(mockGuild.edit(owner_id = some "test"))
      compiles(mockGuild.edit(splash = some "test"))
      compiles(mockGuild.edit(banner = some "test"))
      compiles(mockGuild.edit(system_channel_id = some "test"))
      compiles(mockGuild.edit(rules_channel_id = some "test"))
      compiles(mockGuild.edit(preferred_locale = some "test"))
      compiles(mockGuild.edit(public_updates_channel_id = some "test"))
      compiles(mockGuild.edit(verification_level = some 0))
      compiles(mockGuild.edit(default_message_notifications = some 0))
      compiles(mockGuild.edit(system_channel_flags = some 0))
      compiles(mockGuild.edit(explicit_content_filter = some 0))
      compiles(mockGuild.edit(afk_timeout = some 0))
      compiles(mockGuild.edit(features = @["test"]))
      compiles(mockGuild.edit(premium_progress_bar_enabled = some true))
      compiles(mockGuild.edit(reason = "test reason"))

  test "getAuditLogs template":
    check:
      compiles(mockGuild.getAuditLogs())
      compiles(mockGuild.getAuditLogs(user_id = "test_user"))
      compiles(mockGuild.getAuditLogs(before = "test_before"))
      compiles(mockGuild.getAuditLogs(action_type = -1))
      compiles(mockGuild.getAuditLogs(limit = 50))

  test "deleteRole template":
    check:
      compiles(mockGuild.deleteRole(mockRole))

  test "getInvites template":
    check:
      compiles(mockGuild.getInvites())

  test "getVanity template":
    check:
      compiles(mockGuild.getVanity())

  test "removeMember template":
    check:
      compiles(mockGuild.removeMember(mockMember))
      compiles(mockGuild.removeMember(mockMember, "test reason"))

  test "getBan template":
    check:
      compiles(mockGuild.getBan(mockMember))
      compiles(mockGuild.getBan("test_user"))

  test "getBans template":
    check:
      compiles(mockGuild.getBans())

  test "ban template":
    check:
      compiles(mockGuild.ban(mockMember))
      compiles(mockGuild.ban(mockMember, delete_msg_days = 0))
      compiles(mockGuild.ban(mockMember, reason = "test reason"))

  test "getIntegrations template":
    check:
      compiles(mockGuild.getIntegrations())

  test "getWebhooks template":
    check:
      compiles(mockGuild.getWebhooks())

  test "preview template":
    check:
      compiles(mockGuild.preview())

  test "searchMembers template":
    check:
      compiles(mockGuild.searchMembers())
      compiles(mockGuild.searchMembers(query = "test"))
      compiles(mockGuild.searchMembers(limit = 1))

  test "deleteEmoji template":
    check:
      compiles(mockGuild.deleteEmoji(mockEmoji))
      compiles(mockGuild.deleteEmoji(mockEmoji, "test reason"))

  test "getRegions template":
    check:
      compiles(mockGuild.getRegions())

  test "editSticker template":
    check:
      compiles(mockGuild.editSticker(mockSticker))
      compiles(mockGuild.editSticker(mockSticker, name = some "test"))
      compiles(mockGuild.editSticker(mockSticker, desc = some "test"))
      compiles(mockGuild.editSticker(mockSticker, tags = some "test"))
      compiles(mockGuild.editSticker(mockSticker, reason = "test reason"))

  test "deleteSticker template":
    check:
      compiles(mockGuild.deleteSticker(mockSticker))
      compiles(mockGuild.deleteSticker(mockSticker, "test reason"))

  test "getScheduledEvent template":
    check:
      compiles(mockGuild.getScheduledEvent("event_id"))
      compiles(mockGuild.getScheduledEvent("event_id", with_user_count = false))

  test "getScheduledEvents template":
    check:
      compiles(mockGuild.getScheduledEvents())

  test "delete scheduled event template":
    check:
      compiles(GuildScheduledEvent(id: "123", guild_id: "456").delete())
      compiles(GuildScheduledEvent(id: "123", guild_id: "456").delete("test reason"))

  test "getEventUsers template":
    check:
      compiles(GuildScheduledEvent(id: "123", guild_id: "456").getEventUsers())
      compiles(
        GuildScheduledEvent(id: "123", guild_id: "456").getEventUsers(limit = 100)
      )
      compiles(
        GuildScheduledEvent(id: "123", guild_id: "456").getEventUsers(
          with_member = false
        )
      )
      compiles(
        GuildScheduledEvent(id: "123", guild_id: "456").getEventUsers(
          before = "test_before"
        )
      )
      compiles(
        GuildScheduledEvent(id: "123", guild_id: "456").getEventUsers(
          after = "test_after"
        )
      )

  test "getRules template":
    check:
      compiles(mockGuild.getRules())

  test "getRule template":
    check:
      compiles(mockGuild.getRule("rule_id"))

  test "deleteRule template":
    check:
      compiles(mockGuild.deleteRule(AutoModerationRule(id: "123",
          guild_id: "456")))

  test "editRole template":
    check:
      compiles(mockGuild.editRole(mockRole))
      compiles(mockGuild.editRole(mockRole, name = some "test"))
      compiles(mockGuild.editRole(mockRole, icon = some "test"))
      compiles(mockGuild.editRole(mockRole, unicode_emoji = some "test"))
      compiles(mockGuild.editRole(mockRole, permissions = some default(PermObj)))
      compiles(mockGuild.editRole(mockRole, color = some 0))
      compiles(mockGuild.editRole(mockRole, hoist = some true))
      compiles(mockGuild.editRole(mockRole, mentionable = some true))
      compiles(mockGuild.editRole(mockRole, reason = "test reason"))

  test "editMember template":
    check:
      compiles(mockGuild.editMember(mockMember))
      compiles(mockGuild.editMember(mockMember, nick = some "test"))
      compiles(mockGuild.editMember(mockMember, channel_id = some "test"))
      compiles(
        mockGuild.editMember(
          mockMember, communication_disabled_until = some "2023-01-01T00:00:00.000Z"
        )
      )
      compiles(mockGuild.editMember(mockMember, roles = some(@["test"])))
      compiles(mockGuild.editMember(mockMember, mute = some true))
      compiles(mockGuild.editMember(mockMember, deaf = some true))
      compiles(mockGuild.editMember(mockMember, reason = "test reason"))

  test "bulkBan template":
    check:
      compiles(mockGuild.bulkBan(@["user1", "user2"]))
      compiles(mockGuild.bulkBan(@["user1", "user2"],
          delete_message_seconds = 0))
      compiles(mockGuild.bulkBan(@["user1", "user2"], reason = "test reason"))

  test "removeBan template":
    check:
      compiles(mockGuild.removeBan(mockUser))
      compiles(mockGuild.removeBan("test_user"))
      compiles(mockGuild.removeBan(mockUser, reason = "test reason"))

  test "deleteIntegration template":
    check:
      compiles(mockIntegration.deleteIntegration())
      compiles(mockIntegration.deleteIntegration(reason = "test reason"))

  test "editEmoji template":
    check:
      compiles(mockGuild.editEmoji(mockEmoji))
      compiles(mockGuild.editEmoji(mockEmoji, name = some "test"))
      compiles(mockGuild.editEmoji(mockEmoji, roles = some(@["test"])))
      compiles(mockGuild.editEmoji(mockEmoji, reason = "test reason"))

  test "editEvent template":
    check:
      compiles(mockGuild.editEvent(mockGuildScheduledEvent))
      compiles(mockGuild.editEvent(mockGuildScheduledEvent, name = some "test"))
      compiles(mockGuild.editEvent(mockGuildScheduledEvent, reason = "test reason"))
      compiles(mockGuild.editEvent(mockGuildScheduledEvent, start_time = some "2023-01-01T00:00:00.000Z"))
      compiles(mockGuild.editEvent(mockGuildScheduledEvent, end_time = some "2023-01-01T00:00:00.000Z"))
      compiles(mockGuild.editEvent(mockGuildScheduledEvent, image = some "test"))
      compiles(mockGuild.editEvent(mockGuildScheduledEvent, reason = "test reason"))
      compiles(mockGuild.editEvent(mockGuildScheduledEvent, channel_id = some "test"))
      compiles(mockGuild.editEvent(mockGuildScheduledEvent, end_time = some "2023-01-01T00:00:00.000Z"))
      compiles(mockGuild.editEvent(mockGuildScheduledEvent, desc = some "test"))
      compiles(mockGuild.editEvent(mockGuildScheduledEvent, privacy_level = some splGuildOnly))
      compiles(mockGuild.editEvent(mockGuildScheduledEvent, entity_type = some etStageInstance))
      compiles(mockGuild.editEvent(mockGuildScheduledEvent, entity_metadata = some default(EntityMetadata)))
      compiles(mockGuild.editEvent(mockGuildScheduledEvent, status = some esScheduled))
      compiles(mockGuild.editEvent(mockGuildScheduledEvent, reason = "test reason"))

  test "editRule template":
    check:
      compiles(mockGuild.editRule(mockAutoModRule))
      compiles(mockGuild.editRule(mockAutoModRule, event_type = some 1))
      compiles(mockGuild.editRule(mockAutoModRule, name = some "test"))
      compiles(mockGuild.editRule(mockAutoModRule, trigger_type = none ModerationTriggerType, trigger_metadata = none TriggerMetadata))
      compiles(mockGuild.editRule(mockAutoModRule, actions = some(@[default(ModerationAction)])))
      compiles(mockGuild.editRule(mockAutoModRule, enabled = some true))
      compiles(mockGuild.editRule(mockAutoModRule, exempt_roles = some(@["test"])))
      compiles(mockGuild.editRule(mockAutoModRule, exempt_channels = some(@["test"])))
      compiles(mockGuild.editRule(mockAutoModRule, reason = "test reason"))

suite "Message Helpers Tests":
  test "send template":
    check:
      # todo: poll, allowed_mentions, message_reference
      compiles(mockSomeChannel.send("test message"))
      compiles(mockSomeChannel.send(tts = false))
      compiles(mockSomeChannel.send(nonce = mockOptionInt))
      compiles(mockSomeChannel.send(files = @[mockFile]))
      compiles(mockSomeChannel.send(embeds = @[mockEmbed]))
      compiles(mockSomeChannel.send(attachments = @[mockAttachment]))
      compiles(mockSomeChannel.send(components = @[mockComponent]))
      compiles(mockSomeChannel.send(sticker_ids = @["sticker1"]))
      compiles(mockSomeChannel.send(enforce_nonce = mockOptionBool))

  test "reply template":
    check:
      #todo: allowed_mentions, tts
      compiles(mockMessage.reply("test reply"))
      compiles(mockMessage.reply(embeds = @[mockEmbed]))
      compiles(mockMessage.reply(attachments = @[mockAttachment]))
      compiles(mockMessage.reply(components = @[mockComponent]))
      compiles(mockMessage.reply(files = @[mockFile]))
      compiles(mockMessage.reply(stickers = @["sticker1"]))
      compiles(mockMessage.reply(nonce = mockOptionInt))
      compiles(mockMessage.reply(mention = false))
      compiles(mockMessage.reply(failifnotexists = false))

  test "editMessage template":
    check:
      compiles(mockSomeChannel.editMessage(mockMessage))
      compiles(mockSomeChannel.editMessage(mockMessage, content = "updated"))
      compiles(mockSomeChannel.editMessage(mockMessage, embeds = @[mockEmbed]))
      compiles(
        mockSomeChannel.editMessage(mockMessage, attachments = @[mockAttachment])
      )
      compiles(mockSomeChannel.editMessage(mockMessage, components = @[
          mockComponent]))
      compiles(mockSomeChannel.editMessage(mockMessage, files = @[mockFile]))
      compiles(mockSomeChannel.editMessage(mockMessage, tts = false))
      compiles(mockSomeChannel.editMessage(mockMessage, flags = mockOptionInt))

  test "edit message template":
    check:
      compiles(mockMessage.edit())
      compiles(mockMessage.edit(content = "updated"))
      compiles(mockMessage.edit(embeds = @[mockEmbed]))
      compiles(mockMessage.edit(attachments = @[mockAttachment]))
      compiles(mockMessage.edit(components = @[mockComponent]))
      compiles(mockMessage.edit(files = @[mockFile]))
      compiles(mockMessage.edit(tts = false))
      compiles(mockMessage.edit(flags = mockOptionInt))

  test "delete message template":
    check:
      compiles(mockMessage.delete())
      compiles(mockMessage.delete("test reason"))

  test "delete messages template":
    check:
      compiles(@[mockMessage].delete())
      compiles(@[mockMessage].delete("test reason"))

  test "getMessages template":
    check:
      compiles(mockSomeChannel.getMessages())
      compiles(mockSomeChannel.getMessages(around = "test_around"))
      compiles(mockSomeChannel.getMessages(before = "test_before"))
      compiles(mockSomeChannel.getMessages(after = "test_after"))
      compiles(mockSomeChannel.getMessages(limit = 50))

  test "getMessage template":
    check:
      compiles(mockSomeChannel.getMessage("message_id"))

  test "react proc":
    check:
      compiles(mockMessage.react("emoji"))

  test "removeReaction template":
    check:
      compiles(mockMessage.removeReaction("emoji"))
      compiles(mockMessage.removeReaction("emoji", "user_id"))

  test "removeReactionEmoji template":
    check:
      compiles(mockMessage.removeReactionEmoji("emoji"))

  test "getReactions template":
    check:
      compiles(mockMessage.getReactions("emoji"))
      compiles(mockMessage.getReactions("emoji", kind = ReactionType.rtNormal))
      compiles(mockMessage.getReactions("emoji", after = "test_after"))
      compiles(mockMessage.getReactions("emoji", limit = 25))

  test "clearReactions template":
    check:
      compiles(mockMessage.clearReactions())

  test "getThreadMembers template":
    check:
      compiles(mockChannel.getThreadMembers())

  test "removeFromThread template":
    check:
      compiles(mockChannel.removeFromThread(mockMember))
      compiles(mockChannel.removeFromThread(mockUser))
      compiles(mockChannel.removeFromThread("user_id"))
      compiles(mockChannel.removeFromThread(mockMember, "test reason"))

  test "addThreadMember template":
    check:
      compiles(mockChannel.addThreadMember(mockMember))
      compiles(mockChannel.addThreadMember(mockUser))
      compiles(mockChannel.addThreadMember("user_id"))
      compiles(mockChannel.addThreadMember(mockMember, "test reason"))

  test "leaveThread template":
    check:
      compiles(mockChannel.leaveThread())

  test "joinThread template":
    check:
      compiles(mockChannel.joinThread())

  test "startThread template":
    check:
      compiles(mockMessage.startThread("thread name", 60))
      compiles(mockMessage.startThread("thread name", 60, "test reason"))

  test "endPoll template":
    check:
      compiles(mockMessage.endPoll("poll name", 60))
      compiles(mockMessage.endPoll("poll name", 60, "test reason"))

  test "getPollAnswerVoters template":
    check:
      compiles(mockMessage.getPollAnswerVoters("answer_id"))
      compiles(mockMessage.getPollAnswerVoters("answer_id",
          after = mockOptionString))
      compiles(mockMessage.getPollAnswerVoters("answer_id", limit = 25))

  test "getThreadMember template":
    check:
      compiles(mockChannel.getThreadMember(mockUser))
      compiles(mockChannel.getThreadMember("user_id"))
      compiles(mockChannel.getThreadMember(mockUser, with_member = true))

suite "User Helpers Tests":
  test "getMember template":
    check:
      compiles(mockGuild.getMember("user_id"))

  test "getMembers template":
    check:
      compiles(mockGuild.getMembers())
      compiles(mockGuild.getMembers(limit = 1))
      compiles(mockGuild.getMembers(after = "0"))

  test "setNickname template":
    check:
      compiles(mockGuild.setNickname("nickname"))
      compiles(mockGuild.setNickname("nickname", "test reason"))

  test "addRole template":
    check:
      compiles(mockMember.addRole(mockRole))
      compiles(mockMember.addRole("role_id"))
      compiles(mockMember.addRole(mockRole, "test reason"))

  test "removeRole template":
    check:
      compiles(mockMember.removeRole(mockRole))
      compiles(mockMember.removeRole(mockRole, "test reason"))

  test "leave template":
    check:
      compiles(mockGuild.leave())

  test "getSelf template":
    check:
      compiles(mockGuild.getSelf())

  test "getCommands template":
    check:
      compiles(mockApplication.getCommands())
      compiles(mockApplication.getCommands(guild_id = "guild_id"))
      compiles(mockApplication.getCommands(with_localizations = false))

  test "getCommand template":
    check:
      compiles(mockApplication.getCommand(command_id = "command_id"))
      compiles(mockApplication.getCommand(guild_id = "guild_id", command_id = "command_id"))

  test "registerCommand template":
    check:
      compiles(mockApplication.registerCommand("command_name", "command_description"))
      compiles(mockApplication.registerCommand("command_name", "command_description", name_localizations = some default(Table[string, string])))
      compiles(mockApplication.registerCommand("command_name", "command_description", description_localizations = some default(Table[string, string])))
      compiles(mockApplication.registerCommand("command_name", "command_description", name_localizations = some default(Table[string, string]), description_localizations = some default(Table[string, string])))
      compiles(mockApplication.registerCommand("command_name", "command_description", kind = ApplicationCommandType.atSlash))
      compiles(mockApplication.registerCommand("command_name", "command_description", guild_id = "guild_id"))
      compiles(mockApplication.registerCommand("command_name", "command_description", dm_permission = true))
      compiles(mockApplication.registerCommand("command_name", "command_description", nsfw = true))
      compiles(mockApplication.registerCommand("command_name", "command_description", default_member_permissions = some default(PermissionFlags)))
      compiles(mockApplication.registerCommand("command_name", "command_description", options = @[mockApplicationCommandOption]))

  test "followup template":
    check:
      compiles(mockInteraction.followup())
      compiles(mockInteraction.followup(content = "followup"))
      compiles(mockInteraction.followup(embeds = @[mockEmbed]))
      compiles(mockInteraction.followup(components = @[mockComponent]))
      compiles(mockInteraction.followup(attachments = @[mockAttachment]))
      compiles(mockInteraction.followup(files = @[mockFile]))
      compiles(mockInteraction.followup(allowed_mentions = some default(AllowedMentions)))
      compiles(mockInteraction.followup(tts = false))
      compiles(mockInteraction.followup(ephemeral = false))
      compiles(mockInteraction.followup(thread_id = some "test"))
      compiles(mockInteraction.followup(thread_name = some "test"))
      compiles(mockInteraction.followup(applied_tags = @["tag1"]))
      compiles(mockInteraction.followup(poll = some default(PollRequest)))

  test "editCommand template":
    check:
      compiles(mockApplicationCommand.editCommand(name = "new_name"))
      compiles(mockApplicationCommand.editCommand(desc = "new_desc"))
      compiles(mockApplicationCommand.editCommand(name_localizations = some default(Table[string, string])))
      compiles(mockApplicationCommand.editCommand(description_localizations = some default(Table[string, string])))
      compiles(mockApplicationCommand.editCommand(default_member_permissions = some default(PermissionFlags)))
      compiles(mockApplicationCommand.editCommand(options = @[mockApplicationCommandOption]))

  test "delete command template":
    check:
      compiles(mockApplicationCommand.delete())
      compiles(mockApplicationCommand.delete("guild_id"))

  test "bulkRegisterCommands template":
    check:
      compiles(mockApplication.bulkRegisterCommands(@[]))
      compiles(mockApplication.bulkRegisterCommands(@[ApplicationCommand(id: "123")]))
      compiles(mockApplication.bulkRegisterCommands(@[ApplicationCommand(id: "123")], guild_id = "guild_id"))

  test "reply interaction template":
    check:
      compiles(mockInteraction.reply(content = "response"))
      compiles(mockInteraction.reply(embeds = @[mockEmbed]))
      compiles(mockInteraction.reply(components = @[mockComponent]))
      compiles(mockInteraction.reply(attachments = @[mockAttachment]))
      compiles(mockInteraction.reply(allowed_mentions = mockAllowedMentions))
      compiles(mockInteraction.reply(tts = mockOptionBool))
      compiles(mockInteraction.reply(ephemeral = false))

  test "update interaction template":
    check:
      compiles(mockInteraction.update())
      compiles(mockInteraction.update(content = "updated"))
      compiles(mockInteraction.update(embeds = @[mockEmbed]))
      compiles(mockInteraction.update(flags = {}))
      compiles(mockInteraction.update(attachments = @[mockAttachment]))
      compiles(mockInteraction.update(components = @[mockComponent]))
      compiles(mockInteraction.update(allowed_mentions = mockAllowedMentions))
      compiles(mockInteraction.update(tts = mockOptionBool))


  test "editResponse template":
    check:
      # todo: allowed_mentions
      compiles(mockInteraction.editResponse(content = mockOptionString))
      compiles(mockInteraction.editResponse(embeds = @[mockEmbed]))
      compiles(mockInteraction.editResponse(attachments = @[mockAttachment]))
      compiles(mockInteraction.editResponse(files = @[mockFile]))
      compiles(mockInteraction.editResponse(components = @[mockComponent]))
      compiles(mockInteraction.editResponse(message_id = "@original"))

  test "getResponse template":
    check:
      compiles(mockInteraction.getResponse())
      compiles(mockInteraction.getResponse("message_id"))

  test "delete interaction response template":
    check:
      compiles(mockInteraction.delete())
      compiles(mockInteraction.delete("message_id"))

  test "deferResponse template":
    check:
      compiles(mockInteraction.deferResponse())
      compiles(mockInteraction.deferResponse(ephemeral = false))
      compiles(mockInteraction.deferResponse(hide = false))

  test "suggest template":
    check:
      compiles(mockInteraction.suggest(@[ApplicationCommandOptionChoice(name: "mock_choice", value: (some("mock_value"), none(int)))]))

  test "sendModal template":
    check:
      compiles(mockInteraction.sendModal(InteractionCallbackDataModal(custom_id: "mock_modal", title: "Mock Modal", components: @[])))
