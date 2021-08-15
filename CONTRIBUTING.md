## Contributing to Dimscord

### Notes:
* Issues are used for bug reporting or feature requests, **NOT** questions, if you have questions,
  join the discord api channel as found in the README.md file.
* Pull-requests may take a bit longer to merge, depending if major or not.
* If you have an idea you could discuss it on the discord api channel.

#### Please Do:
* Make sure that when you make your pull request to your changes, test them first.
* Provide some details to your issue for example your nim version and what have you tried to do. Branches included too.
* Make the code consistant or just make like look the others, like for example: `func` needs to be `proc` (`func` has no side-effects and is a pure function.)

#### Please Do NOT:
* Make spam comments or less detailed issues.
* Make command handler PRs or issues. [There is already a command handler](https://github.com/ire4ever1190/dimscmd)
* Make lines over 80-81 characters, unless it's comments which limits to around 120 characters.
* Having echos in code unless if it checks dimscordDebug enabled, but debugs should be helpful and not rather too spammy (e.g. echoing a raw guild object would be considered spammy).