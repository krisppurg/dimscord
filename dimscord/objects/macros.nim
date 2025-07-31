import std/[macros, macrocache], typedefs

#const clientCache = CacheSeq"dimscord.client"

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

macro loadOpt*(obj: typed, lits: varargs[untyped]): untyped =
    result = newStmtList()
    for lit in lits:
        let fieldName = lit.strVal
        result.add quote do:
            if `lit`.isSome:
                `obj`[`fieldName`] = %*get(`lit`)

macro loadOpts*(res, parent: typed, lits: varargs[untyped]): untyped =
    result = newStmtList()
    for lit in lits:
        let fieldName = lit.strVal
        result.add quote do:
            if `parent`.`lit`.isSome:
                `res`[`fieldName`] = %*get(`parent`.`lit`)

macro loadNullableOptStr*(obj: typed, lits: varargs[untyped]): untyped =
    result = newStmtList()
    for lit in lits:
        let fieldName = lit.strVal
        result.add quote do:
            if `lit`.isSome and get(`lit`) == "":
                `obj`[`fieldName`] = newJNull()

macro loadNullableOptInt*(obj: typed, lits: varargs[untyped]): untyped =
    result = newStmtList()
    for lit in lits:
        let fieldName = lit.strVal
        result.add quote do:
            if `lit`.isSome and get(`lit`) == -1:
                `obj`[`fieldName`] = newJNull()

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

macro mainClient*(x: typed) =
  ## Registers a DiscordClient for helper templates
  ## Usage: `let discord {.mainClient.} = newDiscordClient("TOKEN")`
  let tname = ident("dimscordPrivateClient")
  var vname: NimNode
  if (x.kind == nnkLetSection) or (x.kind == nnkVarSection):
    vname = x[0][0]
  else:
    # TODO: check for `newDiscordClient` presence
    error("Invalid usage, macro expects a let or var statement")
  result = newStmtList()
  result.add(x)
  result.add(quote do:
    template `tname`*(): DiscordClient {.dirty.} =
      `vname`
  )

template getClient*: DiscordClient =
  ## Gets registered client or shard client
  when declared(dimscordPrivateClient):
    var dc {.cursor.} = dimscordPrivateClient() # note: is safe in async code ?
    when defined(dimscordDebug):
      if dc.isNil:
        raise (ref AccessViolationDefect)(
          msg: "Client is nil: Check client initialization"
        )
    dc
  elif declared(s) and (s is Shard):
    when defined(dimscordDebug):
      if s.client.isNil:
        raise (ref AccessViolationDefect)(
          msg: "Client is nil: Check shard initialization"
        )
    s.client
  else:
    {.error: "No client found. Use `mainClient` or ensure 's' Shard exists".}
