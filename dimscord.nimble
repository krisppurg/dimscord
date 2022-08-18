# Package

version       = "1.4.0"
author        = "KrispPurg"
description   = "A Discord Bot & REST Library for Nim."
license       = "MIT"

# Dependencies

requires "nim >= 1.2.0", "zippy >= 0.2.1", "ws", "regex >= 0.15.0", "libsodium <= 0.6.0", "flatty >= 0.1.2", "jsony >= 1.1.3"
requires "opussum >= 0.6.0"

task genDoc, "Generates the documentation for dimscord":
    rmDir("docs") # Clean old doc folder
    exec("nim doc2 --outdir=docs --project --index:on -d:dimscordVoice --git.url:https://github.com/krisppurg/dimscord --git.commit:master dimscord.nim")
    exec("nim buildindex -o:docs/theindex.html docs/") # This builds the index to allow search to work

    writeFile("docs/index.html", """
    <!DOCTYPE html>
    <html>
      <head>
        <meta http-equiv="Refresh" content="0; url=dimscord.html"/>
      </head>
      <body>
        <p>Click <a href="dimscord.html">this link</a> if this does not redirect you.</p>
      </body>
    </html>
    """)
