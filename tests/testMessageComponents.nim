import objects
import helpers
import std/unittest

let basicMenuOptions = @[
     newMenuOption("Red", "red"),
     newMenuOption("Green", "green"),
     newMenuOption("Blue", "blue"),
 ]

suite "Action row checking":
    test "Row can't contain another row":
        var row = newActionRow()
        expect AssertionDefect:
            row &= newActionRow()

    test "Contains 5 buttons":
        var row = newActionRow()
        for i in 1..5:
            row &= newButton($i, "btn" & $i)
        checkActionRow row

    test "Contains more than 5 buttons":
        var row = newActionRow()
        for i in 1..5:
            row &= newButton($i, "btn" & $i)
        expect AssertionDefect:
            row &= newButton("6", "btn6")

    test "Contains menu and button":
        var row = newActionRow()
        row &= newButton("Click Me", "btnClick")
        expect AssertionDefect:
            row &= newSelectMenu("slmColours", basicMenuOptions)

    test "Contains more than 1 select menu":
        var row = newActionRow()
        row &= newSelectMenu("slmColours", basicMenuOptions)
        expect AssertionDefect:
            row &= newSelectMenu("slmColours2", basicMenuOptions)
