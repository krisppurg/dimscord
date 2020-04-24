
# <img src="assets/dimscord.png" width="42px" height="32px"/>  Dimscord
A Discord Bot & REST Library for Nim.

Why Dimscord?
 * It is a bit more straightforward.
 * Nim is a good programming language and I believe that Nim should stand a chance on having a good enough discord library.
 * It has REST mode feature.
 * The other nim discord library has bunch of issues and also the way of handling.
 
 ## FAQ:
 What is Nim?
   * Nim is a young statically-typed programming language that compiles to C/C++/JavaScript. It's similar to python and it's syntax is more clear. [You can read it more in the official website for Nim](https://nim-lang.org)

 Where is the documentation for the library?
  * The docs will be out soon or later.

## Notes:
 * This library is 90% finished (estimate).
 * When running your discord bot you would need to define `-d:ssl` e.g. `nim c -r -d:ssl yourfilename.nim`

 * For compressing data and stuff you would need zlib1.dll to be installed, you can put it at your `.nimble/bin` directory or just simply put it at your folder.

 * Voice support will be added on later.

## How to install Dimscord:
### Step 1: Install Nim

 You can use [choosenim](https://github.com/dom96/choosenim) or you could download it from [Nim's website](https://nim-lang.org/install.html)

 ### Step 2: Install Dimscord
Do `nimble install dimscord` or `git clone https://github.com/krisppurg/dimscord`

You will need at least Nim 1.0.0 to install dimscord
 
 ### Step 3: Enjoy.
Stay up-to-date with the latest Dimscord release and stuff.

## Quick Example:
```nim
import dimscord, asyncdispatch

let cl = newDiscordClient("<token>")

cl.events.on_ready = proc (s: Shard, r: Ready) = # Add Event Handler for on_ready.
    echo "Connected to Discord as " & $r.user

cl.events.message_create = proc (s: Shard, m: Message) = #  Add Event Handler for message_create.
    if m.author.bot: return
    if m.content == "!ping": # if message content is "!ping"
        let before = getTime().utc.toTime.toUnix
        let msg = waitFor cl.api.sendMessage(m.channel_id, "ping?")
        let after = getTime().utc.toTime.toUnix 
        asyncCheck cl.api.editMessage(m.channel_id, msg.id, "Pong! took" & $int(after - before) & "ms | " & s.getPing()) # Edit the message as pong! asyncCheck means that it  will only raise an exception if it fails.
    elif m.content == "!embed": # otherwise if content is embed
        asyncCheck cl.api.sendMessage(m.channel_id, embed = ?Embed( # Sends a messge with embed. The '?' symbol is a shorthand for 'some' in options.
            title: ?"Hello there!", 
            description: ?"This is a cool embed",
            color: ?5)

waitFor cl.startSession(compress=true)
```
