local M = {}

local function default_statusline(info)
  local text = info.text or info.pattern or ""
  text = text:gsub("\n", "↵")
  text = vim.fn.strcharpart(text, 0, 24):gsub("%%", "%%%%")
  local bar = ("%%#VisualMultiStatusMode# %s %%#VisualMultiStatusSep#│ "
    .. "%%#VisualMultiStatusCount#%d/%d"):format(info.mode, info.current, info.total)
  if text ~= "" then
    bar = bar .. " %#VisualMultiStatusSep#│ %#VisualMultiStatusText#" .. text
  end
  return bar .. " %#VisualMultiStatus#%="
end

M.defaults = {
  wrap = true,
  case_sensitive = true,
  mappings = {
    find_next = "<C-n>",
    find_previous = "N",
    select_all = "<leader>ma",
    select_left = "<S-Left>",
    select_right = "<S-Right>",
    add_cursor_down = "<C-Down>",
    add_cursor_up = "<C-Up>",
    add_cursor = "<leader>mc",
    add_cursor_word = false,
    move_left = false,
    move_right = false,
    toggle_extend = "<Tab>",
    next_region = "]",
    previous_region = "[",
    skip_region = "q",
    remove_region = "Q",
    insert = "i",
    append = "a",
    insert_bol = "I",
    append_eol = "A",
    insert_paste = "<C-v>",
    change = "c",
    delete = "d",
    delete_char = "x",
    yank = "y",
    paste = "p",
    increase = "+",
    decrease = "_",
    undo = "u",
    redo = "<C-r>",
    clear = "<Esc>",
  },
  statusline = default_statusline,
  highlights = {
    cursor = "VisualMultiCursor",
    cursor_active = "VisualMultiCursorActive",
    insert = "VisualMultiInsert",
    insert_active = "VisualMultiInsertActive",
    selection = "VisualMultiSelection",
    selection_active = "VisualMultiSelectionActive",
  },
}

M.options = vim.deepcopy(M.defaults)

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
  return M.options
end

return M
