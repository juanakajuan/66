local opencode = require("66.opencode")
local prompts = require("66.prompts")
local ui = require("66.ui")

local M = {}

--- Read generated Tutorial Output from disk.
--- @param path string
--- @return string
local function read_tutorial_output(path)
  if vim.fn.filereadable(path) == 0 then
    return ""
  end

  return table.concat(vim.fn.readfile(path), "\n")
end

--- Run a Project Tutorial and open the markdown output in a Response View.
--- @param question string User-authored Tutorial Question.
function M.run(question)
  local output_path = vim.fn.tempname() .. ".md"
  local command =
    opencode.command(prompts.tutorial(question, output_path), opencode.tutorial_title(question))
  local stop_throbber = ui.start_status_throbber("Generating tutorial")

  opencode.run(command, function(result, text)
    stop_throbber()

    local output = read_tutorial_output(output_path)
    vim.fn.delete(output_path)

    if result.code ~= 0 then
      output = string.format("opencode exited with code %d\n\n%s", result.code, text)
    elseif output == "" then
      output = "opencode completed without tutorial output."
    end

    ui.open_scratch_response("66 tutorial", vim.split(output, "\n", { plain = true }), "markdown")
  end)
end

return M
