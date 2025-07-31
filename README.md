# <img src="assets/dimscord.png" width="42px" height="32px"/>  Dimscord
A Discord Bot & REST Library for Nim. [Discord API Channel](https://discord.gg/7jgdC9E) and [Dimscord Server for help](https://discord.gg/dimscord)

## HEADS UP
> :warning: **UPDATE**: Since v1.6.0 is broken due to stupid jsony issues, you **MUST** uninstall dimscord completely then do `nimble install dimscord@#e2f1bc6` to fix your problems. A new version is coming out soon with some new changes to be made more info will be provided in the tag with whats changed. If you have any further issues, feel free to report issue here or ask in the dimscord server.

Why Dimscord?
 * It is minimalistic and efficient. 
 * Nim is a good programming language and I believe that Nim should stand a chance on having an up-to-date, substantial discord library.
 * It has a REST-mode only feature, which isn't cache-reliant.
 * The other Nim Discord library (discordnim) has bunch of issues, and it's unmaintained.
 
 ## FAQ:
 * What is Nim?
   * Nim is a statically-typed programming language (older than Go and Rust) that compiles to C/C++/JavaScript.
   It is similar to Python, easier to learn, and it's flexible. [You can read it more in the official website for Nim.](https://nim-lang.org)
 * Why use Nim for Discord bots?
   * Since it's easier to learn, it's faster than any other interpreted languages,
    which is beneficial for the performance of larger discord bots.
    [You can read the Nim FAQ here](https://nim-lang.org/faq.html)
 * Is there a command handler for Dimscord?
   * [Yes](https://github.com/ire4ever1190/dimscmd), but not in this library.

## Getting Started:
1. Install Nim using [choosenim](https://github.com/dom96/choosenim) or [Nim's website](https://nim-lang.org/install.html)

2. Install Dimscord via Nimble using `nimble install dimscord` or GitHub `git clone https://github.com/krisppurg/dimscord`
   * You will need at least Nim 1.2.0 to install dimscord
 
3. Read the Wiki or Examples for referencing. Maybe even rewrite your bot if you want to switch.
 
4. Start coding! Stay up-to-date with the latest Dimscord release and stuff.

## Quick Example:
```nim
import dimscord, asyncdispatch, times, options

let discord = newDiscordClient("<your bot token goes here>")

# Handle event for on_ready.
proc onReady(s: Shard, r: Ready) {.event(discord).} =
    echo "Ready as " & $r.user

# Handle event for message_create.
proc messageCreate(s: Shard, m: Message) {.event(discord).} =
    if m.author.bot: return
    if m.content == "!ping": # If message content is "!ping".
        let
            before = epochTime() * 1000
            msg = await discord.api.sendMessage(m.channel_id, "ping?")
            after = epochTime() * 1000
        # Now edit the message.
        # Use 'discard' because editMessage returns a new message.
        discard await discord.api.editMessage(
            m.channel_id,
            msg.id, 
            "Pong! took " & $int(after - before) & "ms | " & $s.latency() & "ms."
        )
    elif m.content == "!embed": # Otherwise if message content is "!embed".
        # Sends a message with embed.
        discard await discord.api.sendMessage(
            m.channel_id,
            embeds = @[Embed(
                title: some "Hello there!", 
                description: some "This is description",
                color: some 0x7789ec
            )]
        )

# Connect to Discord and run the bot.
waitFor discord.startSession()
```
Please note that you need to define `-d:ssl` if you are importing httpclient before importing dimscord.
You can use -d:dimscordDebug, if you want to debug.

If you want to use voice then you can use `-d:dimscordVoice`, this requires libsodium, libopus, ffmpeg and optionally yt-dlp (by default)

## Contributing
* If you are interested in contributing to Dimscord, I'd recommend reading the CONTRIBUTING.md file.
