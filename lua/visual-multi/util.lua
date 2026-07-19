local M = {}

function M.clamp_position(buf, row, col)
  local count = vim.api.nvim_buf_line_count(buf)
  row = math.max(0, math.min(row, count - 1))
  local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, true)[1] or ""
  return { row = row, col = math.max(0, math.min(col, #line)) }
end

function M.position_to_offset(buf, pos)
  return vim.api.nvim_buf_get_offset(buf, pos.row) + pos.col
end

function M.offset_to_position(buf, offset)
  local count = vim.api.nvim_buf_line_count(buf)
  local last = count - 1
  local eof = vim.api.nvim_buf_get_offset(buf, last)
    + #(vim.api.nvim_buf_get_lines(buf, last, last + 1, true)[1] or "")
  offset = math.max(0, math.min(offset, eof))

  local low, high = 0, last
  while low <= high do
    local mid = math.floor((low + high) / 2)
    if vim.api.nvim_buf_get_offset(buf, mid) <= offset then
      low = mid + 1
    else
      high = mid - 1
    end
  end

  local row = math.max(0, high)
  local col = offset - vim.api.nvim_buf_get_offset(buf, row)
  return M.clamp_position(buf, row, col)
end

function M.char_end(line, col)
  if col >= #line then
    return col
  end
  local ok, next_col = pcall(vim.str_byteindex, line, vim.str_utfindex(line, col) + 1)
  return ok and next_col or (col + 1)
end

function M.previous_position(buf, pos)
  if pos.col > 0 then
    local line = vim.api.nvim_buf_get_lines(buf, pos.row, pos.row + 1, true)[1] or ""
    local chars = vim.str_utfindex(line, pos.col)
    return { row = pos.row, col = vim.str_byteindex(line, math.max(0, chars - 1)) }
  end
  if pos.row == 0 then
    return { row = 0, col = 0 }
  end
  local row = pos.row - 1
  local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, true)[1] or ""
  if line == "" then
    return { row = row, col = 0 }
  end
  local chars = vim.str_utfindex(line)
  return { row = row, col = vim.str_byteindex(line, math.max(0, chars - 1)) }
end

function M.word_at(buf, row, col)
  local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, true)[1] or ""
  if line == "" then
    return nil
  end

  col = math.min(col, math.max(0, #line - 1))
  local regex = vim.regex([[\k\+]])
  local offset = 0
  while offset < #line do
    local start_col, end_col = regex:match_str(line:sub(offset + 1))
    if not start_col then
      break
    end
    start_col, end_col = start_col + offset, end_col + offset
    if start_col <= col and col < end_col then
      return {
        text = line:sub(start_col + 1, end_col),
        start = { row = row, col = start_col },
        finish = { row = row, col = end_col },
      }
    end
    offset = math.max(end_col, offset + 1)
  end
end

function M.literal_pattern(text, case_sensitive)
  local prefix = case_sensitive and [[\C\V]] or [[\c\V]]
  return prefix .. text:gsub([[\]], [[\\]])
end

function M.split_text(text)
  return vim.split(text, "\n", { plain = true })
end

function M.get_text(buf, start_pos, end_pos)
  return table.concat(vim.api.nvim_buf_get_text(
    buf,
    start_pos.row,
    start_pos.col,
    end_pos.row,
    end_pos.col,
    {}
  ), "\n")
end

function M.compare_pos(a, b)
  return a.row == b.row and a.col - b.col or a.row - b.row
end

return M
