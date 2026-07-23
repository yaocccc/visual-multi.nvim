local config = require("visual-multi.config")
local util = require("visual-multi.util")

local Session = {}
Session.__index = Session

local track_ns = vim.api.nvim_create_namespace("visual-multi-track")
local decor_ns = vim.api.nvim_create_namespace("visual-multi-decor")
local sessions = {}
local next_region_id = 0

local function same_pos(a, b)
  return a.row == b.row and a.col == b.col
end

local function normalized(a, b)
  if util.compare_pos(a, b) <= 0 then
    return a, b
  end
  return b, a
end

local function set_mark(buf, id, pos, gravity)
  return vim.api.nvim_buf_set_extmark(buf, track_ns, pos.row, pos.col, {
    id = id,
    right_gravity = gravity,
    undo_restore = false,
    invalidate = false,
  })
end

function Session.get(buf)
  return sessions[buf or vim.api.nvim_get_current_buf()]
end

function Session.new(buf)
  local self = setmetatable({
    buf = buf,
    regions = {},
    active = 0,
    pattern = nil,
    register = nil,
    mode = "normal",
    inserting = false,
    syncing = false,
    augroup = nil,
    saved_maps = {},
  }, Session)
  sessions[buf] = self
  self:_install_autocmds()
  require("visual-multi.mappings").activate(self)
  require("visual-multi.statusline").attach(self)
  return self
end

function Session.ensure(buf)
  return Session.get(buf) or Session.new(buf)
end

function Session:_install_autocmds()
  self.augroup = vim.api.nvim_create_augroup("VisualMulti:" .. self.buf, { clear = true })
  vim.api.nvim_create_autocmd({ "BufLeave", "BufWipeout" }, {
    group = self.augroup,
    buffer = self.buf,
    callback = function()
      if sessions[self.buf] == self then
        self:clear()
      end
    end,
  })
  vim.api.nvim_create_autocmd("InsertLeave", {
    group = self.augroup,
    buffer = self.buf,
    callback = function()
      vim.schedule(function()
        if sessions[self.buf] == self then
          self:end_insert()
        end
      end)
    end,
  })
  vim.api.nvim_create_autocmd("CursorMoved", {
    group = self.augroup,
    buffer = self.buf,
    callback = function()
      if sessions[self.buf] == self and self:_activate_region_at_cursor() then
        self:render()
      end
    end,
  })
end

function Session:_mark_pos(id)
  local mark = vim.api.nvim_buf_get_extmark_by_id(self.buf, track_ns, id, {})
  if #mark == 0 then
    return nil
  end
  return { row = mark[1], col = mark[2] }
end

function Session:raw_positions(region)
  local anchor = self:_mark_pos(region.start_id)
  local head = self:_mark_pos(region.end_id)
  if not anchor or not head then
    return nil
  end
  return anchor, head
end

function Session:positions(region)
  local anchor, head = self:raw_positions(region)
  if not anchor then
    return nil
  end
  if self.mode ~= "extend" then
    return normalized(anchor, head)
  end

  local start_pos, last_pos = normalized(anchor, head)
  local line = vim.api.nvim_buf_get_lines(self.buf, last_pos.row, last_pos.row + 1, true)[1] or ""
  return start_pos, {
    row = last_pos.row,
    col = util.char_end(line, last_pos.col),
  }
end

function Session:_set_positions(region, anchor, head, insert_gravity)
  anchor = util.clamp_position(self.buf, anchor.row, anchor.col)
  head = util.clamp_position(self.buf, head.row, head.col)
  region.start_id = set_mark(self.buf, region.start_id, anchor, insert_gravity or false)
  region.end_id = set_mark(self.buf, region.end_id, head, insert_gravity or true)
end

function Session:_find_region(start_pos, end_pos)
  for index, region in ipairs(self.regions) do
    local a, b = self:positions(region)
    if a and same_pos(a, start_pos) and same_pos(b, end_pos) then
      return index
    end
  end
end

