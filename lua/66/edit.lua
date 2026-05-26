local context = require("66.context")
local opencode = require("66.opencode")
local prompts = require("66.prompts")
local ui = require("66.ui")

local M = {}

local status_namespace = vim.api.nvim_create_namespace("66_edit_status")
local range_namespace = vim.api.nvim_create_namespace("66_edit_range")

--- @class EditRangeTracker
--- @field start_id integer
--- @field end_id integer

--- Track the selected lines while the user keeps editing the buffer.
--- @param bufnr integer
--- @param start_line integer 1-based first selected line.
--- @param end_line integer 1-based last selected line.
--- @return EditRangeTracker
local function track_edit_range(bufnr, start_line, end_line)
  local start_id = vim.api.nvim_buf_set_extmark(bufnr, range_namespace, start_line - 1, 0, {
    right_gravity = false,
  })
  local end_id = vim.api.nvim_buf_set_extmark(bufnr, range_namespace, end_line - 1, 0, {
    right_gravity = true,
  })

  return {
    start_id = start_id,
    end_id = end_id,
  }
end

--- @param bufnr integer
--- @param tracker EditRangeTracker
local function clear_edit_range(bufnr, tracker)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  vim.api.nvim_buf_del_extmark(bufnr, range_namespace, tracker.start_id)
  vim.api.nvim_buf_del_extmark(bufnr, range_namespace, tracker.end_id)
end

