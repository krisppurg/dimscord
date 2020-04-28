import strutils, tables
from ./objects import Message

func commandCallTokens*(contents: string): seq[string] =
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
        command*: string
        params*: seq[string]
        message*: Message
    CommandHandler* = proc (c: CommandCall)
    CommandHandlerTable* = Table[string, CommandHandler]

proc addHandler*(table: var CommandHandlerTable, command: string, handler: CommandHandler) =
    table[command] = handler

proc handle*(table: CommandHandlerTable, tokens: seq[string], message: Message): bool =
    if tokens.len == 0: return false
    let command = tokens[0]
    let params = tokens[1..^1]

    if table.hasKey(command):
        table[command](CommandCall(command: command, params: params, message: message))
        return true
    return false