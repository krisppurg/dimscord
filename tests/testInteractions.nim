include objects
import std/[
    unittest,
    json
]

template `%*%`(json: untyped): ApplicationCommandInteractionDataOption =
    block:
        let input = %* json
        input.newApplicationCommandInteractionDataOption()

suite "Interaction data types":
    test "String":
        let option = %*% {
            "value": "foobar",
            "type": 3,
            "name": "word"
        }
        check:
            option.kind == acotStr
            option.str == "foobar"

    test "Int":
        let option = %*% {
            "value": 42,
            "type": 4,
            "name": "answer"
        }
        check:
            option.kind == acotInt
            option.ival == 42

    test "Bool":
        let option = %*% {
            "value": true,
            "type": 5,
            "name": "delete?"
        }
        check:
            option.kind == acotBool
            option.bval
    test "User":
        let option = %*% {
            "value": "259999449995018240",
            "type": 6,
            "name": "person"
        }
        check:
            option.kind == acotUser
            option.userID == "259999449995018240"
    test "Channel":
        let option = %*% {
            "value": "571779270498713603",
            "type": 7,
            "name": "thechannel"
        }
        check:
            option.kind == acotChannel
            option.channelID == "571779270498713603"

    test "Role":
        let option = %*% {
            "value": "485396936384315402",
            "type": 8,
            "name": "newrole"
        }
        check:
            option.kind == acotRole
            option.roleID == "485396936384315402"


suite "Interaction data":
    test "Basic option":
        ## Test that it can parse an interaction
        ## data option
        let option = %*% {
                "value": "hello",
                "type": 3,
                "name": "name"
              }
        check:
            option.kind == acotStr
            option.str == "hello"
            option.name == "name"

    test "Basic command":
        ## Test that it can parse a command
        ## with no parameters
        let input = %* {
                   "name": "somecmd",
                   "id": "852446885431738388"
                 }
        let data = input.newApplicationCommandInteractionData()
        check:
            data.name == "somecmd"
            data.id == "852446885431738388"
            data.options.len == 0

    test "Command with parameter":
        ## Test that it can parse a command
        ## with a parameter
        let input = %* {
               "options": [
                 {
                   "value": "hello",
                   "type": 3,
                   "name": "name"
                 }
               ],
               "name": "somecmd",
               "id": "852446885431738388"
             }
        let data = input.newApplicationCommandInteractionData()
        # Test the command is parsed right
        check:
            data.name == "somecmd"
            data.id == "852446885431738388"
            data.options.hasKey "name"

        # Test the parameter is parsed right
        let parameter = data.options["name"]
        check:
            parameter.name == "name"
            parameter.kind == acotStr
            parameter.str == "hello"

    test "Sub Commands/Groups":
        # Test that it can correctly parse sub commands
        let input = %* {
           "options": [
             {
               "type": 1,
               "options": [
                 {
                   "value": 10,
                   "type": 4,
                   "name": "a"
                 },
                 {
                   "value": 12,
                   "type": 4,
                   "name": "b"
                 }
               ],
               "name": "add"
             }
           ],
           "name": "calc",
           "id": "861180910094254093"
         }
        let data = input.newApplicationCommandInteractionData()
        check data.name == "calc"
        # Check the sub command is parsed
        check data.options.hasKey "add"
        let subCmd = data.options["add"]
        check:
            subCmd.kind == acotSubCommand
            subCmd.name == "add"
            subCmd.options.len == 2
        # Check the options are parsed correctly
        check:
            subCmd.options["a"].ival == 10
            subCmd.options["b"].ival == 12
