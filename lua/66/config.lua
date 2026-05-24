local M = {}

--- @class SixtySixConfig
--- @field model string opencode model identifier.
--- @field variant string opencode variant name.
--- @field agent string opencode agent name.
--- @field max_file_lines integer Maximum current-file lines sent as Selection Context.
--- @field edit_context_lines integer Maximum nearby source lines sent as Edit Selection context.
--- @field response_layout "right_split"|"bottom_split"|"float"|"tab" Response View placement.
--- @field ask_keymap string|false Visual-mode Ask About Selection mapping, or false to disable.
--- @field explain_keymap string|false Visual-mode Explain Selection preset mapping, or false to disable.
--- @field search_keymap string|false Normal-mode Project Search mapping, or false to disable.
--- @field history_keymap string|false Normal-mode Session History mapping, or false to disable.
--- @field edit_keymap string|false Edit Selection mapping, or false to disable.

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
  stop_keymap = "<leader>6q",
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
