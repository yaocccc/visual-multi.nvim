local util = require("visual-multi.util")

local M = {}

local function end_positions(session)
  local wanted = {}
  for _, region in ipairs(session.regions) do
    wanted[region.end_id] = true
  end
  local positions = {}
  local marks = vim.api.nvim_buf_get_extmarks(session.buf, session.track_ns, 0, -1, {})
  for _, mark in ipairs(marks) do
    if wanted[mark[1]] then
      positions[mark[1]] = { row = mark[2], col = mark[3] }
    end
  end
  return positions
end

local function insertion_position(session, region, kind)
  local start_pos, finish_pos = session:positions(region)
  if session.mode == "extend" then
    local line = vim.api.nvim_buf_get_lines(session.buf, finish_pos.row, finish_pos.row + 1, true)[1] or ""
    local pos = kind == "i"
        and { row = start_pos.row, col = start_pos.col }
      or { row = finish_pos.row, col = finish_pos.col }
    if kind == "I" then
      pos.row = start_pos.row
      line = vim.api.nvim_buf_get_lines(session.buf, pos.row, pos.row + 1, true)[1] or ""
      pos.col = #(line:match("^%s*") or "")
    elseif kind == "A" then
      pos.col = #line
    end
    return pos
  end

  local line = vim.api.nvim_buf_get_lines(session.buf, start_pos.row, start_pos.row + 1, true)[1] or ""
  local pos = { row = start_pos.row, col = start_pos.col }
  if kind == "a" then
    pos.col = util.char_end(line, pos.col)
  elseif kind == "I" then
    pos.col = #(line:match("^%s*") or "")
  elseif kind == "A" then
    pos.col = #line
  end
  return pos
end

local function prepare(session, kind)
  local positions = {}
  for _, region in ipairs(session.regions) do
    positions[region.id] = insertion_position(session, region, kind)
  end
  for _, region in ipairs(session.regions) do
    local pos = positions[region.id]
    session:_set_positions(region, pos, pos, true)
  end
end

