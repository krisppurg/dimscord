## Interaction with the Discord API:
##
## Quick note: for executing webhooks, this can also apply to interactions, I'd recommend reading:
## https://discord.com/developers/docs/interactions/application-commands
## 
## Endpoint aliases start here:
## [Edit Original Interaction Response](https://discord.com/developers/docs/interactions/receiving-and-responding#edit-original-interaction-response)
##  -> editWebhookMessage
## 
## [Delete Original Interaction Response](https://discord.com/developers/docs/interactions/receiving-and-responding#delete-original-interaction-response)
##  -> deleteWebhookMessage
include restapi/[message, channel, guild, user]