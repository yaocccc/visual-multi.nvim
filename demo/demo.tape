Output demo/demo.gif

Set Shell "bash"
Set Width 1200
Set Height 680
Set FontSize 18
Set TypingSpeed 35ms
Set Padding 16

# Start Neovim without recording the launch command.
Hide
Type "nvim --clean -u demo/minimal.lua demo/sample.js"
Enter
Sleep 1200ms
Show
Sleep 700ms

# Demo 1: native Visual selection -> select all -> synchronized append.
Type "/Color"
Enter
Type "v4l"
Sleep 500ms
Ctrl+D
Sleep 900ms
Type "a"
Type "Token"
Sleep 500ms
Escape
Sleep 350ms
Escape
Sleep 700ms

# Demo 2: add matches one at a time -> synchronized insert.
Type "gg"
Type "/userName"
Enter
Ctrl+N
Sleep 350ms
Ctrl+N
Sleep 350ms
Ctrl+N
Sleep 700ms
Type "i"
Type "active_"
Sleep 500ms
Escape
Sleep 350ms
Escape
Sleep 700ms

# Demo 3: vertical cursors -> append on each line.
Type "gg"
Type "/north"
Enter
Ctrl+Down
Ctrl+Down
Sleep 700ms
Type "A"
Type " // updated"
Sleep 600ms
Escape
Sleep 350ms
Escape
Sleep 700ms

# Demo 4: repeated semantic expansion with v -> synchronized replacement.
Type "gg"
Type "/dark"
Enter
Ctrl+Down
Sleep 450ms
Type "v"
Sleep 250ms
Type "v"
Sleep 250ms
Type "v"
Sleep 250ms
Type "v"
Sleep 650ms
Type "c"
Type "('active')"
Sleep 600ms
Escape
Sleep 350ms
Escape
Sleep 900ms

Hide
Type ":q!"
Enter
