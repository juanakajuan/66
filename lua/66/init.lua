local M = {}

local defaults = {
  model = "openai/gpt-5.5",
  variant = "low",
  agent = "build",
  max_file_lines = 400,
  keymap = "<leader>6a",
}

local config = vim.deepcopy(defaults)
local did_setup = false

local function normalize_range(start_pos, end_pos)
  local start_row = start_pos[2] - 1
  local start_col = start_pos[3] - 1
  local end_row = end_pos[2] - 1
  local end_col = end_pos[3]

  if start_row > end_row or (start_row == end_row and start_col > end_col) then
    start_row, end_row = end_row, start_row
    start_col, end_col = end_col - 1, start_col + 1
  end

  return start_row, start_col, end_row, end_col
end

local function with_line_numbers(lines, start_line)
  local numbered = {}
  for index, line in ipairs(lines) do
    numbered[index] = string.format("%d: %s", start_line + index - 1, line)
  end
  return table.concat(numbered, "\n")
end

local function current_file_context(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  if #lines > config.max_file_lines then
    return string.format(
      "Current file omitted because it has %d lines, over the %d line limit.",
      #lines,
      config.max_file_lines
    )
  end

  return with_line_numbers(lines, 1)
end

local function selection_context()
  local bufnr = vim.api.nvim_get_current_buf()
  local start_row, start_col, end_row, end_col = normalize_range(
    vim.fn.getpos("'<"),
    vim.fn.getpos("'>")
  )
  local selected = vim.api.nvim_buf_get_text(
    bufnr,
    start_row,
    start_col,
    end_row,
    end_col,
    {}
  )

  return {
    path = vim.api.nvim_buf_get_name(bufnr),
    filetype = vim.bo[bufnr].filetype,
    start_line = start_row + 1,
    end_line = end_row + 1,
    selected = with_line_numbers(selected, start_row + 1),
    current_file = current_file_context(bufnr),
  }
end

local function build_prompt(question, context)
  return table.concat({
    "You are answering a question about a visual selection from a Neovim buffer.",
    "This is read-only. Do not edit files. Answer directly and reference relevant lines when useful.",
    "",
    "Question:",
    question,
    "",
    "File path:",
    context.path ~= "" and context.path or "[No file path]",
    "",
    "Filetype:",
    context.filetype ~= "" and context.filetype or "[No filetype]",
    "",
    string.format("Selected lines: %d-%d", context.start_line, context.end_line),
    "",
    "Selected code:",
    "```" .. (context.filetype or ""),
    context.selected,
    "```",
    "",
    "Current file context:",
    "```" .. (context.filetype or ""),
    context.current_file,
    "```",
  }, "\n")
end

local function open_scratch_split(name, lines, filetype)
  vim.cmd("botright vertical new")
  local bufnr = vim.api.nvim_get_current_buf()
  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].filetype = filetype or "markdown"
  vim.api.nvim_buf_set_name(bufnr, name)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  return bufnr
end

local function show_response(command)
  local response_bufnr = open_scratch_split("66 response", {
    "Loading...",
    "",
    table.concat(vim.list_slice(command, 1, #command - 1), " "),
  }, "markdown")

  local output = {}
  vim.system(command, {
    text = true,
    cwd = vim.fn.getcwd(),
    stdout = function(_, data)
      if data and data ~= "" then
        table.insert(output, data)
      end
    end,
    stderr = function(_, data)
      if data and data ~= "" then
        table.insert(output, data)
      end
    end,
  }, vim.schedule_wrap(function(result)
    if not vim.api.nvim_buf_is_valid(response_bufnr) then
      return
    end

    local text = table.concat(output, "")
    if text == "" then
      text = result.stdout or result.stderr or ""
    end
    if result.code ~= 0 then
      text = string.format("opencode exited with code %d\n\n%s", result.code, text)
    end
    if text == "" then
      text = "opencode completed without output."
    end

    vim.api.nvim_buf_set_lines(
      response_bufnr,
      0,
      -1,
      false,
      vim.split(text, "\n", { plain = true })
    )
  end))
end

local function submit_prompt(prompt_bufnr, context)
  local question = table.concat(
    vim.api.nvim_buf_get_lines(prompt_bufnr, 0, -1, false),
    "\n"
  )
  if question:gsub("%s", "") == "" then
    vim.notify("Ask66 cancelled: question is empty", vim.log.levels.WARN)
    return
  end

  local prompt = build_prompt(question, context)
  local command = {
    "opencode",
    "run",
    "--agent",
    config.agent,
    "-m",
    config.model,
    "--variant",
    config.variant,
    prompt,
  }

  vim.cmd("close")
  show_response(command)
end

--- Ask opencode about the current visual selection without editing source buffers.
function M.ask()
  local ok, context = pcall(selection_context)
  if not ok then
    vim.notify("Ask66 requires a visual selection", vim.log.levels.ERROR)
    return
  end

  vim.cmd("botright 8new")
  local prompt_bufnr = vim.api.nvim_get_current_buf()
  vim.bo[prompt_bufnr].buftype = "acwrite"
  vim.bo[prompt_bufnr].bufhidden = "wipe"
  vim.bo[prompt_bufnr].swapfile = false
  vim.bo[prompt_bufnr].filetype = "markdown"
  vim.api.nvim_buf_set_name(prompt_bufnr, "66 ask")
  vim.api.nvim_buf_set_lines(prompt_bufnr, 0, -1, false, {
    "Ask about the selected code, then write this buffer to submit.",
    "",
  })
  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = prompt_bufnr,
    once = true,
    callback = function()
      submit_prompt(prompt_bufnr, context)
    end,
  })
end

--- Configure the 66 prototype.
--- @param opts? { model?: string, variant?: string, agent?: string, max_file_lines?: integer, keymap?: string|false }
function M.setup(opts)
  config = vim.tbl_deep_extend("force", defaults, opts or {})

  vim.api.nvim_create_user_command("Ask66", function()
    M.ask()
  end, { desc = "Ask opencode about the visual selection", range = true })

  if config.keymap and not did_setup then
    vim.keymap.set("v", config.keymap, function()
      M.ask()
    end, { desc = "66 ask about selection" })
  end

  did_setup = true
end

return M
