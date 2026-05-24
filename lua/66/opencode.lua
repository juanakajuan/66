local config = require("66.config")
local ui = require("66.ui")

local M = {}

--- @class ActiveRequest
--- @field id integer
--- @field handle vim.SystemObj?
--- @field canceled boolean
--- @field finished boolean
--- @field on_cancel? fun()

local active_requests = {}
local next_request_id = 0
local SIGTERM = vim.uv.constants.SIGTERM

--- @param event table
--- @return string?
local function text_event_phase(event)
  local part = event.part
  if event.type ~= "text" or type(part) ~= "table" then
    return nil
  end

  local metadata = part.metadata
  if type(metadata) ~= "table" then
    return nil
  end

  local openai = metadata.openai
  if type(openai) ~= "table" then
    return nil
  end

  return openai.phase
end

--- Parse opencode JSONL and return assistant text only.
--- @param text string
--- @return string?
local function assistant_text_from_json(text)
  local text_chunks = {}
  local final_answer_chunks = {}

  for _, line in ipairs(vim.split(text, "\n", { trimempty = true })) do
    local ok, event = pcall(vim.json.decode, line)
    if ok and type(event) == "table" and event.type == "text" and type(event.part) == "table" then
      local part_text = event.part.text
      if type(part_text) == "string" and part_text ~= "" then
        local phase = text_event_phase(event)
        if phase == "final_answer" then
          table.insert(final_answer_chunks, part_text)
        else
          table.insert(text_chunks, part_text)
        end
      end
    end
  end

  if #final_answer_chunks > 0 then
    return table.concat(final_answer_chunks, "")
  end
  if #text_chunks > 0 then
    return table.concat(text_chunks, "")
  end

  return nil
end

--- Drop opencode's captured status prologue from response text.
--- @param text string
--- @return string
local function strip_opencode_prologue(text)
  text = text:gsub("\27%[[%d;]*m", "")

  local lines = vim.split(text, "\n", { plain = true })
  local start = 1

  for index, line in ipairs(lines) do
    local trimmed = line:gsub("^%s+", "")
    if trimmed:match("^[→✱]") then
      start = index + 1
    end
  end

  while lines[start] == "" do
    start = start + 1
  end

  if start > 1 then
    return table.concat(vim.list_slice(lines, start), "\n")
  end

  local function is_ansi_reset_line(line)
    return line:match("^%s*%[[%d;]*m%s*$")
  end

  local function skip_ansi_reset_lines()
    while lines[start] and is_ansi_reset_line(lines[start]) do
      start = start + 1
    end
  end

  skip_ansi_reset_lines()

  if lines[start] and lines[start]:match("^%s*>%s+[%w_-]+%s+·%s+.+%s*$") then
    start = start + 1
  end

  skip_ansi_reset_lines()

  return table.concat(vim.list_slice(lines, start), "\n")
end

--- Build an opencode session title that Session History can identify.
--- @param kind "Ask"|"Search"|"Edit"
--- @param text string
--- @return string
local function session_title(kind, text)
  local title = text:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")

  if #title > 80 then
    title = title:sub(1, 77) .. "..."
  end

  return string.format("[66] %s: %s", kind, title)
end

local function next_id()
  next_request_id = next_request_id + 1
  return next_request_id
end

--- @param handle vim.SystemObj?
--- @param opts? OpenCodeRunOpts
--- @return ActiveRequest
local function register_request(handle, opts)
  opts = opts or {}

  local request = {
    id = next_id(),
    handle = handle,
    canceled = false,
    finished = false,
    on_cancel = opts.on_cancel,
  }

  table.insert(active_requests, request)
  return request
end

--- @param request ActiveRequest
local function unregister_request(request)
  request.finished = true

  for index, active_request in ipairs(active_requests) do
    if active_request == request then
      table.remove(active_requests, index)
      return
    end
  end
end

--- @return ActiveRequest?
local function newest_active_request()
  for index = #active_requests, 1, -1 do
    local request = active_requests[index]
    if not request.finished and not request.canceled then
      return request
    end
  end
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

--- @class OpenCodeRunState
--- @field canceled boolean

--- @class OpenCodeRunOpts
--- @field on_cancel? fun()

--- Run opencode and return combined stdout/stderr to the callback.
--- @param command string[]
--- @param on_complete fun(result: vim.SystemCompleted, text: string, state: OpenCodeRunState)
--- @param opts? OpenCodeRunOpts
function M.run(command, on_complete, opts)
  local output = {}
  local function append_output(_, data)
    if data and data ~= "" then
      table.insert(output, data)
    end
  end

  local request = register_request(nil, opts)
  request.handle = vim.system(
    command,
    {
      text = true,
      cwd = vim.fn.getcwd(),
      stdout = append_output,
      stderr = append_output,
    },
    vim.schedule_wrap(function(result)
      unregister_request(request)

      local text = table.concat(output, "")
      if text == "" then
        text = result.stdout or result.stderr or ""
      end
      on_complete(result, assistant_text_from_json(text) or strip_opencode_prologue(text), {
        canceled = request.canceled,
      })
    end)
  )
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

    if result.code ~= 0 then
      text = string.format("opencode exited with code %d\n\n%s", result.code, text)
    end
    if text == "" then
      text = "opencode completed without output."
    end

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
  local request = newest_active_request()
  if not request then
    vim.notify("No active 66 request to cancel", vim.log.levels.INFO)
    return
  end

  request.canceled = true
  if request.on_cancel then
    request.on_cancel()
  end
  if request.handle then
    request.handle:kill(SIGTERM)
  end
  vim.notify("Canceled 66 request", vim.log.levels.INFO)
end

return M
