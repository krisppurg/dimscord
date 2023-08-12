import std/[macros, genasts, macrocache], typedefs

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

macro useHelper*(x: DiscordClient): untyped =
    ## Register a DiscordClient
    ## - Use this variable to use the helper functions. Can be set only once.
    runnableExamples "-r:off":
        # Register the client when declaring it
        let discord* {.useHelper.} = newDiscordClient("YOUR_TOKEN")
        # Now you can use the helper functions
        
    if clientCache.len > 0:
        error("You must choose one of your client variables to set as your main")
    elif x.kind notin {nnkLetSection, nnkVarSection}:
        error("let/var must be used when declaring the variable")
    else:
        clientCache &= x[0][0]
        result = x

macro getClient*(): DiscordClient = 
    ## Fetch a registered DiscordClient that would be used as the main variable for helper functions.
    ## - You must use `useHelper` before using this macro!
    if clientCache.len == 0:
        error("Client not registered")
    clientCache[0]

