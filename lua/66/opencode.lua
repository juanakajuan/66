local config = require("66.config")
local opencode_request = require("66.opencode_request")
local ui = require("66.ui")

local M = {}

--- Build an opencode session title that Session History can identify.
--- @param kind "Ask"|"Search"|"Edit"
--- @param text string
--- @return string
local function session_title(kind, text)
  local title = vim.trim(text:gsub("%s+", " "))

  if #title > 80 then
    title = title:sub(1, 77) .. "..."
  end

  return string.format("[66] %s: %s", kind, title)
end

--- Build an opencode command for the active config.
--- @param prompt string
--- @param title string
--- @return string[]
function M.command(prompt, title)
  local opts = config.options()
  return {
    "opencode",
    "run",
    "--format",
    "json",
    "--agent",
    opts.agent,
    "-m",
    opts.model,
    "--variant",
    opts.variant,
    "--title",
    title,
    prompt,
  }
end

--- @alias OpenCodeRequestKind "Ask"|"Search"|"Edit"

--- @class OpenCodeSubmission
--- @field kind OpenCodeRequestKind
--- @field prompt string
--- @field title string
--- @field on_complete fun(result: vim.SystemCompleted, text: string, state: OpenCodeRunState)
--- @field on_cancel? fun()

--- Submit an opencode request from user intent.
--- @param submission OpenCodeSubmission
function M.submit(submission)
  local command = M.command(submission.prompt, session_title(submission.kind, submission.title))
  opencode_request.run(command, submission.on_complete, {
    on_cancel = submission.on_cancel,
  })
end

--- Run opencode and return combined stdout/stderr to the callback.
--- @param command string[]
--- @param on_complete fun(result: vim.SystemCompleted, text: string, state: OpenCodeRunState)
--- @param opts? OpenCodeRunOpts
function M.run(command, on_complete, opts)
  opencode_request.run(command, on_complete, opts)
end

--- @class OpenCodeResponseOpts
--- @field on_complete? fun(result: vim.SystemCompleted, text: string)

--- Run opencode and display output in a Response View.
--- @param command string[]
--- @param opts? OpenCodeResponseOpts
function M.show_response(command, opts)
  opts = opts or {}
  local frame = 1
  local timer = assert(vim.uv.new_timer(), "failed to create response throbber timer")
  local running = true

  local function stop_timer()
    if not running then
      return
    end

    running = false
    timer:stop()
    timer:close()
  end

  local response_bufnr = ui.open_scratch_response("66 response", {
    ui.throbber_frames[frame] .. " Loading...",
    "",
    table.concat(vim.list_slice(command, 1, #command - 1), " "),
  }, "markdown")

  timer:start(
    0,
    100,
    vim.schedule_wrap(function()
      if not running then
        return
      end

      if not vim.api.nvim_buf_is_valid(response_bufnr) then
        stop_timer()
        return
      end

      frame = frame % #ui.throbber_frames + 1
      vim.api.nvim_buf_set_lines(response_bufnr, 0, 1, false, {
        ui.throbber_frames[frame] .. " Loading...",
      })
    end)
  )

  M.run(command, function(result, text, state)
    stop_timer()

    if state and state.canceled then
      return
    end

    text = opencode_request.response_output(result, text)

    if opts.on_complete then
      opts.on_complete(result, text)
    end

    if not vim.api.nvim_buf_is_valid(response_bufnr) then
      return
    end

    vim.api.nvim_buf_set_lines(
      response_bufnr,
      0,
      -1,
      false,
      vim.split(text, "\n", { plain = true })
    )
  end)
end

--- Build an Ask About Selection session title.
--- @param question string
--- @return string
function M.ask_title(question)
  return session_title("Ask", question)
end

--- Build a Project Search session title.
--- @param question string
--- @return string
function M.search_title(question)
  return session_title("Search", question)
end

--- Build an Edit Selection session title.
--- @param instruction string
--- @return string
function M.edit_title(instruction)
  return session_title("Edit", instruction)
end

function M.cancel_active()
  opencode_request.cancel_active()
end

return M
