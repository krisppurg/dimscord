## Welcome to the Dimscord Documentation!
##
## - If you have any errors like for example getGuildChannel doesn't exist in
##   v1.0.0, then you can just simply do `nimble install dimscord@#head` if
##   this does not work then uninstall the version you were using,
##   or you could replace the folder from the `.nimble/pkgs` directory.
## You can search for symbols by going to https://krisppurg.github.io/dimscord/theindex.html.
##
## Reference
## ===================================
## - `objects` Includes the discord objects,
##   such as Message, Guild, User, Shard, etc.
## 
## - `gateway` Allows you to connect, disconnect, send gateway messages
##   to the gateway. Like updating your status with updateStatus,
##   requesting guild members with requestGuildMembers,
##   joining/moving/leaving a voice channel with voiceStateUpdate.
## 
##   Please note that if you are compiling with ARC or ORC, use `--deepCopy`.
## 
## - `restapi` Interfaces with Discord's REST API,
##   I'd recommend either stopping your bot or at least check your code
##   like if the bot has the permissions to do this and that,
##   for 429s the lib would at least try to re-send the request, the common
##   ways to get 429s is reactions and you may get 429s, though this is
##   more common in other libraries, if you were to add more reactions,
##   I'd recommend adding some sort of cooldowns to it.
##   (`OAuth2` support will be added)
## 
## - `helpers` Includes helper methods such as mentioning a user
##   @ify channels, users, roles, etc, this includes iconUrls too.
## 
## - `constants` Say if you were to check what verification level is the guild
##   you can use the constants like vlHigh, vlLow, vlVeryHigh, vlMedium,
##   this file includes permission enums like permAddReactions, permViewAuditLogs,
##   permCreateInstantInvite, etc. Intents are also included there.
## 
## - `voice` Allows you to connect to the voice gateway (Sending audio is postponed),
##    handle voice gateway, etc.
##
##   For joining/leaving a voice channel, see `gateway`.
## 
##   **Keep in mind that:**
##    When you join a channel `Shard.voiceConnections` will store the `guild_id`,
##    and the VoiceClient information such as the `endpoint` and `channel_id` for example.
##    With `VoiceClient` you can connect to the voice client gateway
##    so you can play audio on `on_ready`.
##
##   For further details about `voice` click `dimscord/voice`.
## 
## Modules required
## ===================
## Sometimes you would need some modules in order to use in procedures,
## for example if you were to edit a guild member you would need to
## import options to provide an Option type.
## 
## - [asyncdispatch](https://nim-lang.org/docs/asyncdispatch.html) This one is needed.
## - [options](https://nim-lang.org/docs/options.html) Optional parameters, e.g. `mute = some true`.
## - [base64](https://nim-lang.org/docs/base64.html) Icons such as Guild icons or emoji image.
## - [json](https://nim-lang.org/docs/json.html) Raw data handling (`on_dispatch`)
## 
## Definable options
## ==============
## - `-d:dimscordDebug` For debugging rest, gateway and voice.
## - `-d:discordCompress` Compress gateway payloads, by using zippy.
## - `-d:discordv8` Discord API v8 if v6 or v7 is no longer function consider defining it.

import dimscord/[
    gateway, restapi, constants,
    objects, helpers, voice
]

export gateway, restapi, constants, objects, helpers, voice