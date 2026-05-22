local config = require("66.config")
local ui = require("66.ui")

local ask = require("66.ask")
local search = require("66.search")
local tutorial = require("66.tutorial")
local history = require("66.history")
local edit = require("66.edit")

local M = {}

local did_setup = false

--- Ask opencode about the current visual selection without editing source buffers.
function M.ask()
	ask.run()
end

--- Explain the current visual selection without prompting for a question.
function M.explain()
	ask.explain()
end

--- Search the current project and open matching locations in quickfix.
function M.search()
	ui.capture_prompt(" 66 search ", "66 search", "Search66", function(question)
		search.run(question)
	end)
end

--- Create a read-only markdown tutorial about the current project.
function M.tutorial()
	ui.capture_prompt(" 66 tutorial ", "66 tutorial", "Tutorial66", function(question)
		tutorial.run(question)
	end)
end

--- Show opencode sessions for the current project.
function M.history()
	history.run()
end

--- Ask opencode to edit code related to the current visual selection.
function M.edit()
	edit.run()
end

--- Configure the 66 prototype.
--- @param opts? table Partial `SixtySixConfig` override table.
function M.setup(opts)
	local options = config.setup(opts)

	vim.api.nvim_create_user_command("Ask66", function()
		M.ask()
	end, { desc = "Ask opencode about the visual selection", range = true })

	vim.api.nvim_create_user_command("Explain66", function()
		M.explain()
	end, { desc = "Explain the visual selection with opencode", range = true })

	vim.api.nvim_create_user_command("Search66", function()
		M.search()
	end, { desc = "Search the current project with opencode" })

	vim.api.nvim_create_user_command("Tutorial66", function()
		M.tutorial()
	end, { desc = "Create a project tutorial with opencode" })

	vim.api.nvim_create_user_command("History66", function()
		M.history()
	end, { desc = "Open the session history for the current project" })

	vim.api.nvim_create_user_command("Edit66", function()
		M.edit()
	end, { desc = "Have opencode edit the visual selection", range = true })

	if not did_setup then
		if options.ask_keymap then
			vim.keymap.set("v", options.ask_keymap, function()
				M.ask()
			end, { desc = "66 ask about selection" })
		end

		if options.explain_keymap then
			vim.keymap.set("v", options.explain_keymap, function()
				M.explain()
			end, { desc = "66 explain selection" })
		end

		if options.search_keymap then
			vim.keymap.set("n", options.search_keymap, function()
				M.search()
			end, { desc = "66 search project" })
		end

		if options.tutorial_keymap then
			vim.keymap.set("n", options.tutorial_keymap, function()
				M.tutorial()
			end, { desc = "66 create project tutorial" })
		end

		if options.history_keymap then
			vim.keymap.set("n", options.history_keymap, function()
				M.history()
			end, { desc = "66 open session history" })
		end

		if options.edit_keymap then
			vim.keymap.set("v", options.edit_keymap, function()
				M.edit()
			end, { desc = "66 edit current selection" })
		end
	end

	did_setup = true
end

return M
