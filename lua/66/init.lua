local config = require("66.config")
local ask = require("66.ask")
local search = require("66.search")
local ui = require("66.ui")

local M = {}

local did_setup = false

--- Ask opencode about the current visual selection without editing source buffers.
function M.ask()
	ask.run()
end

--- Search the current project and open matching locations in quickfix.
function M.search()
	ui.capture_prompt(" 66 search ", "66 search", "Search66", function(question)
		search.run(question)
	end)
end

--- Configure the 66 prototype.
--- @param opts? { model?: string, variant?: string, agent?: string, max_file_lines?: integer, response_layout?: "right_split"|"bottom_split"|"float"|"tab", ask_keymap?: string|false, search_keymap?: string|false, history_keymap?: string|false }
function M.setup(opts)
	local opts_with_defaults = config.setup(opts)

	vim.api.nvim_create_user_command("Ask66", function()
		M.ask()
	end, { desc = "Ask opencode about the visual selection", range = true })

	vim.api.nvim_create_user_command("Search66", function()
		M.search()
	end, { desc = "Search the current project with opencode" })

	vim.api.nvim_create_user_command("History66", function()
		M.history()
	end, { desc = "Open the session history for the current project" })

	if opts_with_defaults.ask_keymap and not did_setup then
		vim.keymap.set("v", opts_with_defaults.ask_keymap, function()
			M.ask()
		end, { desc = "66 ask about selection" })
	end

	if opts_with_defaults.search_keymap and not did_setup then
		vim.keymap.set("n", opts_with_defaults.search_keymap, function()
			M.search()
		end, { desc = "66 search project" })
	end

	if opts_with_defaults.history_keymap and not did_setup then
		vim.keymap.set("n", opts_with_defaults.history_keymap, function()
			M.history()
		end, { desc = "66 open session history" })
	end

	did_setup = true
end

return M
