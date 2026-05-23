local config = require("66.config")

local M = {}

--- @class SelectionContext
--- @field path string Absolute path of the selected buffer, or empty for unnamed buffers.
--- @field filetype string Neovim filetype for the selected buffer.
--- @field start_line integer 1-based first selected line.
--- @field end_line integer 1-based last selected line.
--- @field selected string Selected text prefixed with source line numbers.
--- @field current_file string Whole current file with line numbers, or an omission notice when too large.
--- @field edit_context string Nearby current-file lines around the selection for Edit Selection prompts.

--- Normalize visual marks into zero-based buffer text coordinates.
--- @param bufnr integer
--- @param start_pos [integer, integer, integer, integer]
--- @param end_pos [integer, integer, integer, integer]
--- @param selection_mode string
--- @return integer start_row
--- @return integer start_col
--- @return integer end_row
--- @return integer end_col
local function normalize_range(bufnr, start_pos, end_pos, selection_mode)
  if start_pos[2] == 0 or end_pos[2] == 0 then
    error("missing visual selection", 0)
  end

  local start_row = start_pos[2] - 1
  local start_col = start_pos[3] - 1
  local end_row = end_pos[2] - 1
  local end_col = end_pos[3]

  if selection_mode == "V" then
    if start_row > end_row then
      start_row, end_row = end_row, start_row
    end

    start_col = 0
    end_col = #(vim.api.nvim_buf_get_lines(bufnr, end_row, end_row + 1, false)[1] or "")
    return start_row, start_col, end_row, end_col
  end

  if start_row > end_row or (start_row == end_row and start_col > end_col) then
    start_row, end_row = end_row, start_row
    start_col, end_col = end_col - 1, start_col + 1
  end

  return start_row, start_col, end_row, end_col
end

--- Prefix lines with their 1-based source line numbers.
--- @param lines string[]
--- @param start_line integer
--- @return string
local function with_line_numbers(lines, start_line)
  local numbered = {}
  for index, line in ipairs(lines) do
    numbered[index] = string.format("%d: %s", start_line + index - 1, line)
  end
  return table.concat(numbered, "\n")
end

--- Return bounded current-file context for an Ask About Selection prompt.
--- @param bufnr integer
--- @return string
local function current_file_context(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local opts = config.options()
  if #lines > opts.max_file_lines then
    return string.format(
      "Current file omitted because it has %d lines, over the %d line limit.",
      #lines,
      opts.max_file_lines
    )
  end

  return with_line_numbers(lines, 1)
end

--- Return nearby current-file context around a selected range.
--- @param bufnr integer
--- @param start_row integer zero-based first selected row.
--- @param end_row integer zero-based last selected row.
--- @return string
local function edit_context(bufnr, start_row, end_row)
  local opts = config.options()
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  local context_lines = math.max(opts.edit_context_lines or 0, 0)
  local selected_count = end_row - start_row + 1
  local surrounding_lines = math.max(context_lines - selected_count, 0)
  local before = math.floor(surrounding_lines / 2)
  local after = surrounding_lines - before
  local context_start = math.max(start_row - before, 0)
  local context_end = math.min(end_row + after + 1, line_count)
  local lines = vim.api.nvim_buf_get_lines(bufnr, context_start, context_end, false)

  return with_line_numbers(lines, context_start + 1)
end

--- Capture the current visual selection and bounded file context.
--- @return SelectionContext
function M.selection()
  local bufnr = vim.api.nvim_get_current_buf()
  local mode = vim.fn.mode()
  local is_visual = mode == "v" or mode == "V" or mode == "\22"
  local selection_mode = is_visual and mode or vim.fn.visualmode()
  local start_row, start_col, end_row, end_col = normalize_range(
    bufnr,
    vim.fn.getpos(is_visual and "v" or "'<"),
    vim.fn.getpos(is_visual and "." or "'>"),
    selection_mode
  )
  local selected = vim.api.nvim_buf_get_text(bufnr, start_row, start_col, end_row, end_col, {})

  return {
    path = vim.api.nvim_buf_get_name(bufnr),
    filetype = vim.bo[bufnr].filetype,
    start_line = start_row + 1,
    end_line = end_row + 1,
    selected = with_line_numbers(selected, start_row + 1),
    current_file = current_file_context(bufnr),
    edit_context = edit_context(bufnr, start_row, end_row),
  }
end

return M
