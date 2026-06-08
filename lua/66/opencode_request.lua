local M = {}

--- @class ActiveOpenCodeRequest
--- @field id integer
--- @field handle vim.SystemObj?
--- @field canceled boolean
--- @field finished boolean
--- @field on_cancel? fun()

--- @class OpenCodeRunState
--- @field canceled boolean

--- @class OpenCodeRunOpts
--- @field on_cancel? fun()

--- @type ActiveOpenCodeRequest[]
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

  local phase = openai.phase
  if type(phase) == "string" then
    return phase
  end

  return nil
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

--- Return captured streamed output, falling back to process output fields.
--- @param output string[] chunks collected from process output callbacks
--- @param result vim.SystemCompleted
--- @return string
local function combined_output(output, result)
  local text = table.concat(output, "")
  if text ~= "" then
    return text
  end

  return result.stdout or result.stderr or ""
end

--- Return raw command output, keeping stderr for failed commands.
--- @param stdout string[]
--- @param stderr string[]
--- @param result vim.SystemCompleted
--- @return string
local function raw_output(stdout, stderr, result)
  local text = table.concat(stdout, "")
  if text == "" and result.stdout then
    text = result.stdout
  end

  if result.code ~= 0 then
    local error_text = table.concat(stderr, "")
    if error_text == "" and result.stderr then
      error_text = result.stderr
    end
    text = text .. error_text
  end

  if text == "" and result.stderr then
    return result.stderr
  end

  return text
end

--- @param output string[]
--- @return fun(_: any, data: string?)
local function append_output(output)
  return function(_, data)
    if data and data ~= "" then
      table.insert(output, data)
    end
  end
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

--- Return user-readable assistant output from opencode's captured text.
--- @param text string
--- @return string
local function readable_output(text)
  return assistant_text_from_json(text) or strip_opencode_prologue(text)
end

local function next_id()
  next_request_id = next_request_id + 1
  return next_request_id
end

--- @param handle vim.SystemObj?
--- @param opts? OpenCodeRunOpts
--- @return ActiveOpenCodeRequest
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

--- @param request ActiveOpenCodeRequest
local function unregister_request(request)
  request.finished = true

  for index, active_request in ipairs(active_requests) do
    if active_request == request then
      table.remove(active_requests, index)
      return
    end
  end
end

--- @return ActiveOpenCodeRequest?
local function newest_active_request()
  for index = #active_requests, 1, -1 do
    local request = active_requests[index]
    if not request.finished and not request.canceled then
      return request
    end
  end
end

--- Run an opencode process through the shared active-request lifecycle.
--- @param command string[]
--- @param stdout fun(_: any, data: string?)
--- @param stderr fun(_: any, data: string?)
--- @param on_complete fun(result: vim.SystemCompleted, request: ActiveOpenCodeRequest)
--- @param opts? OpenCodeRunOpts
local function run_process(command, stdout, stderr, on_complete, opts)
  local request = register_request(nil, opts)
  request.handle = vim.system(
    command,
    {
      text = true,
      cwd = vim.fn.getcwd(),
      stdout = stdout,
      stderr = stderr,
    },
    vim.schedule_wrap(function(result)
      unregister_request(request)
      on_complete(result, request)
    end)
  )
end

--- Format opencode's completed process result for display.
--- @param result vim.SystemCompleted
--- @param text string
--- @return string
function M.response_output(result, text)
  if result.code ~= 0 then
    return string.format("opencode exited with code %d\n\n%s", result.code, text)
  end

  if text == "" then
    return "opencode completed without output."
  end

  return text
end

--- Run opencode and return combined stdout/stderr to the callback.
--- @param command string[]
--- @param on_complete fun(result: vim.SystemCompleted, text: string, state: OpenCodeRunState)
--- @param opts? OpenCodeRunOpts
function M.run(command, on_complete, opts)
  local output = {}

  run_process(command, append_output(output), append_output(output), function(result, request)
    local text = combined_output(output, result)
    on_complete(result, readable_output(text), {
      canceled = request.canceled,
    })
  end, opts)
end

--- Run opencode and return raw stdout, preserving stderr for failures.
--- @param command string[]
--- @param on_complete fun(result: vim.SystemCompleted, text: string, state: OpenCodeRunState)
--- @param opts? OpenCodeRunOpts
function M.run_raw(command, on_complete, opts)
  local stdout = {}
  local stderr = {}

  run_process(command, append_output(stdout), append_output(stderr), function(result, request)
    on_complete(result, raw_output(stdout, stderr, result), {
      canceled = request.canceled,
    })
  end, opts)
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
