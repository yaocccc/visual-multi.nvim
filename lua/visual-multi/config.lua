local M = {}

local function default_statusline(info)
  local text = info.text or info.pattern or ""
  text = text:gsub("\n", "↵")
  text = vim.fn.strcharpart(text, 0, 24):gsub("%%", "%%%%")
  local bar = ("%%#VisualMultiStatusMode#▎%s%%#VisualMultiStatus# "
    .. "%%#VisualMultiStatusCount#%d/%d"):format(info.mode, info.current, info.total)
  if text ~= "" then
    bar = bar .. " %#VisualMultiStatusSep#· %#VisualMultiStatusText#" .. text
  end
  return bar .. " %*"
end

M.defaults = {
  wrap = true,
  case_sensitive = true,
  mappings = {
    find_next = "<C-n>",
    find_previous = "N",
    select_all = "<C-d>",
    select_left = "<C-Left>",
    select_right = "<C-Right>",
    add_cursor_down = "<C-Down>",
    add_cursor_up = "<C-Up>",
    add_cursor = "<C-x>",
    add_cursor_word = "<C-w>",
    move_left = false,
    move_right = false,
    next_region = "]",
    previous_region = "[",
    skip_region = false,
    remove_region = "q",
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
  },
  statusline = default_statusline,
  highlights = {
    cursor = "VisualMultiCursor",
    cursor_active = "VisualMultiActive",
    insert = "VisualMultiInsert",
    insert_active = "VisualMultiInsert",
    selection = "VisualMultiSelection",
    selection_active = "VisualMultiSelectionActive",
  },
}

local custom_highlight_groups = {
  cursor = "VisualMultiCustomCursor",
  cursor_active = "VisualMultiCustomActive",
  insert = "VisualMultiCustomInsert",
  insert_active = "VisualMultiCustomInsertActive",
  selection = "VisualMultiCustomSelection",
  selection_active = "VisualMultiCustomSelectionActive",
}

M.options = vim.deepcopy(M.defaults)
M.highlight_specs = {}

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
  M.highlight_specs = {}
  for role, group in pairs(custom_highlight_groups) do
    local value = M.options.highlights[role]
    if type(value) == "table" then
      M.highlight_specs[group] = vim.deepcopy(value)
      M.options.highlights[role] = group
    elseif type(value) ~= "string" then
      error(("highlights.%s must be a highlight group name or table"):format(role))
    end
  end
  return M.options
end

return M
