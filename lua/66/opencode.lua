local config = require("66.config")
local ui = require("66.ui")

local M = {}

--- Drop opencode's captured status prologue from response text.
--- @param text string
--- @return string
local function strip_opencode_prologue(text)
	local lines = vim.split(text, "\n", { plain = true })
	local start = 1

	local function is_ansi_reset_line(line)
		return line:match("^%s*\27%[[%d;]*m%s*$") or line:match("^%s*%[[%d;]*m%s*$")
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
--- @param kind "Ask"|"Search"|"Edit"|"Tutorial"
--- @param text string
--- @return string
local function session_title(kind, text)
	local title = text:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")

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

--- Run opencode and return combined stdout/stderr to the callback.
--- @param command string[]
--- @param on_complete fun(result: vim.SystemCompleted, text: string)
function M.run(command, on_complete)
	local output = {}
	local function append_output(_, data)
		if data and data ~= "" then
			table.insert(output, data)
		end
	end

	vim.system(
		command,
		{
			text = true,
			cwd = vim.fn.getcwd(),
			stdout = append_output,
			stderr = append_output,
		},
		vim.schedule_wrap(function(result)
			local text = table.concat(output, "")
			if text == "" then
				text = result.stdout or result.stderr or ""
			end
			on_complete(result, strip_opencode_prologue(text))
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

	M.run(command, function(result, text)
		stop_timer()

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

		vim.api.nvim_buf_set_lines(response_bufnr, 0, -1, false, vim.split(text, "\n", { plain = true }))
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

--- Build a Project Tutorial session title.
--- @param question string
--- @return string
function M.tutorial_title(question)
	return session_title("Tutorial", question)
end

--- Build an Edit Selection session title.
--- @param instruction string
--- @return string
function M.edit_title(instruction)
	return session_title("Edit", instruction)
end

return M
