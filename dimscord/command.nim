import strutils, tables
from ./objects import Message

func commandCallTokens*(contents: string): seq[string] =
    ## Splits the given message content into individual tokens.
    ## This is similar to `split(contents, ' ')` except that it supports double-quoted tokens with whitespace in them.
    runnableExamples:
        doAssert commandCallTokens(".test") == @[".test"]
        doAssert commandCallTokens(".test 1 2 3") == @[".test", "1", "2", "3"]
        doAssert commandCallTokens(".test \"a quoted token\"") == @[".test", "a quoted token"]
        doAssert commandCallTokens("\t\r\n  ") == @[]
    
    if contents.isEmptyOrWhitespace: return @[]
    result = newSeqOfCap[string](contents.count(' ') + 1)

    var quoting = false
    var inToken = false
    var token = newStringOfCap(contents.len)

    template endCurrentToken() =
        result.add(token)
        token.setLen(0)
        quoting = false
        inToken = false

    for ch in contents:
        let whitespace = ch in Whitespace
        if inToken and ((ch == '"' and quoting) or (whitespace and not quoting)):
            endCurrentToken()
        elif not inToken:
            if ch == '"':
                # start new quoted token
                quoting = true
                inToken = true
            elif not whitespace:
                # start new unquoted token
                inToken = true
                token &= ch
        elif ch == '"':
            # found quote in middle of unquoted token; not supported
            raise newException(ValueError, "unsupported string prefix: " & token)
        else:
            # continue token
            token &= ch
    if inToken: endCurrentToken()
        
type
    CommandCall* = object
        ## Represents a Discord message (`message`) that invoked a particular command (`command`) with parameters `params`.
        ## `params` does not include the command itself.
        command*: string
        params*: seq[string]
        message*: Message
    CommandHandler* = proc (c: CommandCall)
    CommandHandlerTable* = Table[string, CommandHandler]

proc addHandler*(table: var CommandHandlerTable, command: string, handler: CommandHandler) =
    ## Add the given `CommandHandler` to `table` such that it is invoked with the command `command`.
    table[command] = handler

proc handle*(table: CommandHandlerTable, tokens: seq[string], message: Message): bool =
    ## Dispatch the `message` with the given `tokens` to the appropriate registered `CommandHandler`.
    ## Returns `true` if the message was handled by any handler. Returns `false` if the message was not handled.
    if tokens.len == 0: return false
    let command = tokens[0]
    let params = tokens[1..^1]

    if table.hasKey(command):
        table[command](CommandCall(command: command, params: params, message: message))
        return true
    return false