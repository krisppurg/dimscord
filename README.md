
# <img src="assets/dimscord.png" width="42px" height="32px"/>  Dimscord
A Discord Bot & REST Library for Nim. [Discord Server](https://discord.gg/bw4mHUV)

Why Dimscord?
 * It is minimalistic and efficient. 
 * Nim is a good programming language and I believe that Nim should stand a chance on having an up-to-date good enough discord library.
 * It has REST mode only feature, which isn't cache reliant.
 * The other nim discord library has bunch of issues and it's unmaintained.
 
 ## FAQ:
 What is Nim?
   * Nim is a young statically-typed programming language that compiles to C/C++/JavaScript. It's similar to python and it's syntax is more clear. [You can read it more in the official website for Nim](https://nim-lang.org)

 Where is the Documentation for the library in devel?
   * https://krisppurg.github.io/dimscord-devel-docs

## Notes:
 * For compressing data and stuff you would need zlib1.(dll,dylib,so.1) to be installed, you can put it at your `.nimble/bin` directory or just simply put it at your folder.
 * Voice support will be added on later.
 * If your bot is in a large guild (>50-250 large_threshold), I'd recommend turning off guild_subscriptions or use intents, if you want to get a guild member use the requestGuildMembers proc, that way you can get a specific guild member from a large guild; if you have presence intent enabled and you are debugging with a large guild,
 dont debug because it will slow down your bot.
 * If you are interested in contributing to Dimscord, I'd recommend reading the CONTRIBUTING.md file.

## How to install Dimscord:
### Step 1: Install Nim

 You can use [choosenim](https://github.com/dom96/choosenim) or you could download it from [Nim's website](https://nim-lang.org/install.html)

 ### Step 2: Install Dimscord
 You'd can install Dimscord via Nimble using `nimble install dimscord` or Github `git clone https://github.com/krisppurg/dimscord`

You will need at least Nim 1.2.0 to install dimscord
 
 ### Step 3: Enjoy.
 Stay up-to-date with the latest Dimscord release and stuff.

## Quick Example:
```nim
import dimscord, asyncdispatch, times, options

let discord = newDiscordClient("<your bot token goes here>")

# Handle event for on_ready.
discord.events.on_ready = proc (s: Shard, r: Ready) {.async.} =
    echo "Ready as " & $r.user

# Handle event for message_create.
discord.events.message_create = proc (s: Shard, m: Message) {.async.} =
    if m.author.bot: return
    if m.content == "!ping": # If message content is "!ping".
        let
            before = epochTime() * 1000
            msg = await discord.api.sendMessage(m.channel_id, "ping?")
            after = epochTime() * 1000
        # Edit the message as pong! Use 'discard' because editMessage returns a new message.
        discard await discord.api.editMessage(
            m.channel_id,
            msg.id, 
            "Pong! took " & $int(after - before) & "ms | " & $s.latency() & "ms."
        )
    elif m.content == "!embed": # Otherwise if content is embed.
        # Sends a messge with embed.
        discard await discord.api.sendMessage(
            m.channel_id,
            embed = some Embed(
                title: some "Hello there!", 
                description: some "This is description",
                color: some 0x7789ec
            )
        )

# Connect to Discord and run the bot.
waitFor discord.startSession()
```
Please make sure that when you are running your discord bot you would need to define `-d:ssl` example: `nim c -r -d:ssl main.nim`, you can use `-d:dimscordDebug`, if you want to debug.