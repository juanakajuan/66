local context = require("66.context")
local opencode = require("66.opencode")
local prompts = require("66.prompts")
local ui = require("66.ui")

local M = {}

--- Ask Neovim to notice files changed by the external edit process.
--- @param source_bufnr integer
local function refresh_changed_buffers(source_bufnr)
	local ok, err = pcall(function()
		if vim.api.nvim_buf_is_valid(source_bufnr) then
			vim.cmd("checktime " .. source_bufnr)
		end
		vim.cmd("checktime")
	end)
	if not ok then
		vim.notify("Edit66 could not refresh changed buffers: " .. tostring(err), vim.log.levels.WARN)
	end
end

function M.run()
	local source_bufnr = vim.api.nvim_get_current_buf()
	local ok, selection = pcall(context.selection)
	if not ok then
		vim.notify("Edit66 requires a visual selection", vim.log.levels.ERROR)
		return
	end

	ui.capture_prompt(" 66 edit ", "66 edit", "Edit66", function(instruction)
		opencode.show_response(opencode.command(prompts.edit(instruction, selection), opencode.edit_title(instruction)), {
			on_complete = function()
				refresh_changed_buffers(source_bufnr)
			end,
		})
	end)
end

return M