function Session:add_region(start_pos, end_pos)
  end_pos = end_pos or start_pos
  local existing = self:_find_region(start_pos, end_pos)
  if existing then
    self.active = existing
    self:render()
    self:focus()
    return false
  end

  next_region_id = next_region_id + 1
  local region = { id = next_region_id }
  region.start_id = set_mark(self.buf, nil, start_pos, false)
  region.end_id = set_mark(self.buf, nil, end_pos, true)
  table.insert(self.regions, region)
  self:sort_regions(region.id)
  self:render()
  self:focus()
  return true
end

function Session:add_selection(start_pos, finish_pos)
  local head = util.previous_position(self.buf, finish_pos)
  self.mode = "extend"
  local existing = self:_find_region(start_pos, finish_pos)
  if existing then
    self.active = existing
    self:render()
    self:focus()
    return false
  end
  return self:add_region(start_pos, head)
end

function Session:sort_regions(active_id)
  active_id = active_id or (self.regions[self.active] and self.regions[self.active].id)
  table.sort(self.regions, function(left, right)
    local a = self:positions(left) or { row = 0, col = 0 }
    local b = self:positions(right) or { row = 0, col = 0 }
    return util.compare_pos(a, b) < 0
  end)
  for index, region in ipairs(self.regions) do
    if region.id == active_id then
      self.active = index
      break
    end
  end
end

function Session:render()
  if not vim.api.nvim_buf_is_valid(self.buf) then
    return
  end
  vim.api.nvim_buf_clear_namespace(self.buf, decor_ns, 0, -1)
  local highlights = config.options.highlights
  for index, region in ipairs(self.regions) do
    local start_pos, end_pos = self:positions(region)
    if start_pos then
      local active = index == self.active
      local cursor_hl = self.mode == "insert"
          and (active and highlights.insert_active or highlights.insert)
        or (active and highlights.cursor_active or highlights.cursor)
      if self.mode == "insert" then
        local line = vim.api.nvim_buf_get_lines(self.buf, start_pos.row, start_pos.row + 1, true)[1] or ""
        if start_pos.col < #line then
          vim.api.nvim_buf_set_extmark(self.buf, decor_ns, start_pos.row, start_pos.col, {
            end_row = start_pos.row,
            end_col = util.char_end(line, start_pos.col),
            hl_group = cursor_hl,
            right_gravity = true,
            end_right_gravity = true,
            priority = active and 210 or 200,
          })
        else
          vim.api.nvim_buf_set_extmark(self.buf, decor_ns, start_pos.row, start_pos.col, {
            virt_text = { { " ", cursor_hl } },
            virt_text_pos = "overlay",
            right_gravity = true,
            priority = active and 210 or 200,
          })
        end
      elseif self.mode ~= "extend" then
        local line = vim.api.nvim_buf_get_lines(self.buf, start_pos.row, start_pos.row + 1, true)[1] or ""
        if start_pos.col < #line then
          vim.api.nvim_buf_set_extmark(self.buf, decor_ns, start_pos.row, start_pos.col, {
            end_row = start_pos.row,
            end_col = util.char_end(line, start_pos.col),
            hl_group = cursor_hl,
            priority = active and 210 or 200,
          })
        else
          vim.api.nvim_buf_set_extmark(self.buf, decor_ns, start_pos.row, start_pos.col, {
            virt_text = { { " ", cursor_hl } },
            virt_text_pos = "overlay",
            priority = active and 210 or 200,
          })
        end
      elseif same_pos(start_pos, end_pos) then
        vim.api.nvim_buf_set_extmark(self.buf, decor_ns, start_pos.row, start_pos.col, {
          virt_text = { { " ", active and highlights.selection_active or highlights.selection } },
          virt_text_pos = "overlay",
          priority = active and 210 or 200,
        })
      else
        vim.api.nvim_buf_set_extmark(self.buf, decor_ns, start_pos.row, start_pos.col, {
          end_row = end_pos.row,
          end_col = end_pos.col,
          hl_group = active and highlights.selection_active or highlights.selection,
          hl_eol = end_pos.row > start_pos.row,
          priority = active and 210 or 200,
        })
      end
    end
  end
  require("visual-multi.statusline").update(self)
end

