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