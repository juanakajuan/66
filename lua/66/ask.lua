local context = require("66.context")
local opencode = require("66.opencode")
local prompts = require("66.prompts")
local ui = require("66.ui")

local M = {}

local status_namespace = vim.api.nvim_create_namespace("66_ask_status")

--- Run opencode for an Ask prompt, then open the response after completion.
--- @param source_bufnr integer
--- @param selection SelectionContext
--- @param question string
local function run_question(source_bufnr, selection, question)
  local stop_status = ui.start_inline_status(
    source_bufnr,
    status_namespace,
    selection.start_line,
    selection.end_line,
    "Asking"
  )
  local command = opencode.command(prompts.ask(question, selection), opencode.ask_title(question))

  opencode.run(command, function(result, text, state)
    stop_status()

    if state and state.canceled then
      return
    end

    if result.code ~= 0 then
      text = string.format("opencode exited with code %d\n\n%s", result.code, text)
    end
    if text == "" then
      text = "opencode completed without output."
    end

    ui.open_scratch_response("66 response", vim.split(text, "\n", { plain = true }), "markdown")
  end, {
    on_cancel = stop_status,
  })
end

--- Ask opencode about the current visual selection with a provided question.
--- @param question string User-facing question or preset instruction.
local function ask_selection(question)
  local source_bufnr = vim.api.nvim_get_current_buf()
  local ok, selection = pcall(context.selection)
  if not ok then
    vim.notify("Ask66 requires a visual selection", vim.log.levels.ERROR)
    return
  end

  run_question(source_bufnr, selection, question)
end

--- Ask opencode about the current visual selection without editing source buffers.
function M.run()
  local source_bufnr = vim.api.nvim_get_current_buf()
  local ok, selection = pcall(context.selection)
  if not ok then
    vim.notify("Ask66 requires a visual selection", vim.log.levels.ERROR)
    return
  end

  ui.capture_prompt(" 66 ask ", "66 ask", "Ask66", function(question)
    run_question(source_bufnr, selection, question)
  end)
end

--- Explain the current visual selection without asking for a prompt.
function M.explain()
  ask_selection("Explain this selection clearly and concisely.")
end

return M