function Session:focus()
  if vim.api.nvim_get_current_buf() ~= self.buf then
    return
  end
  local region = self.regions[self.active]
  local head = region and self:_mark_pos(region.end_id)
  if head then
    pcall(vim.api.nvim_win_set_cursor, 0, { head.row + 1, head.col })
  end
end

function Session:select_word()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local word = util.word_at(self.buf, cursor[1] - 1, cursor[2])
  if not word then
    return false
  end
  self.pattern = word.text
  return self:add_selection(word.start, word.finish)
end

function Session:_pattern_from_selection()
  if self.mode ~= "extend" then
    return false
  end
  local region = self.regions[self.active]
  if not region then
    return false
  end
  local start_pos, end_pos = self:positions(region)
  if not start_pos then
    return false
  end
  local text = util.get_text(self.buf, start_pos, end_pos)
  if text == "" or text:find("\n", 1, true) then
    return false
  end
  self.pattern = text
  return true
end

function Session:_search(direction, origin)
  if not self.pattern or self.pattern == "" then
    return false
  end

  local region = self.regions[self.active]
  local start_pos, end_pos
  if region then
    start_pos, end_pos = self:positions(region)
  end
  if origin then
    start_pos, end_pos = origin.start, origin.finish
  end
  if not start_pos then
    return false
  end

  local search_from = direction > 0 and end_pos or start_pos
  local line = vim.api.nvim_buf_get_lines(self.buf, search_from.row, search_from.row + 1, true)[1] or ""
  local col = search_from.col
  if direction > 0 and col > 0 then
    col = math.min(#line, col - 1)
  end
  pcall(vim.api.nvim_win_set_cursor, 0, { search_from.row + 1, col })

  local flags = direction > 0 and "W" or "bW"
  if config.options.wrap then
    flags = flags:gsub("W", "w")
  end
  local pattern = util.literal_pattern(self.pattern, config.options.case_sensitive)

  for _ = 1, #self.regions + 2 do
    local found = vim.fn.searchpos(pattern, flags)
    if found[1] == 0 then
      self:focus()
      return false
    end
    local match_start = { row = found[1] - 1, col = found[2] - 1 }
    local match_end = { row = match_start.row, col = match_start.col + #self.pattern }
    if not self:_find_region(match_start, match_end) then
      return self:add_selection(match_start, match_end)
    end
    pcall(vim.api.nvim_win_set_cursor, 0, { found[1], found[2] - 1 })
  end
  self:focus()
  return false
end

function Session:find_next(direction)
  if #self.regions == 0 then
    return self:select_word()
  end
  self:_pattern_from_selection()
  return self:_search(direction or 1)
end

function Session:_replace_selections(matches)
  if #matches == 0 then
    return
  end

  vim.api.nvim_buf_clear_namespace(self.buf, track_ns, 0, -1)
  self.regions = {}
  self.mode = "extend"
  for _, match in ipairs(matches) do
    next_region_id = next_region_id + 1
    local head = util.previous_position(self.buf, match.finish)
    self.regions[#self.regions + 1] = {
      id = next_region_id,
      start_id = set_mark(self.buf, nil, match.start, false),
      end_id = set_mark(self.buf, nil, head, true),
    }
  end
  self.active = #self.regions
  self:render()
  self:focus()
end

function Session:select_all()
  if not self:_pattern_from_selection() and not self.pattern then
    if not self:select_word() then
      return
    end
  end

  local matches = {}
  local pattern = vim.regex(util.literal_pattern(self.pattern, config.options.case_sensitive))
  local lines = vim.api.nvim_buf_get_lines(self.buf, 0, -1, true)
  for row, line in ipairs(lines) do
    local offset = 0
    while offset <= #line do
      local start_col, end_col = pattern:match_str(line:sub(offset + 1))
      if not start_col then
        break
      end
      start_col, end_col = start_col + offset, end_col + offset
      matches[#matches + 1] = {
        start = { row = row - 1, col = start_col },
        finish = { row = row - 1, col = end_col },
      }
      offset = math.max(end_col, offset + 1)
    end
  end
  self:_replace_selections(matches)
end

function Session:add_vertical(direction)
  local cursor = vim.api.nvim_win_get_cursor(0)
  if #self.regions == 0 then
    self:add_region({ row = cursor[1] - 1, col = cursor[2] })
  end
  local region = self.regions[self.active]
  local pos = region and self:_mark_pos(region.start_id)
  if not pos then
    return
  end
  local target_row = pos.row + direction
  if target_row < 0 or target_row >= vim.api.nvim_buf_line_count(self.buf) then
    return
  end
  local vcol = vim.fn.virtcol({ pos.row + 1, pos.col + 1 })
  local target_col = vim.fn.virtcol2col(0, target_row + 1, vcol)
  target_col = math.max(0, target_col - 1)
  self:add_region({ row = target_row, col = target_col })
end

function Session:add_cursor_at_current()
  local cursor = vim.api.nvim_win_get_cursor(0)
  self:add_region({ row = cursor[1] - 1, col = cursor[2] })
end

function Session:add_word_at_current()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local word = util.word_at(self.buf, cursor[1] - 1, cursor[2])
  if word then
    self.pattern = self.pattern or word.text
    self:add_selection(word.start, word.finish)
  end
end

function Session:toggle_extend()
  if self.mode == "insert" then
    return
  end
  if self.mode == "normal" then
    self.mode = "extend"
  else
    for _, region in ipairs(self.regions) do
      local _, head = self:raw_positions(region)
      if head then
        self:_set_positions(region, head, head)
      end
    end
    self.mode = "normal"
  end
  self:sort_regions()
  self:render()
  self:focus()
end

function Session:select_horizontal(direction)
  if #self.regions == 0 then
    self:add_cursor_at_current()
  end
  if self.mode ~= "extend" then
    self:toggle_extend()
  end
  self:move(direction > 0 and "l" or "h", 1)
end

function Session:start_from_selection(start_pos, finish_pos, select_all)
  local text = util.get_text(self.buf, start_pos, finish_pos)
  if text == "" or text:find("\n", 1, true) then
    return false
  end
  self.pattern = text
  self:add_selection(start_pos, finish_pos)
  if select_all then
    self:select_all()
  else
    self:_search(1)
  end
  return true
end

function Session:navigate(delta)
  if #self.regions == 0 then
    return
  end
  self.active = ((self.active - 1 + delta) % #self.regions) + 1
  self:render()
  self:focus()
end

function Session:_region_index_at_cursor()
  if vim.api.nvim_get_current_buf() ~= self.buf then
    return nil
  end
  local cursor = vim.api.nvim_win_get_cursor(0)
  local pos = { row = cursor[1] - 1, col = cursor[2] }
  local low, high, candidate = 1, #self.regions, nil
  while low <= high do
    local mid = math.floor((low + high) / 2)
    local start_pos = self:positions(self.regions[mid])
    if start_pos and util.compare_pos(start_pos, pos) <= 0 then
      candidate = mid
      low = mid + 1
    else
      high = mid - 1
    end
  end
  if candidate then
    local start_pos, end_pos = self:positions(self.regions[candidate])
    local after_start = util.compare_pos(pos, start_pos) >= 0
    local before_end = util.compare_pos(pos, end_pos) < 0
    if (same_pos(start_pos, end_pos) and same_pos(pos, start_pos))
      or (after_start and before_end)
    then
      return candidate
    end
  end
end

function Session:_activate_region_at_cursor()
  local index = self:_region_index_at_cursor()
  if not index then
    return false
  end
  local changed = self.active ~= index
  self.active = index
  return changed
end

function Session:remove_current()
  self:_activate_region_at_cursor()
  local region = self.regions[self.active]
  if not region then
    return
  end
  vim.api.nvim_buf_del_extmark(self.buf, track_ns, region.start_id)
  vim.api.nvim_buf_del_extmark(self.buf, track_ns, region.end_id)
  table.remove(self.regions, self.active)
  if #self.regions == 0 then
    self:clear()
    return
  end
  self.active = math.min(self.active, #self.regions)
  self:render()
  self:focus()
end

function Session:skip()
  self:_activate_region_at_cursor()
  local region = self.regions[self.active]
  if not region then
    return
  end
  local start_pos, end_pos = self:positions(region)
  if not start_pos then
    return
  end
  self:remove_current()
  if sessions[self.buf] == self then
    self:_search(1, { start = start_pos, finish = end_pos })
  end
end

function Session:_edits_for_regions(kind, values)
  local edits = {}
  for index, region in ipairs(self.regions) do
    local start_pos, end_pos = self:positions(region)
    if start_pos then
      if same_pos(start_pos, end_pos) and kind ~= "insert" then
        local line = vim.api.nvim_buf_get_lines(self.buf, start_pos.row, start_pos.row + 1, true)[1] or ""
        end_pos = { row = start_pos.row, col = util.char_end(line, start_pos.col) }
      end
      edits[#edits + 1] = {
        region = region,
        start = start_pos,
        finish = end_pos,
        text = values and (values[index] or values[1]) or "",
      }
    end
  end
  table.sort(edits, function(a, b)
    return util.compare_pos(a.start, b.start) > 0
  end)
  return edits
end

function Session:_deduplicate_regions()
  local active_region = self.regions[self.active]
  local seen, regions, active = {}, {}, 1
  for _, region in ipairs(self.regions) do
    local pos = self:_mark_pos(region.end_id)
    if pos then
      local key = pos.row .. ":" .. pos.col
      if not seen[key] then
        regions[#regions + 1] = region
        seen[key] = #regions
      else
        vim.api.nvim_buf_del_extmark(self.buf, track_ns, region.start_id)
        vim.api.nvim_buf_del_extmark(self.buf, track_ns, region.end_id)
      end
      if region == active_region then
        active = seen[key]
      end
    end
  end
  self.regions = regions
  self.active = math.min(active, #regions)
end

function Session:_apply_edits(edits, _, deduplicate)
  for index, edit in ipairs(edits) do
    if index > 1 then
      pcall(vim.cmd, "silent! undojoin")
    end
    local start_pos = util.clamp_position(self.buf, edit.start.row, edit.start.col)
    local finish_pos = util.clamp_position(self.buf, edit.finish.row, edit.finish.col)
    vim.api.nvim_buf_set_text(
      self.buf,
      start_pos.row,
      start_pos.col,
      finish_pos.row,
      finish_pos.col,
      util.split_text(edit.text)
    )
  end

  self.mode = "normal"
  for _, edit in ipairs(edits) do
    local start_pos = self:_mark_pos(edit.region.start_id) or edit.start
    self:_set_positions(edit.region, start_pos, start_pos)
  end
  self:sort_regions()
  if deduplicate then
    self:_deduplicate_regions()
  end
  self:render()
  self:focus()
end

function Session:yank(keep_extend)
  local values = {}
  for _, region in ipairs(self.regions) do
    local start_pos, end_pos = self:positions(region)
    if same_pos(start_pos, end_pos) then
      local line = vim.api.nvim_buf_get_lines(self.buf, start_pos.row, start_pos.row + 1, true)[1] or ""
      end_pos = { row = start_pos.row, col = util.char_end(line, start_pos.col) }
    end
    values[#values + 1] = util.get_text(self.buf, start_pos, end_pos)
  end
  self.register = values
  if values[1] then
    vim.fn.setreg('"', values[1], "v")
  end

  if self.mode == "extend" and not keep_extend then
    for _, region in ipairs(self.regions) do
      local _, head = self:raw_positions(region)
      self:_set_positions(region, head, head)
    end
    self.mode = "normal"
    self:sort_regions()
    self:render()
    self:focus()
  end
end

function Session:delete(enter_insert)
  self:yank(true)
  self:_apply_edits(self:_edits_for_regions("delete"), false)
  if enter_insert then
    self:begin_insert("i")
  end
end

function Session:delete_to_eol()
  local edits, values = {}, {}
  for index, region in ipairs(self.regions) do
    local _, head = self:raw_positions(region)
    if head then
      local line = vim.api.nvim_buf_get_lines(self.buf, head.row, head.row + 1, true)[1] or ""
      local finish_pos = { row = head.row, col = #line }
      values[index] = util.get_text(self.buf, head, finish_pos)
      edits[#edits + 1] = {
        region = region,
        start = head,
        finish = finish_pos,
        text = "",
      }
    end
  end
  table.sort(edits, function(left, right)
    return util.compare_pos(left.start, right.start) > 0
  end)
  self.register = values
  if values[1] then
    vim.fn.setreg('"', values[1], "v")
  end
  self:_apply_edits(edits, false, true)
  self:begin_insert("i")
end

function Session:paste()
  local values = self.register
  if not values or #values == 0 then
    values = { vim.fn.getreg('"') }
  end
  self:_apply_edits(self:_edits_for_regions("replace", values), true)
end

function Session:move(motion, count)
  count = count or vim.v.count1
  local active_id = self.regions[self.active] and self.regions[self.active].id
  local line_local = motion == "w" or motion == "b" or motion == "e" or motion == "h" or motion == "l"
  local backward = motion == "b" or motion == "h"
  for _, region in ipairs(self.regions) do
    local anchor, head = self:raw_positions(region)
    if head then
      pcall(vim.api.nvim_win_set_cursor, 0, { head.row + 1, head.col })
      vim.cmd.normal({ args = { tostring(count) .. motion }, bang = true })
      local cursor = vim.api.nvim_win_get_cursor(0)
      local moved = { row = cursor[1] - 1, col = cursor[2] }
      if line_local and moved.row ~= head.row then
        local line = vim.api.nvim_buf_get_lines(self.buf, head.row, head.row + 1, true)[1] or ""
        moved = (backward or line == "") and { row = head.row, col = 0 }
          or util.previous_position(self.buf, { row = head.row, col = #line })
      end
      if self.mode == "extend" then
        self:_set_positions(region, anchor, moved)
      else
        self:_set_positions(region, moved, moved)
      end
    end
  end
  self:sort_regions(active_id)
  self:render()
  self:focus()
end

function Session:change_number(delta)
  local key = vim.api.nvim_replace_termcodes(delta > 0 and "<C-a>" or "<C-x>", true, false, true)
  local regions = vim.list_slice(self.regions)
  table.sort(regions, function(left, right)
    local a = self:_mark_pos(left.end_id)
    local b = self:_mark_pos(right.end_id)
    return util.compare_pos(a, b) > 0
  end)
  for index, region in ipairs(regions) do
    local pos = self:_mark_pos(region.end_id)
    if pos then
      if index > 1 then
        pcall(vim.cmd, "silent! undojoin")
      end
      pcall(vim.api.nvim_win_set_cursor, 0, { pos.row + 1, pos.col })
      vim.cmd.normal({ args = { tostring(vim.v.count1) .. key }, bang = true })
      local cursor = vim.api.nvim_win_get_cursor(0)
      local changed = { row = cursor[1] - 1, col = cursor[2] }
      self:_set_positions(region, changed, changed)
    end
  end
  self.mode = "normal"
  self:sort_regions()
  self:render()
  self:focus()
end

function Session:begin_insert(kind)
  require("visual-multi.insert").start(self, kind or "i")
end

function Session:insert_paste()
  require("visual-multi.insert").paste(self)
end

function Session:end_insert()
  require("visual-multi.insert").stop(self)
end

function Session:info()
  local current = self:_region_index_at_cursor() or self.active
  local text
  local region = self.mode == "extend" and self.regions[current] or nil
  if region then
    local start_pos, end_pos = self:positions(region)
    if start_pos then
      text = util.get_text(self.buf, start_pos, end_pos)
    end
  end
  return {
    active = self.active,
    current = current,
    total = #self.regions,
    pattern = self.pattern,
    text = text,
    mode = self.mode,
    inserting = self.inserting,
  }
end

function Session:clear()
  if sessions[self.buf] ~= self then
    return
  end
  self.inserting = false
  require("visual-multi.statusline").detach(self)
  require("visual-multi.mappings").deactivate(self)
  if vim.api.nvim_buf_is_valid(self.buf) then
    vim.api.nvim_buf_clear_namespace(self.buf, track_ns, 0, -1)
    vim.api.nvim_buf_clear_namespace(self.buf, decor_ns, 0, -1)
  end
  if self.augroup then
    pcall(vim.api.nvim_del_augroup_by_id, self.augroup)
  end
  sessions[self.buf] = nil
end

Session.track_ns = track_ns

return Session
