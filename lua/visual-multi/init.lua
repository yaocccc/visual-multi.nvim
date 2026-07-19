local M = {}

local config = require("visual-multi.config")
local Session = require("visual-multi.session")

local loaded = false
local global_mappings = {}

local function current_session(create)
  local buf = vim.api.nvim_get_current_buf()
  return create and Session.ensure(buf) or Session.get(buf)
end

local function define_highlights()
  vim.api.nvim_set_hl(0, "VisualMultiCursor", {
    default = true,
    bg = "#87afff",
    fg = "#4e4e4e",
  })
  vim.api.nvim_set_hl(0, "VisualMultiActive", {
    default = true,
    bg = "#dfdf87",
    fg = "#4e4e4e",
  })
  vim.api.nvim_set_hl(0, "VisualMultiInsert", {
    default = true,
    bg = "#4c4e50",
  })
  vim.api.nvim_set_hl(0, "VisualMultiSelection", {
    default = true,
    bg = "#005faf",
  })
  vim.api.nvim_set_hl(0, "VisualMultiSelectionActive", {
    default = true,
    bg = "#87afff",
    fg = "#4e4e4e",
  })
  vim.api.nvim_set_hl(0, "VisualMultiStatus", {
    default = true,
    bg = "#d9dde3",
    fg = "#4f5863",
  })
  vim.api.nvim_set_hl(0, "VisualMultiStatusMode", {
    default = true,
    bg = "#d9dde3",
    fg = "#20252b",
    bold = true,
  })
  vim.api.nvim_set_hl(0, "VisualMultiStatusCount", {
    default = true,
    bg = "#d9dde3",
    fg = "#4f5863",
  })
  vim.api.nvim_set_hl(0, "VisualMultiStatusText", {
    default = true,
    bg = "#d9dde3",
    fg = "#6f7883",
  })
  vim.api.nvim_set_hl(0, "VisualMultiStatusSep", {
    default = true,
    bg = "#d9dde3",
    fg = "#aab1ba",
  })

  for group, spec in pairs(config.highlight_specs) do
    vim.api.nvim_set_hl(0, group, spec)
  end
end

local function define_commands()
  vim.api.nvim_create_user_command("VisualMultiNext", function()
    M.find_next()
  end, { desc = "Select the word or its next occurrence" })
  vim.api.nvim_create_user_command("VisualMultiAll", function()
    M.select_all()
  end, { desc = "Select all occurrences" })
  vim.api.nvim_create_user_command("VisualMultiAdd", function()
    M.add_cursor()
  end, { desc = "Add a cursor at the current position" })
  vim.api.nvim_create_user_command("VisualMultiClear", function()
    M.clear()
  end, { desc = "Clear all cursors" })
  vim.api.nvim_create_user_command("VisualMultiInfo", function()
    local session = current_session(false)
    vim.notify(vim.inspect(session and session:info() or {}), vim.log.levels.INFO)
  end, { desc = "Show current multi-cursor state" })
end

local function global_map(lhs, callback, desc)
  if lhs and lhs ~= "" then
    vim.keymap.set("n", lhs, callback, { silent = true, desc = "Visual Multi: " .. desc })
    global_mappings[#global_mappings + 1] = lhs
  end
end

local function define_global_mappings()
  for _, lhs in ipairs(global_mappings) do
    pcall(vim.keymap.del, "n", lhs)
  end
  global_mappings = {}

  local maps = config.options.mappings
  global_map(maps.find_next, M.find_next, "find next")
  global_map(maps.select_all, M.select_all, "select all")
  global_map(maps.select_left, function() M.select_horizontal(-1) end, "select left")
  global_map(maps.select_right, function() M.select_horizontal(1) end, "select right")
  global_map(maps.add_cursor_down, function() M.add_cursor_vertical(1) end, "add cursor down")
  global_map(maps.add_cursor_up, function() M.add_cursor_vertical(-1) end, "add cursor up")
  global_map(maps.add_cursor, M.add_cursor, "add cursor")
  global_map(maps.add_cursor_word, M.add_cursor_word, "add word")
end

function M.setup(opts)
  config.setup(opts)
  define_highlights()
  if not loaded then
    define_commands()
    local group = vim.api.nvim_create_augroup("VisualMultiHighlights", { clear = true })
    vim.api.nvim_create_autocmd("ColorScheme", {
      group = group,
      callback = define_highlights,
    })
    loaded = true
  end
  define_global_mappings()
end

function M.find_next()
  current_session(true):find_next(1)
end

function M.find_previous()
  local session = current_session(false)
  if session then
    session:find_next(-1)
  end
end

function M.select_all()
  current_session(true):select_all()
end

function M.add_cursor_vertical(direction)
  current_session(true):add_vertical(direction)
end

function M.add_cursor()
  current_session(true):add_cursor_at_current()
end

function M.add_cursor_word()
  current_session(true):add_word_at_current()
end

function M.select_horizontal(direction)
  current_session(true):select_horizontal(direction)
end

function M.clear()
  local session = current_session(false)
  if session then
    session:clear()
  end
end

function M.get_session(buf)
  return Session.get(buf)
end

return M
