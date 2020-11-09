# Package

version       = "1.2.1"
author        = "KrispPurg"
description   = "A Discord Bot & REST Library for Nim."
license       = "MIT"

# Dependencies

requires "nim >= 1.2.0", "zip >= 0.2.1", "ws <= 0.4.0", "regex >= 0.15.0"

task genDoc, "Generates the documentation for dimscord":
    rmDir("docs") # Clean old doc folder
    exec("nim doc2 --outdir=docs --project --index:on --git.url:https://github.com/krisppurg/dimscord --git.commit:master dimscord.nim")
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
