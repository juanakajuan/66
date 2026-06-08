local context = require("66.context")
local edit_application = require("66.edit_application")
local opencode = require("66.opencode")
local prompts = require("66.prompts")
local ui = require("66.ui")

local M = {}

local status_namespace = vim.api.nvim_create_namespace("66_edit_status")

--- Open opencode output only when Edit Selection fails.
--- @param code integer
--- @param text string
local function show_edit_error(code, text)
  local lines = vim.split(
    string.format("opencode exited with code %d\n\n%s", code, text),
    "\n",
    { plain = true }
  )
  ui.open_scratch_response("66 edit error", lines, "markdown")
end

function M.run()
  local source_bufnr = vim.api.nvim_get_current_buf()
  local ok, selection = pcall(context.selection)
  if not ok then
    vim.notify("Edit66 requires a visual selection", vim.log.levels.ERROR)
    return
  end

  ui.capture_prompt(" 66 edit ", "66 edit", "Edit66", function(instruction)
    local application = edit_application.start(source_bufnr, selection)
    local stop_status = ui.start_inline_status(
      source_bufnr,
      status_namespace,
      selection.start_line,
      selection.end_line,
      "Implementing"
    )

    opencode.submit({
      kind = "Edit",
      title = instruction,
      prompt = prompts.edit(instruction, selection),
      on_complete = function(result, text, state)
        stop_status()

        if state and state.canceled then
          edit_application.discard(application)
          return
        end

        if result.code ~= 0 then
          edit_application.discard(application)
          show_edit_error(result.code, text)
          return
        end

        edit_application.apply_changed_source(application)
      end,
      on_cancel = function()
        stop_status()
        edit_application.discard(application)
      end,
    })
  end)
end

return M
