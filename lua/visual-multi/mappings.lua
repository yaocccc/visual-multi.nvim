local M = {}

local function map(session, mode, lhs, callback, desc)
  if not lhs or lhs == "" then
    return
  end
  local id = mode .. "\0" .. lhs
  if session.saved_maps[id] == nil then
    local saved = vim.fn.maparg(lhs, mode, false, true)
    session.saved_maps[id] = {
      mode = mode,
      lhs = lhs,
      saved = saved.buffer == 1 and saved or false,
    }
  end
  vim.keymap.set(mode, lhs, callback, {
    buffer = session.buf,
    silent = true,
    nowait = true,
    desc = "Visual Multi: " .. desc,
  })
end

function M.activate(session)
  local keys = require("visual-multi.config").options.mappings
  local actions = {
    find_next = { function() session:find_next(1) end, "find next" },
    find_previous = { function() session:find_next(-1) end, "find previous" },
    select_all = { function() session:select_all() end, "select all" },
    select_left = { function() session:select_horizontal(-1) end, "select left" },
    select_right = { function() session:select_horizontal(1) end, "select right" },
    add_cursor_down = { function() session:add_vertical(1) end, "add cursor down" },
    add_cursor_up = { function() session:add_vertical(-1) end, "add cursor up" },
    add_cursor = { function() session:add_cursor_at_current() end, "add cursor" },
    add_cursor_word = { function() session:add_word_at_current() end, "add word" },
    move_left = { function() session:move("h") end, "move left" },
    move_right = { function() session:move("l") end, "move right" },
    toggle_extend = { function() session:toggle_extend() end, "toggle normal/extend" },
    next_region = { function() session:navigate(1) end, "next cursor" },
    previous_region = { function() session:navigate(-1) end, "previous cursor" },
    skip_region = { function() session:skip() end, "skip current" },
    remove_region = { function() session:remove_current() end, "remove current" },
    insert = { function() session:begin_insert("i") end, "insert" },
    append = { function() session:begin_insert("a") end, "append" },
    insert_bol = { function() session:begin_insert("I") end, "insert at first nonblank" },
    append_eol = { function() session:begin_insert("A") end, "append at line end" },
    change = { function() session:delete(true) end, "change" },
    delete = { function() session:delete(false) end, "delete" },
    delete_char = { function() session:delete(false) end, "delete character" },
    yank = { function() session:yank() end, "yank" },
    paste = { function() session:paste() end, "paste" },
    increase = { function() session:change_number(1) end, "increase number" },
    decrease = { function() session:change_number(-1) end, "decrease number" },
    undo = {
      function()
        vim.cmd.undo()
        session:render()
        session:focus()
      end,
      "undo",
    },
    redo = {
      function()
        vim.cmd.redo()
        session:render()
        session:focus()
      end,
      "redo",
    },
    clear = { function() session:clear() end, "clear" },
  }

  for name, action in pairs(actions) do
    map(session, "n", keys[name], action[1], action[2])
  end

  map(session, "n", "D", function() session:delete_to_eol() end, "delete to end of line")
  map(session, "n", "o", function() session:begin_insert("o") end, "open line below")
  map(session, "n", "O", function() session:begin_insert("O") end, "open line above")

  for _, motion in ipairs({ "h", "j", "k", "l", "w", "b", "e", "0", "^", "$" }) do
    local key = motion
    map(session, "n", key, function() session:move(key) end, "move " .. key)
  end

  map(session, "i", keys.insert_paste, function()
    if session.inserting then
      session:insert_paste()
    end
  end, "paste at cursors")
end

function M.deactivate(session)
  if not vim.api.nvim_buf_is_valid(session.buf) then
    return
  end
  for _, entry in pairs(session.saved_maps) do
    pcall(vim.keymap.del, entry.mode, entry.lhs, { buffer = session.buf })
    if entry.saved then
      pcall(vim.fn.mapset, entry.mode, false, entry.saved)
    end
  end
  session.saved_maps = {}
end

return M
