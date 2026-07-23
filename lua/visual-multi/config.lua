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
    cursor = { bg = "#87afff", fg = "#4e4e4e" },
    cursor_active = { bg = "#dfdf87", fg = "#4e4e4e" },
    insert = { bg = "#4c4e50" },
    insert_active = { bg = "#4c4e50" },
    selection = { bg = "#005faf" },
    selection_active = { bg = "#87afff", fg = "#4e4e4e" },
  },
}

local highlight_groups = {
  cursor = "VisualMultiCursor",
  cursor_active = "VisualMultiActive",
  insert = "VisualMultiInsert",
  insert_active = "VisualMultiInsertActive",
  selection = "VisualMultiSelection",
  selection_active = "VisualMultiSelectionActive",
}

M.options = vim.deepcopy(M.defaults)
M.highlight_specs = {}
M.configured = false

function M.setup(opts)
  if opts == nil and M.configured then
    return M.options
  end

  local input = vim.deepcopy(opts or {})
  local user_highlights = input.highlights
  input.highlights = nil
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), input)
  M.options.highlights = {}
  M.highlight_specs = {}

  if user_highlights ~= nil and type(user_highlights) ~= "table" then
    error("highlights must be a table")
  end
  for role in pairs(user_highlights or {}) do
    if not highlight_groups[role] then
      error(("unknown highlight role: %s"):format(role))
    end
  end

  for role, group in pairs(highlight_groups) do
    local custom = user_highlights and user_highlights[role] or nil
    local value
    if custom == nil then
      value = vim.deepcopy(M.defaults.highlights[role])
    elseif type(custom) == "table" then
      value = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults.highlights[role]), custom)
    else
      value = custom
    end

    if type(value) == "table" then
      M.highlight_specs[group] = value
      M.options.highlights[role] = group
    elseif type(value) == "string" then
      M.options.highlights[role] = value
    else
      error(("highlights.%s must be a highlight group name or table"):format(role))
    end
  end
  M.configured = M.configured or opts ~= nil
  return M.options
end

return M