--- Find the minimal changed line range between the original and edited file.
--- @param before string[]
--- @param after string[]
--- @return integer? old_start zero-based inclusive
--- @return integer? old_end zero-based exclusive
--- @return integer? new_start zero-based inclusive
--- @return integer? new_end zero-based exclusive
local function changed_range(before, after)
  local prefix = 0
  while before[prefix + 1] ~= nil and before[prefix + 1] == after[prefix + 1] do
    prefix = prefix + 1
  end

  local suffix = 0
  while #before - suffix > prefix and #after - suffix > prefix do
    if before[#before - suffix] ~= after[#after - suffix] then
      break
    end
    suffix = suffix + 1
  end

  local old_start = prefix
  local old_end = #before - suffix
  local new_start = prefix
  local new_end = #after - suffix

  if old_start == old_end and new_start == new_end then
    return nil, nil, nil, nil
  end

  return old_start, old_end, new_start, new_end
end

--- @class EditChangeHunk
--- @field old_start integer vim.diff old start index, 1-based except 0 for insertions at file start.
--- @field old_count integer
--- @field new_start integer vim.diff new start index, 1-based except 0 for deletions at file start.
--- @field new_count integer

--- Find changed line hunks between the original and edited file.
--- @param before string[]
--- @param after string[]
--- @return EditChangeHunk[]
local function changed_hunks(before, after)
  local hunks = vim.text.diff(table.concat(before, "\n"), table.concat(after, "\n"), {
    result_type = "indices",
  })
  if type(hunks) ~= "table" then
    return {}
  end

  local changes = {}

  for _, hunk in ipairs(hunks) do
    table.insert(changes, {
      old_start = hunk[1],
      old_count = hunk[2],
      new_start = hunk[3],
      new_count = hunk[4],
    })
  end

  return changes
end

--- @param hunk EditChangeHunk
--- @param selection SelectionContext
--- @return boolean
local function hunk_is_outside_selection(hunk, selection)
  if hunk.old_count == 0 then
    return hunk.old_start < selection.start_line or hunk.old_start >= selection.end_line
  end

  local old_end = hunk.old_start + hunk.old_count - 1
  return hunk.old_start < selection.start_line or old_end > selection.end_line
end

--- @param selection SelectionContext
--- @return string
local function outside_changes_title(selection)
  return string.format(
    "66 Edit: outside selected lines %d-%d",
    selection.start_line,
    selection.end_line
  )
end

--- @param items table[]
--- @param selection SelectionContext
--- @param line_count integer
--- @param lnum integer
--- @param count integer
local function add_outside_change_item(items, selection, line_count, lnum, count)
  local clamped_lnum = math.min(math.max(lnum, 1), line_count)
  table.insert(items, {
    filename = selection.path,
    lnum = clamped_lnum,
    col = 1,
    end_lnum = count > 0 and math.min(clamped_lnum + count - 1, line_count) or clamped_lnum,
    text = outside_changes_title(selection),
  })
end

--- @param items table[]
--- @param selection SelectionContext
--- @param line_count integer
--- @param hunk EditChangeHunk
local function add_outside_change_items(items, selection, line_count, hunk)
  if not hunk_is_outside_selection(hunk, selection) then
    return
  end

  if hunk.old_count == 0 then
    add_outside_change_item(items, selection, line_count, hunk.new_start, hunk.new_count)
    return
  end

  local old_end = hunk.old_start + hunk.old_count - 1
  if old_end < selection.start_line or hunk.old_start > selection.end_line then
    add_outside_change_item(items, selection, line_count, hunk.new_start, hunk.new_count)
    return
  end

  if hunk.old_start < selection.start_line then
    local old_count = selection.start_line - hunk.old_start
    add_outside_change_item(
      items,
      selection,
      line_count,
      hunk.new_start,
      math.min(old_count, hunk.new_count)
    )
  end

  if old_end > selection.end_line then
    local old_count = old_end - selection.end_line
    local new_count = math.min(old_count, hunk.new_count)
    add_outside_change_item(
      items,
      selection,
      line_count,
      hunk.new_start + math.max(hunk.new_count - new_count, 0),
      new_count
    )
  end
end

--- @param selection SelectionContext
--- @param edited_lines string[]
--- @param hunks EditChangeHunk[]
local function show_outside_changes(selection, edited_lines, hunks)
  local items = {}
  local line_count = math.max(#edited_lines, 1)

  for _, hunk in ipairs(hunks) do
    add_outside_change_items(items, selection, line_count, hunk)
  end

  if #items == 0 then
    return
  end

  vim.fn.setqflist({}, "r", { title = outside_changes_title(selection), items = items })
  vim.cmd("copen")
end

--- Translate the original file diff range into the current live-buffer range.
---
--- The user may keep editing while opencode runs. Extmarks preserve the selected
--- block's current position so the changed source can be applied without
--- reloading the buffer and discarding unrelated live edits.
--- @param bufnr integer
--- @param tracker EditRangeTracker
--- @param selection SelectionContext
--- @param old_start integer zero-based inclusive
--- @param old_end integer zero-based exclusive
--- @return integer start_row zero-based inclusive
--- @return integer end_row zero-based exclusive
local function current_apply_range(bufnr, tracker, selection, old_start, old_end)
  local selection_start = selection.start_line - 1
  local selection_end = selection.end_line
  local start_pos = vim.api.nvim_buf_get_extmark_by_id(bufnr, range_namespace, tracker.start_id, {})
  local end_pos = vim.api.nvim_buf_get_extmark_by_id(bufnr, range_namespace, tracker.end_id, {})
  local start_row = start_pos[1] or selection_start
  local end_row = (end_pos[1] and end_pos[1] + 1) or selection_end
  local line_count = vim.api.nvim_buf_line_count(bufnr)

  return math.max(0, math.min(start_row + old_start - selection_start, line_count)),
    math.max(0, math.min(end_row + old_end - selection_end, line_count))
end

--- Apply the source-file edit back into the live buffer without reloading it.
---
--- opencode edits the file on disk. 66 reads that changed file, finds the
--- minimal changed range, and patches only the corresponding live-buffer lines.
--- @param source_bufnr integer
--- @param selection SelectionContext
--- @param tracker EditRangeTracker
--- @param original_lines string[]
local function apply_changed_source(source_bufnr, selection, tracker, original_lines)
  if selection.path == "" or not vim.api.nvim_buf_is_valid(source_bufnr) then
    return
  end

  local ok, err = pcall(function()
    local edited_lines = vim.fn.readfile(selection.path)
    local hunks = changed_hunks(original_lines, edited_lines)
    local old_start, old_end, new_start, new_end = changed_range(original_lines, edited_lines)
    if not old_start or not old_end or not new_start or not new_end then
      return
    end

    local start_row, end_row =
      current_apply_range(source_bufnr, tracker, selection, old_start, old_end)
    vim.api.nvim_buf_set_lines(
      source_bufnr,
      start_row,
      end_row,
      false,
      vim.list_slice(edited_lines, new_start + 1, new_end)
    )
    vim.api.nvim_buf_call(source_bufnr, function()
      vim.cmd("silent noautocmd write!")
    end)
    show_outside_changes(selection, edited_lines, hunks)
  end)
  if not ok then
    vim.notify("Edit66 could not apply changed source: " .. tostring(err), vim.log.levels.WARN)
  end
end

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
    local original_lines = vim.api.nvim_buf_get_lines(source_bufnr, 0, -1, false)
    local tracker = track_edit_range(source_bufnr, selection.start_line, selection.end_line)
    local stop_status = ui.start_inline_status(
      source_bufnr,
      status_namespace,
      selection.start_line,
      selection.end_line,
      "Implementing"
    )
    local command =
      opencode.command(prompts.edit(instruction, selection), opencode.edit_title(instruction))

    opencode.run(command, function(result, text, state)
      stop_status()
      clear_edit_range(source_bufnr, tracker)

      if state and state.canceled then
        return
      end

      if result.code ~= 0 then
        show_edit_error(result.code, text)
        return
      end

      apply_changed_source(source_bufnr, selection, tracker, original_lines)
    end, {
      on_cancel = function()
        stop_status()
        clear_edit_range(source_bufnr, tracker)
      end,
    })
  end)
end

return M
