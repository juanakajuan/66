local context = require("66.context")
local opencode = require("66.opencode")
local prompts = require("66.prompts")
local ui = require("66.ui")

local M = {}

--- Ask opencode about the current visual selection without editing source buffers.
function M.run()
	local ok, selection = pcall(context.selection)
	if not ok then
		vim.notify("Ask66 requires a visual selection", vim.log.levels.ERROR)
		return
	end

	ui.capture_prompt(" 66 ask ", "66 ask", "Ask66", function(question)
		opencode.show_response(opencode.command(prompts.ask(question, selection), opencode.ask_title(question)))
	end)
end

return M
