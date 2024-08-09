import std/[macros, macrocache], typedefs

const clientCache = CacheSeq"dimscord.client"

macro keyCheckOptInt*(obj: typed, obj2: typed,
                        lits: varargs[untyped]): untyped =
    result = newStmtList()
    for lit in lits:
        let fieldName = lit.strVal
        result.add quote do:
            if `fieldName` in `obj` and `obj`[`fieldName`].kind != JNull:
                `obj2`.`lit` = some `obj`[`fieldName`].getInt

macro keyCheckOptBool*(obj: typed, obj2: typed,
                        lits: varargs[untyped]): untyped =
    result = newStmtList()
    for lit in lits:
        let fieldName = lit.strVal
        result.add quote do:
            if `fieldName` in `obj` and `obj`[`fieldName`].kind != JNull:
                `obj2`.`lit` = some `obj`[`fieldName`].getBool

macro keyCheckBool*(obj: typed, obj2: typed,
                        lits: varargs[untyped]): untyped =
    result = newStmtList()
    for lit in lits:
        let fieldName = lit.strVal
        result.add quote do:
            if `fieldName` in `obj` and `obj`[`fieldName`].kind != JNull:
                `obj2`.`lit` = `obj`[`fieldName`].getBool

macro keyCheckOptStr*(obj: typed, obj2: typed,
                        lits: varargs[untyped]): untyped =
    result = newStmtList()
    for lit in lits:
        let fieldName = lit.strVal
        result.add quote do:
            if `fieldName` in `obj` and `obj`[`fieldName`].kind != JNull:
                `obj2`.`lit` = some `obj`[`fieldName`].getStr

macro keyCheckStr*(obj: typed, obj2: typed,
                        lits: varargs[untyped]): untyped =
    result = newStmtList()
    for lit in lits:
        let fieldName = lit.strVal
        result.add quote do:
            if `fieldName` in `obj` and `obj`[`fieldName`].kind != JNull:
                `obj2`.`lit` = `obj`[`fieldName`].getStr

macro optionIf*(check: typed): untyped =
    ## Runs `check` to see if a variable is considered empty
    ## - if check is true, then it returns None[T]
    ## - if check is false, then it returns some(variable)
    ## not very robust but supports basics like calls, field access
    expectKind check, nnkInfix
    let symbol = case check[1].kind:
        of nnkDotExpr: check[1][1]
        else: check[1]
    let
        variable = check[1]
        varType  = ident $symbol.getType()

    result = quote do:
        if `check`: none `varType` else: some (`variable`)

macro mainClient*(x: typed): untyped =
    ## Register a DiscordClient
    ## - Use this variable to use the helper functions. Can be set only once.
    ##```nim
    ##  # Register the client when declaring it
    ##  let discord* {.mainClient.} = newDiscordClient("YOUR_TOKEN")
    ##  # Now you can use the helper functions
    ## ```
    # NOTE: Don't deprecate `mainClient` but reserve it for future use.
    if x.kind notin {nnkLetSection, nnkVarSection}:
        error("let/var must be used when declaring the variable")
    else:
        result = x

template getClient*: DiscordClient = 
  ## Tries to access DiscordClient by using a Shard. Internal use only.
  # WIP: move to another module
  when (declared(s)) and (typeof(s) is Shard):
    var dc {.cursor.} = s.client
    when defined(dimscordDebug): 
      if dc.isNil: raise (ref AccessViolationDefect)(msg: "Client is Nil") # add a more descriptive error ?
    dc
  else:
    {.error: "Error: Cannot find any Shard in scope.\nHelpers must have the 's' variable in scope in order to work".}





