local M = {}

local defaults = {
	model = "openai/gpt-5.5",
	variant = "low",
	agent = "build",
	max_file_lines = 400,
	response_layout = "bottom_split",
	ask_keymap = "<leader>6a",
	search_keymap = "<leader>6s",
	history_keymap = "<leader>6h",
}

local response_layouts = {
	right_split = true,
	bottom_split = true,
	float = true,
	tab = true,
}

local config = vim.deepcopy(defaults)

--- Return the active 66 configuration.
--- @return table
function M.options()
	return config
end

--- Configure 66 from user options.
--- @param opts? { model?: string, variant?: string, agent?: string, max_file_lines?: integer, response_layout?: "right_split"|"bottom_split"|"float"|"tab", ask_keymap?: string|false, search_keymap?: string|false, history_keymap?: string|false }
--- @return table
function M.setup(opts)
	config = vim.tbl_deep_extend("force", defaults, opts or {})
	if not response_layouts[config.response_layout] then
		error("invalid 66 response_layout: " .. tostring(config.response_layout), 0)
	end

	return config
end

return M
