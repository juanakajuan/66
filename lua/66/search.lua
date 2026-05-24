local opencode = require("66.opencode")
local prompts = require("66.prompts")
local ui = require("66.ui")

local M = {}

--- @class SearchResult
--- @field filename string Absolute file path for quickfix navigation.
--- @field lnum integer 1-based start line.
--- @field col integer 1-based start column.
--- @field end_lnum integer 1-based end line.
--- @field text string Single-line match explanation.

--- Parse one strict Search Result line into a quickfix item.
--- @param line string `/absolute/path:line:column,count,notes`.
--- @return SearchResult?
local function parse_search_result(line)
  local filepath, lnum_raw, col_raw, count_raw, notes =
    line:match("^(/.*):(%d+):(%d+),(%d+),?(.*)$")
  if not filepath then
    return nil
  end

  local lnum = tonumber(lnum_raw)
  local col = tonumber(col_raw)
  local count = tonumber(count_raw)
  if not lnum or not col or not count then
    return nil
  end

  return {
    filename = filepath,
    lnum = lnum,
    col = col,
    end_lnum = lnum + math.max(count - 1, 0),
    text = notes or "",
  }
end

--- Parse opencode Project Search output into quickfix items.
--- @param text string
--- @return SearchResult[]
local function parse_search_results(text)
  local items = {}
  for _, line in ipairs(vim.split(text, "\n", { trimempty = true })) do
    local item = parse_search_result(vim.trim(line))
    if item then
      table.insert(items, item)
    end
  end
  return items
end

--- Build a bounded quickfix title from the Search Question.
--- @param question string
--- @return string
local function quickfix_title(question)
  local title = question:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  if #title > 80 then
    title = title:sub(1, 77) .. "..."
  end
  return "66 Search: " .. title
end

--- Show unparseable Project Search output in a Response View for debugging.
--- @param question string
--- @param text string
local function show_search_raw_output(question, text)
  if text == "" then
    text = "Project Search completed without parseable Search Results."
  end
  ui.open_scratch_response("66 search output", {
    "No parseable Search Results.",
    "",
    quickfix_title(question),
    "",
    text,
  }, "markdown")
end

--- Show opencode failure output for a Project Search.
--- @param code integer
--- @param text string
local function show_search_error(code, text)
  local lines = vim.split(
    string.format("opencode exited with code %d\n\n%s", code, text),
    "\n",
    { plain = true }
  )
  ui.open_scratch_response("66 search error", lines, "markdown")
end

--- Run a Project Search and populate quickfix with parsed Search Results.
--- @param question string
function M.run(question)
  local stop_throbber = ui.start_status_throbber("Searching")
  local command = opencode.command(prompts.search(question), opencode.search_title(question))

  opencode.run(command, function(result, text, state)
    stop_throbber()

    if state and state.canceled then
      return
    end

    if result.code ~= 0 then
      show_search_error(result.code, text)
      return
    end

    local items = parse_search_results(text)
    if #items == 0 then
      show_search_raw_output(question, text)
      return
    end

    vim.fn.setqflist({}, "r", { title = quickfix_title(question), items = items })
    vim.cmd("copen")
  end, {
    on_cancel = stop_throbber,
  })
end

return M
