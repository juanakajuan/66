local context = require("66.context")
local opencode = require("66.opencode")
local prompts = require("66.prompts")
local ui = require("66.ui")

local M = {}

function M.run()
	local ok, selection = pcall(context.selection)
	if not ok then
		vim.notify("Edit66 requires a visual selection", vim.log.levels.ERROR)
		return
	end

	ui.capture_prompt(" 66 edit ", "66 edit", "Edit66", function(instruction)
		opencode.show_response(opencode.command(prompts.edit(instruction, selection), opencode.edit_title(instruction)))
	end)
end

return M
