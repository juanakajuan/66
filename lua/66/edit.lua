local context = require("66.context")
local opencode = require("66.opencode")
local prompts = require("66.prompts")
local ui = require("66.ui")

local M = {}

local status_namespace = vim.api.nvim_create_namespace("66_edit_status")

--- Show an inline Implementing status around the selected range.
--- @param bufnr integer
--- @param start_line integer 1-based first selected line.
--- @param end_line integer 1-based last selected line.
--- @return fun()
local function start_implementing_status(bufnr, start_line, end_line)
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
    local text = ui.throbber_frames[frame] .. " Implementing"

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

--- Ask Neovim to notice files changed by the external edit process.
--- @param source_bufnr integer
local function refresh_changed_buffers(source_bufnr)
  local ok, err = pcall(function()
    if vim.api.nvim_buf_is_valid(source_bufnr) then
      if vim.bo[source_bufnr].modified then
        vim.cmd("checktime " .. source_bufnr)
      else
        vim.api.nvim_buf_call(source_bufnr, function()
          vim.cmd("silent! edit!")
        end)
      end
    end
    vim.cmd("checktime")
  end)
  if not ok then
    vim.notify("Edit66 could not refresh changed buffers: " .. tostring(err), vim.log.levels.WARN)
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
    local stop_status =
      start_implementing_status(source_bufnr, selection.start_line, selection.end_line)
    local command =
      opencode.command(prompts.edit(instruction, selection), opencode.edit_title(instruction))
    opencode.run(command, function(result, text)
      stop_status()
      refresh_changed_buffers(source_bufnr)

      if result.code ~= 0 then
        show_edit_error(result.code, text)
      end
    end)
  end)
end

return M
