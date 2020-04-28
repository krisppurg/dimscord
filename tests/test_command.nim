import unittest
import ../dimscord/command

suite "command call tokenize":
    test "single command call":
        check commandCallTokens("!test") == @["!test"]

    test "nothing":
        check commandCallTokens("").len == 0

    test "nothing but whitespace":
        check commandCallTokens("\t\t\n\n\r  ").len == 0

    test "multiple non-quoted tokens":
        check commandCallTokens("!test a b c d") == @["!test", "a", "b", "c", "d"]

    test "multiple non-quoted numbers":
        check commandCallTokens("!test 1 2 3 4") == @["!test", "1", "2", "3", "4"]

    test "quoted token":
        check commandCallTokens("""!test "token spaces"""") == @["!test", "token spaces"]

    test "prefix string throws exception":
        expect ValueError:
            discard commandCallTokens("""!test prefix"this won't work" """)
    
    test "complicated token":
        check commandCallTokens("""
        !test 5&2*4^1_4\5\a "st2 1m 55a')" "man"""") == @["!test", "5&2*4^1_4\\5\\a", "st2 1m 55a')", "man"]


from ../dimscord/objects import Message
let msg = Message(id: "uniqueID")

suite "command handler table":
    setup:
        var table = CommandHandlerTable()
        var called = false

    test "add single handler":
        table.addHandler("!test") do (cmd: CommandCall):
            called = true
        
        check table.handle(@["!test"], msg)
        check called
    
    test "no handlers":
        check not table.handle(@["!test"], msg)

    test "pass no tokens":
        table.addHandler("!test") do (cmd: CommandCall):
            called = true

        check not table.handle(@[], msg)
        check not called
    
    test "pass different token":
        table.addHandler("!make") do (c: CommandCall):
            called = true

        check not table.handle(@["!notmake"], msg)
        check not called
    
    test "pass parameters":
        table.addHandler("!add") do (c: CommandCall):
            check c.command == "!add"
            check c.params == @["item1", "item2"]
            called = true

        check table.handle(@["!add", "item1", "item2"], msg)
        check called

    test "pass message to handler":
        table.addHandler("!test") do (c: CommandCall):
            called = true
            check c.message == msg
        
        check table.handle(@["!test"], msg)
        check called
        
