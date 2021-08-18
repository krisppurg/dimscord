import std/[
    macros,
    strutils,
    tables
]

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

macro construct*(data: JsonNode, kind: typedesc, args: static[openarray[string]]): untyped =
    ## Creates an object constructor with data from json.
    ## Allows specifying the fields to include so that edge cases can be handled manually.
    result = nnkObjConstr.newTree(kind)
    # Add your own calls here (do in full lower case)
    # The calls must only have a single parameter of kind JsonNode
    let callTable = toTable {
        "string": "str",
        "int":    "getInt",
        "bool":   "bval"
    }
    for paramNode in kind.getImpl()[2][2]:
        let paramSymbol = paramNode[^2]
        for parameterNode in paramNode[0 ..< ^2]:
            var parameter = if parameterNode.kind == nnkPostfix:
                $(parameterNode.basename)
            else:
                $parameterNode
            if parameter notin args: continue # Don't try and parse if it isn't specified
            let parameterName = if parameter == "kind": "type" else: parameter

            let jsonAccess = nnkBracketExpr.newTree( # Add in nodes to access the json key
                data,
                newLit(parameterName)
            )
            let paramImplementation = paramSymbol.getImpl()
            var call: NimNode
            # Check that the type is an enum, and that it isn't bool (which is an enum internally)
            if paramImplementation.kind != nnkNilLit and
                paramImplementation[2].kind == nnkEnumTy and
                paramImplementation[0].kind != nnkPragmaExpr:
                call = nnkCall.newTree(
                    ($paramSymbol).ident,
                    nnkDotExpr.newTree(jsonAccess, "getInt".ident)
                )
            else:
                call = nnkDotExpr.newTree(
                    jsonAccess,
                    callTable[($paramSymbol).normalize].ident # Get the call
                )

            result &= nnkExprColonExpr.newTree(
                parameter.ident,
                call
            )
