local M = {}

M.created_buffers = {}
M.patches = {}

function M.next_frame()
  local done = false
  vim.schedule(function()
    done = true
  end)

  vim.wait(1000, function()
    return done
  end)
end

function M.joined(lines)
  return table.concat(lines, "\n")
end

function M.patch_selection(start_line, start_col, end_line, end_col, mode)
  M.patch(vim.fn, "mode", function()
    return "n"
  end)
  M.patch(vim.fn, "visualmode", function()
    return mode or "v"
  end)
  M.patch(vim.fn, "getpos", function(mark)
    if mark == "'<" then
      return { 0, start_line, start_col, 0 }
    end
    if mark == "'>" then
      return { 0, end_line, end_col, 0 }
    end
    error("unexpected mark: " .. mark)
  end)
end

function M.clean_buffers()
  for _, bufnr in ipairs(M.created_buffers) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end

  M.created_buffers = {}
end

function M.restore_patches()
  for i = #M.patches, 1, -1 do
    local patch = M.patches[i]
    patch.table[patch.key] = patch.value
  end

  M.patches = {}
end

function M.cleanup()
  M.restore_patches()
  M.clean_buffers()
  vim.fn.setqflist({}, "r")
end

function M.patch(target, key, value)
  table.insert(M.patches, {
    table = target,
    key = key,
    value = target[key],
  })

  target[key] = value
end

function M.create_buffer(lines, filetype, row, col)
  assert(type(lines) == "table", "lines must be a table")

  local bufnr = vim.api.nvim_create_buf(false, false)
  vim.api.nvim_set_current_buf(bufnr)
  vim.bo[bufnr].filetype = filetype or "lua"
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_win_set_cursor(0, { row or 1, col or 0 })

  table.insert(M.created_buffers, bufnr)

  return bufnr
end

function M.buffer_lines(bufnr)
  return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
end

return M
