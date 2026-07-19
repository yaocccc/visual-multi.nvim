local config = require("visual-multi.config")

local M = {}
local states = {}
local expression = "%!v:lua.require'visual-multi.statusline'.render()"

local function current_win()
  local win = tonumber(vim.g.statusline_winid)
  if win and vim.api.nvim_win_is_valid(win) then
    return win
  end
  return vim.api.nvim_get_current_win()
end

function M.render()
  local state = states[current_win()]
  if not state or not state.session then
    return ""
  end

  local formatter = config.options.statusline
  if type(formatter) ~= "function" then
    return ""
  end

  local info = state.session:info()
  info.mode = (info.mode or "normal"):upper()
  local ok, value = pcall(formatter, info)
  return ok and type(value) == "string" and value or info.mode
end

function M.attach(session)
  if type(config.options.statusline) ~= "function" then
    return
  end

  local win = vim.api.nvim_get_current_win()
  if not vim.api.nvim_win_is_valid(win) then
    return
  end
  states[win] = {
    session = session,
    saved = vim.api.nvim_get_option_value("statusline", { win = win }),
  }
  session.statusline_win = win
  vim.api.nvim_set_option_value("statusline", expression, { win = win })
  vim.cmd.redrawstatus()
end

function M.update(session)
  local win = session.statusline_win
  if win and states[win] and vim.api.nvim_win_is_valid(win) then
    if vim.api.nvim_get_option_value("statusline", { win = win }) ~= expression then
      vim.api.nvim_set_option_value("statusline", expression, { win = win })
    end
    vim.cmd.redrawstatus()
  end
end

function M.detach(session)
  local win = session.statusline_win
  local state = win and states[win]
  if not state then
    return
  end

  if vim.api.nvim_win_is_valid(win) then
    if vim.api.nvim_get_option_value("statusline", { win = win }) == expression then
      vim.api.nvim_set_option_value("statusline", state.saved, { win = win })
    end
  end
  states[win] = nil
  session.statusline_win = nil
  vim.cmd.redrawstatus()
end

return M
