local config = require("66.config")

local M = {}

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

local function with_line_numbers(lines, start_line)
	local numbered = {}
	for index, line in ipairs(lines) do
		numbered[index] = string.format("%d: %s", start_line + index - 1, line)
	end
	return table.concat(numbered, "\n")
end

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

--- Capture the current visual selection and bounded file context.
--- @return { path: string, filetype: string, start_line: integer, end_line: integer, selected: string, current_file: string }
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
	}
end

return M
