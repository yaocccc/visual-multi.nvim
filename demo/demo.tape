Output demo/demo.gif

Set Shell "bash"
Set Width 1200
Set Height 680
Set FontSize 18
Set TypingSpeed 40ms
Set Padding 16

# Start Neovim without recording the launch command.
Hide
Type "nvim --clean -u demo/minimal.lua demo/sample.js"
Enter
Sleep 1200ms
Show
Sleep 850ms

# Demo 1: native Visual selection -> select all -> synchronized append.
Type "/Color"
Enter
Type "v4l"
Sleep 800ms
Ctrl+D
Sleep 1050ms
Type "a"
Type "Token"
Sleep 800ms
Escape
Sleep 550ms
Escape
Sleep 850ms

# Demo 2: add matches one at a time -> synchronized insert.
Type "gg"
Type "/userName"
Enter
Ctrl+N
Sleep 550ms
Ctrl+N
Sleep 550ms
Ctrl+N
Sleep 850ms
Type "i"
Type "active_"
Sleep 800ms
Escape
Sleep 550ms
Escape
Sleep 850ms

# Demo 3: vertical cursors -> append on each line.
Type "gg"
Type "/north"
Enter
Ctrl+Down
Ctrl+Down
Sleep 850ms
Type "A"
Type " // updated"
Sleep 750ms
Escape
Sleep 550ms
Escape
Sleep 850ms

# Demo 4: repeated semantic expansion with v -> synchronized replacement.
Type "gg"
Type "/dark"
Enter
Ctrl+Down
Sleep 550ms
Type "v"
Sleep 550ms
Type "v"
Sleep 550ms
Type "v"
Sleep 550ms
Type "v"
Sleep 800ms
Type "c"
Type "('active')"
Sleep 750ms
Escape
Sleep 550ms
Escape
Sleep 850ms

# Demo 5: yank different words -> per-cursor paste -> synchronized edit.
Type "gg"
Type "/alpha"
Enter
Ctrl+Down
Type "vv"
Sleep 800ms
Type "y"
Sleep 550ms
Type "jj$"
Type "a"
Type " "
Ctrl+V
Sleep 800ms
Type " + '_edited'"
Sleep 750ms
Escape
Sleep 550ms
Escape
Sleep 1050ms

Hide
Type ":q!"
Enter