local function prepare_new_lines(session, kind)
  local groups = {}
  local active_region = session.regions[session.active]
  for _, region in ipairs(session.regions) do
    local _, head = session:raw_positions(region)
    if head then
      local group = groups[head.row]
      if not group then
        group = { row = head.row, region = region, active = false }
        groups[head.row] = group
      elseif group.region ~= region then
        vim.api.nvim_buf_del_extmark(session.buf, session.track_ns, region.start_id)
        vim.api.nvim_buf_del_extmark(session.buf, session.track_ns, region.end_id)
      end
      if region == active_region then
        group.active = true
      end
    end
  end

  local ordered = vim.tbl_values(groups)
  table.sort(ordered, function(left, right)
    return left.row > right.row
  end)

  session.syncing = true
  for index, group in ipairs(ordered) do
    if index > 1 then
      pcall(vim.cmd, "silent! undojoin")
    end
    local line = vim.api.nvim_buf_get_lines(session.buf, group.row, group.row + 1, true)[1] or ""
    local indent = vim.bo[session.buf].autoindent and (line:match("^%s*") or "") or ""
    local insert_row = kind == "o" and group.row + 1 or group.row
    vim.api.nvim_buf_set_lines(session.buf, insert_row, insert_row, false, { indent })
    group.mark = vim.api.nvim_buf_set_extmark(session.buf, session.track_ns, insert_row, #indent, {
      right_gravity = false,
    })
  end
  session.syncing = false

  local regions, active_id = {}, nil
  for _, group in ipairs(ordered) do
    local mark = vim.api.nvim_buf_get_extmark_by_id(session.buf, session.track_ns, group.mark, {})
    if #mark > 0 then
      local pos = { row = mark[1], col = mark[2] }
      session:_set_positions(group.region, pos, pos, true)
      vim.api.nvim_buf_del_extmark(session.buf, session.track_ns, group.mark)
      regions[#regions + 1] = group.region
      if group.active then
        active_id = group.region.id
      end
    end
  end
  session.regions = regions
  session.mode = "normal"
  session:sort_regions(active_id)
end

local function changed_text(buf, start_row, start_col, new_end_row, new_end_col)
  local end_row = start_row + new_end_row
  local end_col = new_end_row == 0 and start_col + new_end_col or new_end_col
  return vim.api.nvim_buf_get_text(buf, start_row, start_col, end_row, end_col, {})
end

local function mirror(session, event, generation)
  if session._insert_generation ~= generation or not vim.api.nvim_buf_is_valid(session.buf) then
    return
  end

  local state = session.insert_state
  if not state or state.generation ~= generation then
    return
  end

  local active = session.regions[session.active]
  if not active then
    return
  end

  local relative_start = event.relative_start
  local positions = end_positions(session)
  local simple_insert = relative_start == 0 and event.old_length == 0
  local targets = {}
  for index, region in ipairs(session.regions) do
    local cursor = positions[region.end_id]
    if index ~= session.active and cursor then
      local target = { cursor = cursor }
      if not simple_insert then
        target.start_offset = util.position_to_offset(session.buf, cursor) + relative_start
      end
      targets[#targets + 1] = target
    end
  end

  session.syncing = true
  for index = #targets, 1, -1 do
    local target = targets[index]
    pcall(vim.cmd, "silent! undojoin")
    local start_pos, end_pos
    if simple_insert then
      start_pos, end_pos = target.cursor, target.cursor
    else
      start_pos = util.offset_to_position(session.buf, target.start_offset)
      end_pos = util.offset_to_position(session.buf, target.start_offset + event.old_length)
    end
    pcall(
      vim.api.nvim_buf_set_text,
      session.buf,
      start_pos.row,
      start_pos.col,
      end_pos.row,
      end_pos.col,
      event.text
    )
  end
  session.syncing = false

  local active_pos = session:_mark_pos(active.end_id)
  if active_pos then
    state.active_offset = util.position_to_offset(session.buf, active_pos)
    if vim.api.nvim_get_current_buf() == session.buf then
      pcall(vim.api.nvim_win_set_cursor, 0, { active_pos.row + 1, active_pos.col })
    end
  end
end

function M.start(session, kind)
  if session.inserting or #session.regions == 0 then
    return
  end

  if kind == "o" or kind == "O" then
    prepare_new_lines(session, kind)
  else
    prepare(session, kind)
  end
  session.extend_origins = {}
  session.mode = "insert"
  session.inserting = true
  session._insert_generation = (session._insert_generation or 0) + 1
  local generation = session._insert_generation
  local active = session.regions[session.active]
  local active_pos = session:_mark_pos(active.end_id)
  local return_marks = {}
  for _, region in ipairs(session.regions) do
    local pos = session:_mark_pos(region.end_id)
    if pos then
      local return_pos = pos
      if (kind == "a" or kind == "A") and pos.col > 0 then
        return_pos = util.previous_position(session.buf, pos)
      end
      return_marks[region.id] = vim.api.nvim_buf_set_extmark(
        session.buf,
        session.track_ns,
        return_pos.row,
        return_pos.col,
        { right_gravity = false, undo_restore = false, invalidate = false }
      )
    end
  end

  local active_offset = util.position_to_offset(session.buf, active_pos)
  session.insert_state = {
    generation = generation,
    active_offset = active_offset,
    input_offset = active_offset,
    return_marks = return_marks,
    changed = false,
    queue = {},
    scheduled = false,
  }

  vim.api.nvim_buf_attach(session.buf, false, {
    on_bytes = function(
      _, buf, _, start_row, start_col, start_byte, _, _, old_length,
      new_end_row, new_end_col, new_length
    )
      if session._insert_generation ~= generation then
        return true
      end
      if session.syncing or not session.inserting then
        return false
      end
      local state = session.insert_state
      if not state or state.generation ~= generation then
        return false
      end
      state.changed = true
      state.queue[#state.queue + 1] = {
        relative_start = start_byte - state.input_offset,
        old_length = old_length,
        text = changed_text(buf, start_row, start_col, new_end_row, new_end_col),
      }
      state.input_offset = start_byte + new_length
      if not state.scheduled then
        state.scheduled = true
        vim.schedule(function()
          local current = session.insert_state
          if not current or current.generation ~= generation then
            return
          end
          for index = 1, #current.queue do
            mirror(session, current.queue[index], generation)
          end
          current.queue = {}
          current.scheduled = false
          current.input_offset = current.active_offset
        end)
      end
      return false
    end,
  })

  session:render()
  session:focus()
  local line = vim.api.nvim_buf_get_lines(session.buf, active_pos.row, active_pos.row + 1, true)[1] or ""
  if #line > 0 and active_pos.col >= #line then
    vim.cmd("startinsert!")
  else
    vim.cmd("startinsert")
  end
end

function M.paste(session)
  if not session.inserting or #session.regions == 0 then
    return
  end
  if session.insert_state then
    session.insert_state.changed = true
  end

  local values = session.register
  if not values or #values == 0 then
    values = { vim.fn.getreg('"') }
  end

  local positions = end_positions(session)
  local targets = {}
  local split_cache = {}
  for index, region in ipairs(session.regions) do
    local pos = positions[region.end_id]
    if pos then
      local text = values[index] or values[1] or ""
      split_cache[text] = split_cache[text] or util.split_text(text)
      targets[#targets + 1] = {
        pos = pos,
        lines = split_cache[text],
      }
    end
  end

  session.syncing = true
  for index = #targets, 1, -1 do
    local target = targets[index]
    pcall(vim.cmd, "silent! undojoin")
    pcall(
      vim.api.nvim_buf_set_text,
      session.buf,
      target.pos.row,
      target.pos.col,
      target.pos.row,
      target.pos.col,
      target.lines
    )
  end
  session.syncing = false

  local active = session.regions[session.active]
  local active_pos = active and session:_mark_pos(active.end_id)
  if active_pos then
    if session.insert_state then
      local offset = util.position_to_offset(session.buf, active_pos)
      session.insert_state.active_offset = offset
      session.insert_state.input_offset = offset
    end
    pcall(vim.api.nvim_win_set_cursor, 0, { active_pos.row + 1, active_pos.col })
  end
end

function M.stop(session)
  if not session.inserting then
    return
  end
  session.inserting = false
  session.mode = "normal"
  session._insert_generation = (session._insert_generation or 0) + 1
  local state = session.insert_state
  session.insert_state = nil

  local positions = end_positions(session)
  for _, region in ipairs(session.regions) do
    local pos = positions[region.end_id]
    local return_mark = state and state.return_marks and state.return_marks[region.id]
    if state and not state.changed and return_mark then
      local saved = vim.api.nvim_buf_get_extmark_by_id(session.buf, session.track_ns, return_mark, {})
      if #saved > 0 then
        pos = { row = saved[1], col = saved[2] }
      end
    elseif state and state.changed and pos and pos.col > 0 then
      pos = util.previous_position(session.buf, pos)
    end
    if return_mark then
      vim.api.nvim_buf_del_extmark(session.buf, session.track_ns, return_mark)
    end
    if pos then
      session:_set_positions(region, pos, pos, false)
    end
  end
  session:render()
  session:focus()
end

return M
