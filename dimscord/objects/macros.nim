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
