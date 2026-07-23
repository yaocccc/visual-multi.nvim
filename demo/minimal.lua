local source = debug.getinfo(1, "S").source:sub(2)
local root = vim.fs.dirname(vim.fs.dirname(vim.fs.normalize(source)))
vim.opt.runtimepath:prepend(root)

vim.opt.number = true
vim.opt.relativenumber = false
vim.opt.termguicolors = true
vim.opt.laststatus = 2
vim.opt.showmode = false
vim.opt.cmdheight = 0
vim.opt.signcolumn = "no"
vim.opt.fillchars = { eob = " " }

local key_buffer, key_window
local key_tokens = {}
local last_key_at = 0

local function render_keys()
  if key_buffer and vim.api.nvim_buf_is_valid(key_buffer) then
    local text = "KEYS  " .. table.concat(vim.tbl_map(function(item)
      return item.text
    end, key_tokens), "  ")
    vim.api.nvim_buf_set_lines(key_buffer, 0, -1, false, { text })
  end
end

local function show_key(key)
  local now = vim.uv.hrtime() / 1e6
  local translated = vim.fn.keytrans(key)
  local printable = vim.fn.strchars(translated) == 1 and translated:match("%g") ~= nil
  local previous = key_tokens[#key_tokens]
  if printable and previous and previous.printable and now - last_key_at < 180 then
    previous.text = previous.text .. translated
  else
    key_tokens[#key_tokens + 1] = { text = translated, printable = printable }
  end
  while #key_tokens > 6 do
    table.remove(key_tokens, 1)
  end
  last_key_at = now
  vim.schedule(render_keys)
end

vim.on_key(function(_, typed)
  if typed and typed ~= "" then
    show_key(typed)
  end
end, vim.api.nvim_create_namespace("visual-multi-demo-keys"))

vim.api.nvim_create_autocmd("VimEnter", {
  once = true,
  callback = function()
    vim.cmd("normal! gg0")
    key_buffer = vim.api.nvim_create_buf(false, true)
    local width = 38
    key_window = vim.api.nvim_open_win(key_buffer, false, {
      relative = "editor",
      row = 1,
      col = math.max(0, vim.o.columns - width - 2),
      width = width,
      height = 1,
      style = "minimal",
      border = "rounded",
      focusable = false,
      zindex = 60,
    })
    vim.api.nvim_set_option_value("winhighlight", "NormalFloat:VisualMultiDemoKeys,FloatBorder:VisualMultiDemoBorder", {
      win = key_window,
    })
    vim.api.nvim_set_hl(0, "VisualMultiDemoKeys", { bg = "#1f2335", fg = "#c0caf5", bold = true })
    vim.api.nvim_set_hl(0, "VisualMultiDemoBorder", { bg = "#1f2335", fg = "#7aa2f7" })
    render_keys()
  end,
})
