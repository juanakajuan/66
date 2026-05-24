local config = require("66.config")
local ui = require("66.ui")

local ask = require("66.ask")
local search = require("66.search")
local history = require("66.history")
local edit = require("66.edit")
local cancel = require("66.cancel")

local M = {}

local did_setup = false

local commands = {
  {
    name = "Ask66",
    method = "ask",
    opts = { desc = "Ask opencode about the visual selection", range = true },
  },
  {
    name = "Explain66",
    method = "explain",
    opts = { desc = "Explain the visual selection with opencode", range = true },
  },
  {
    name = "Search66",
    method = "search",
    opts = { desc = "Search the current project with opencode" },
  },
  {
    name = "History66",
    method = "history",
    opts = { desc = "Open the session history for the current project" },
  },
  {
    name = "Edit66",
    method = "edit",
    opts = { desc = "Have opencode edit the visual selection", range = true },
  },
  { name = "Cancel66", method = "cancel", opts = { desc = "Cancel the active opencode request" } },
}

local keymaps = {
  { option = "ask_keymap", mode = "v", method = "ask", desc = "66 ask about selection" },
  { option = "explain_keymap", mode = "v", method = "explain", desc = "66 explain selection" },
  { option = "search_keymap", mode = "n", method = "search", desc = "66 search project" },
  { option = "history_keymap", mode = "n", method = "history", desc = "66 open session history" },
  { option = "edit_keymap", mode = "v", method = "edit", desc = "66 edit current selection" },
  {
    option = "cancel_keymap",
    mode = "n",
    method = "cancel",
    desc = "66 cancel the current opencode request",
  },
}

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

--- Show opencode sessions for the current project.
function M.history()
  history.run()
end

--- Ask opencode to edit code related to the current visual selection.
function M.edit()
  edit.run()
end

--- Cancel the active opencode request.
function M.cancel()
  cancel.run()
end

--- Configure the 66 prototype.
--- @param opts? table Partial `SixtySixConfig` override table.
function M.setup(opts)
  local options = config.setup(opts)

  for _, command in ipairs(commands) do
    vim.api.nvim_create_user_command(command.name, function()
      M[command.method]()
    end, command.opts)
  end

  if not did_setup then
    for _, keymap in ipairs(keymaps) do
      local left_hand_side = options[keymap.option]

      if left_hand_side then
        vim.keymap.set(keymap.mode, left_hand_side, function()
          M[keymap.method]()
        end, { desc = keymap.desc })
      end
    end
  end

  did_setup = true
end

return M
