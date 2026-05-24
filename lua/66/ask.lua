local context = require("66.context")
local opencode = require("66.opencode")
local prompts = require("66.prompts")
local ui = require("66.ui")

local M = {}

local status_namespace = vim.api.nvim_create_namespace("66_ask_status")

--- Show an inline Asking status around the selected range.
--- @param bufnr integer
--- @param start_line integer 1-based first selected line.
--- @param end_line integer 1-based last selected line.
--- @return fun()
local function start_asking_status(bufnr, start_line, end_line)
  local running = true
  local frame = 1
  local top_id
  local bottom_id

  local function clear()
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_clear_namespace(bufnr, status_namespace, 0, -1)
    end
  end

  local function set_extmark(row, id, line, above)
    local opts = {
      virt_lines = { { { line, "Comment" } } },
      virt_lines_above = above,
    }
    if id then
      opts.id = id
    end
    return vim.api.nvim_buf_set_extmark(bufnr, status_namespace, row, 0, opts)
  end

  local function render()
    if not running or not vim.api.nvim_buf_is_valid(bufnr) then
      return
    end

    local line_count = vim.api.nvim_buf_line_count(bufnr)
    local top_row = math.max(0, math.min(start_line - 1, line_count - 1))
    local bottom_row = math.max(0, math.min(end_line - 1, line_count - 1))
    local text = ui.throbber_frames[frame] .. " Asking"

    top_id = set_extmark(top_row, top_id, text, true)
    bottom_id = set_extmark(bottom_row, bottom_id, text, false)
    frame = frame % #ui.throbber_frames + 1
    vim.defer_fn(render, 120)
  end

  render()

  return function()
    running = false
    clear()
  end
end

--- Run opencode for an Ask prompt, then open the response after completion.
--- @param source_bufnr integer
--- @param selection SelectionContext
--- @param question string
local function run_question(source_bufnr, selection, question)
  local stop_status = start_asking_status(source_bufnr, selection.start_line, selection.end_line)
  local command = opencode.command(prompts.ask(question, selection), opencode.ask_title(question))

  opencode.run(command, function(result, text)
    stop_status()

    if result.code ~= 0 then
      text = string.format("opencode exited with code %d\n\n%s", result.code, text)
    end
    if text == "" then
      text = "opencode completed without output."
    end

    ui.open_scratch_response("66 response", vim.split(text, "\n", { plain = true }), "markdown")
  end)
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
