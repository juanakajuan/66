local config = require("66.config")

local M = {}

--- Animated glyphs used by Response View and status throbbers.
M.throbber_frames = { "⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷" }

--- @param frame integer
--- @return integer
local function next_throbber_frame(frame)
  return frame % #M.throbber_frames + 1
end

--- @param bufnr integer
--- @param buftype string
--- @param filetype string
local function configure_scratch_buf(bufnr, buftype, filetype)
  vim.bo[bufnr].buftype = buftype
  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].filetype = filetype
end

--- @param name string
--- @param lines string[]
--- @param filetype? string
--- @return integer bufnr
local function prepare_scratch_buf(name, lines, filetype)
  local bufnr = vim.api.nvim_get_current_buf()

  configure_scratch_buf(bufnr, "nofile", filetype or "markdown")
  vim.api.nvim_buf_set_name(bufnr, name)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  return bufnr
end

--- @class CenteredFloatConfig
--- @field width integer
--- @field height integer
--- @field title? string
--- @field title_pos? string
--- @field footer? string
--- @field footer_pos? string

--- @param bufnr integer
--- @param opts CenteredFloatConfig
local function open_centered_floating_win(bufnr, opts)
  vim.api.nvim_open_win(
    bufnr,
    true,
    vim.tbl_extend("force", {
      relative = "editor",
      style = "minimal",
      border = "rounded",
      row = math.floor((vim.o.lines - opts.height) / 2),
      col = math.floor((vim.o.columns - opts.width) / 2),
    }, opts)
  )
end

--- @param bufnr integer
--- @param winid integer
local function close_floating_win(bufnr, winid)
  if vim.api.nvim_win_is_valid(winid) then
    vim.api.nvim_win_close(winid, true)
  end
  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
end

--- Open a scratch Response View using the configured layout.
--- @param name string
--- @param lines string[]
--- @param filetype? string
--- @return integer
function M.open_scratch_response(name, lines, filetype)
  local opts = config.options()
  if opts.response_layout == "right_split" then
    vim.cmd("botright vertical new")
  elseif opts.response_layout == "bottom_split" then
    vim.cmd("botright new")
  elseif opts.response_layout == "tab" then
    vim.cmd("tabnew")
  elseif opts.response_layout == "float" then
    local bufnr = vim.api.nvim_create_buf(false, true)
    local width = math.min(100, math.max(50, math.floor(vim.o.columns * 0.75)))
    local height = math.min(30, math.max(10, math.floor(vim.o.lines * 0.65)))

    open_centered_floating_win(bufnr, {
      title = " 66 response ",
      title_pos = "center",
      width = width,
      height = height,
    })
  end

  return prepare_scratch_buf(name, lines, filetype)
end

--- @param title string
--- @param name string
--- @return integer bufnr
local function open_prompt(title, name)
  local bufnr = vim.api.nvim_create_buf(false, true)
  local width = math.min(80, math.max(40, math.floor(vim.o.columns * 0.7)))
  local height = math.min(12, math.max(6, math.floor(vim.o.lines * 0.3)))

  open_centered_floating_win(bufnr, {
    title = title,
    title_pos = "center",
    footer = " :w send  :q close ",
    footer_pos = "center",
    width = width,
    height = height,
  })

  configure_scratch_buf(bufnr, "acwrite", "markdown")
  vim.api.nvim_buf_set_name(bufnr, name)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
  vim.bo[bufnr].modified = false

  return bufnr
end

--- Read and submit prompt-buffer text.
--- @param prompt_bufnr integer
--- @param label string
--- @param on_submit fun(question: string)
local function submit_prompt(prompt_bufnr, label, on_submit)
  local question = table.concat(vim.api.nvim_buf_get_lines(prompt_bufnr, 0, -1, false), "\n")
  if question:gsub("%s", "") == "" then
    vim.notify(label .. " cancelled: question is empty", vim.log.levels.WARN)
    return
  end

  vim.bo[prompt_bufnr].modified = false
  vim.cmd("close")
  on_submit(question)
end

--- Capture a user prompt from a floating buffer and submit it on write.
--- @param title string
--- @param name string
--- @param label string
--- @param on_submit fun(question: string)
function M.capture_prompt(title, name, label, on_submit)
  local prompt_bufnr = open_prompt(title, name)

  -- Don't ask if we want to save the prompt buffer when closing.
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    buffer = prompt_bufnr,
    callback = function()
      if vim.api.nvim_buf_is_valid(prompt_bufnr) then
        vim.bo[prompt_bufnr].modified = false
      end
    end,
  })

  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = prompt_bufnr,
    once = true,
    callback = function()
      submit_prompt(prompt_bufnr, label, on_submit)
    end,
  })

  vim.cmd("startinsert")
end

--- Start an inline status throbber around a 1-based line range.
--- @param bufnr integer
--- @param namespace integer
--- @param start_line integer 1-based first selected line.
--- @param end_line integer 1-based last selected line.
--- @param label string
--- @return fun()
function M.start_inline_status(bufnr, namespace, start_line, end_line, label)
  local running = true
  local frame = 1
  local top_id
  local bottom_id

  local function clear()
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
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
    return vim.api.nvim_buf_set_extmark(bufnr, namespace, row, 0, opts)
  end

  local function render()
    if not running or not vim.api.nvim_buf_is_valid(bufnr) then
      return
    end

    local line_count = vim.api.nvim_buf_line_count(bufnr)
    local top_row = math.max(0, math.min(start_line - 1, line_count - 1))
    local bottom_row = math.max(0, math.min(end_line - 1, line_count - 1))
    local text = M.throbber_frames[frame] .. " " .. label

    top_id = set_extmark(top_row, top_id, text, true)
    bottom_id = set_extmark(bottom_row, bottom_id, text, false)
    frame = next_throbber_frame(frame)
    vim.defer_fn(render, 120)
  end

  render()

  return function()
    running = false
    clear()
  end
end

--- Start a floating status throbber and return its stop callback.
--- @param label string
--- @return fun()
function M.start_status_throbber(label)
  local width = math.max(18, #label + 6)
  local bufnr = vim.api.nvim_create_buf(false, true)
  local winid = vim.api.nvim_open_win(bufnr, false, {
    relative = "editor",
    style = "minimal",
    border = "rounded",
    width = width,
    height = 1,
    row = 0,
    col = vim.o.columns,
    anchor = "NE",
    zindex = 50,
  })
  local running = true
  local frame = 1

  configure_scratch_buf(bufnr, "nofile", "")

  local function render()
    if not running then
      return
    end
    if not vim.api.nvim_buf_is_valid(bufnr) or not vim.api.nvim_win_is_valid(winid) then
      running = false
      return
    end

    local text = string.format("%s %s", M.throbber_frames[frame], label)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { text })
    frame = next_throbber_frame(frame)
    vim.defer_fn(render, 120)
  end

  render()

  return function()
    running = false
    close_floating_win(bufnr, winid)
  end
end

return M
