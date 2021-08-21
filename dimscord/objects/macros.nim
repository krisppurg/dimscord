import std/macros

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
