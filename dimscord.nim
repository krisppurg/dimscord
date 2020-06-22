## Welcome to the Dimscord Documentation!
## 
## Reference
## ===================================
## 
## - For objects, this file includes the discord objects,
##   such as Message, Guild, User, Shard, etc.
##   This also includes some utils for permissions too.
## 
## - For gateway, this file allows you to
##   connect, disconnect, send gateway messages to the gateway.
##   Like updating your status with updateStatus,
##   requesting guild members with requestGuildMembers,
##   joining/moving/leaving a voice channel with voiceStateUpdate
## 
## - For restapi, this file would be pretty self-explantory,
##   as this file would handle ratelimits if you receive lots of 403s or 429s,
##   I'd recommend either stopping your bot or at least check your code
##   like if the bot has the permissions to do this and that,
##   for 429s the lib would at least try to re-send the request, the common
##   ways to get 429s is reactions and you may get 429s, though this is
##   more common in other libraries, if you were to add more reactions,
##   I'd recommend adding some sort of cooldowns to it.
##   (OAuth2 support will be added)
## 
## - For misc, this includes helper methods such as mentioning a user
##   @ify channels, users, roles, etc, this also includes iconUrls.
## 
## - For constants, say if you were to check what verification level is the guild
##   you can use the constants like vlHigh, vlLow, vlVeryHigh, vlMedium,
##   this file includes permission enums like permAddReactions, permViewAuditLogs,
##   permCreateInstantInvite, etc. Intents are also included there.

import dimscord/[gateway, restapi, constants, objects, misc]

export gateway, restapi, constants, objects, misc