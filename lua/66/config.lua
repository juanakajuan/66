local M = {}

local defaults = {
  model = "openai/gpt-5.5",
  variant = "low",
  agent = "build",
  max_file_lines = 400,
  edit_context_lines = 120,
  response_layout = "bottom_split",
  ask_keymap = "<leader>6a",
  explain_keymap = "<leader>6x",
  search_keymap = "<leader>6s",
  history_keymap = "<leader>6h",
  edit_keymap = "<leader>6e",
  cancel_keymap = "<leader>6c",
}

local response_layouts = {
  right_split = true,
  bottom_split = true,
  float = true,
  tab = true,
}

local config = vim.deepcopy(defaults)

--- Return the active 66 configuration.
--- @return SixtySixConfig
function M.options()
  return config
end

--- Configure 66 from user options.
--- @param opts? table Partial `SixtySixConfig` override table.
--- @return SixtySixConfig
function M.setup(opts)
  config = vim.tbl_deep_extend("force", defaults, opts or {})
  if not response_layouts[config.response_layout] then
    error("invalid 66 response_layout: " .. tostring(config.response_layout), 0)
  end

  return config
end

return M
