local M = {}

local defaults = {
	model = "openai/gpt-5.5",
	variant = "low",
	agent = "build",
	max_file_lines = 400,
	response_layout = "bottom_split",
	keymap = "<leader>6a",
	search_keymap = "<leader>6s",
}

local config = vim.deepcopy(defaults)
local did_setup = false

local response_layouts = {
	right_split = true,
	bottom_split = true,
	float = true,
	tab = true,
}

local spinner_frames = { "⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷" }

local function normalize_range(bufnr, start_pos, end_pos, selection_mode)
	if start_pos[2] == 0 or end_pos[2] == 0 then
		error("missing visual selection", 0)
	end

	local start_row = start_pos[2] - 1
	local start_col = start_pos[3] - 1
	local end_row = end_pos[2] - 1
	local end_col = end_pos[3]

	if selection_mode == "V" then
		if start_row > end_row then
			start_row, end_row = end_row, start_row
		end

		start_col = 0
		end_col = #(vim.api.nvim_buf_get_lines(bufnr, end_row, end_row + 1, false)[1] or "")
		return start_row, start_col, end_row, end_col
	end

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
	local mode = vim.fn.mode()
	local is_visual = mode == "v" or mode == "V" or mode == "\22"
	local selection_mode = is_visual and mode or vim.fn.visualmode()
	local start_row, start_col, end_row, end_col = normalize_range(
		bufnr,
		vim.fn.getpos(is_visual and "v" or "'<"),
		vim.fn.getpos(is_visual and "." or "'>"),
		selection_mode
	)
	local selected = vim.api.nvim_buf_get_text(bufnr, start_row, start_col, end_row, end_col, {})

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

local function build_search_prompt(question)
	return table.concat({
		"You are performing a read-only Project Search for a Neovim user.",
		"Find code locations in the current project that match the user's Search Question.",
		"Do not edit files. Do not create files. Do not modify buffers.",
		"Return only Search Results. Do not include commentary, markdown, bullets, or code fences.",
		"Each Search Result must use this exact format:",
		"/absolute/path/to/file.ext:line:column,count,notes",
		"line and column are 1-based. count is the number of lines the result covers.",
		"notes must be a single line explaining why the location matched.",
		"If no locations match, return no output.",
		"",
		"Project:",
		vim.fn.getcwd(),
		"",
		"Search Question:",
		question,
	}, "\n")
end

local function prepare_scratch_buffer(name, lines, filetype)
	local bufnr = vim.api.nvim_get_current_buf()

	vim.bo[bufnr].buftype = "nofile"
	vim.bo[bufnr].bufhidden = "wipe"
	vim.bo[bufnr].swapfile = false
	vim.bo[bufnr].filetype = filetype or "markdown"
	vim.api.nvim_buf_set_name(bufnr, name)
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

	return bufnr
end

local function open_scratch_response(name, lines, filetype)
	if config.response_layout == "right_split" then
		vim.cmd("botright vertical new")
	elseif config.response_layout == "bottom_split" then
		vim.cmd("botright new")
	elseif config.response_layout == "tab" then
		vim.cmd("tabnew")
	elseif config.response_layout == "float" then
		local bufnr = vim.api.nvim_create_buf(false, true)
		local width = math.min(100, math.max(50, math.floor(vim.o.columns * 0.75)))
		local height = math.min(30, math.max(10, math.floor(vim.o.lines * 0.65)))

		vim.api.nvim_open_win(bufnr, true, {
			relative = "editor",
			style = "minimal",
			border = "rounded",
			title = " 66 response ",
			title_pos = "center",
			width = width,
			height = height,
			row = math.floor((vim.o.lines - height) / 2),
			col = math.floor((vim.o.columns - width) / 2),
		})
	end

	return prepare_scratch_buffer(name, lines, filetype)
end

local function open_prompt_float(title, name)
	local bufnr = vim.api.nvim_create_buf(false, true)
	local width = math.min(80, math.max(40, math.floor(vim.o.columns * 0.7)))
	local height = math.min(12, math.max(6, math.floor(vim.o.lines * 0.3)))

	vim.api.nvim_open_win(bufnr, true, {
		relative = "editor",
		style = "minimal",
		border = "rounded",
		title = title,
		title_pos = "center",
		footer = " :w send  :q close ",
		footer_pos = "center",
		width = width,
		height = height,
		row = math.floor((vim.o.lines - height) / 2),
		col = math.floor((vim.o.columns - width) / 2),
	})

	vim.bo[bufnr].buftype = "acwrite"
	vim.bo[bufnr].bufhidden = "wipe"
	vim.bo[bufnr].swapfile = false
	vim.bo[bufnr].filetype = "markdown"
	vim.api.nvim_buf_set_name(bufnr, name)
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
	vim.bo[bufnr].modified = false

	return bufnr
end

local function start_status_spinner(label)
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

	vim.bo[bufnr].buftype = "nofile"
	vim.bo[bufnr].bufhidden = "wipe"
	vim.bo[bufnr].swapfile = false

	local function render()
		if not running then
			return
		end
		if not vim.api.nvim_buf_is_valid(bufnr) or not vim.api.nvim_win_is_valid(winid) then
			running = false
			return
		end

		local text = string.format("%s %s", spinner_frames[frame], label)
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { text })
		frame = frame % #spinner_frames + 1
		vim.defer_fn(render, 120)
	end

	render()

	return function()
		running = false
		if vim.api.nvim_win_is_valid(winid) then
			vim.api.nvim_win_close(winid, true)
		end
		if vim.api.nvim_buf_is_valid(bufnr) then
			vim.api.nvim_buf_delete(bufnr, { force = true })
		end
	end
end

--- Drop opencode's captured status prologue from response text.
local function strip_opencode_prologue(text)
	local lines = vim.split(text, "\n", { plain = true })
	local start = 1
	local function is_ansi_reset_line(line)
		return line:match("^%s*\27%[[%d;]*m%s*$") or line:match("^%s*%[[%d;]*m%s*$")
	end

	while lines[start] and is_ansi_reset_line(lines[start]) do
		start = start + 1
	end

	if lines[start] and lines[start]:match("^%s*>%s+[%w_-]+%s+·%s+.+%s*$") then
		start = start + 1
	end

	while lines[start] and is_ansi_reset_line(lines[start]) do
		start = start + 1
	end

	return table.concat(vim.list_slice(lines, start), "\n")
end

local function opencode_command(prompt)
	return {
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
end

local function run_opencode(command, on_complete)
	local output = {}
	vim.system(
		command,
		{
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

local function show_response(command)
	local frame = 1
	local timer = assert(vim.uv.new_timer(), "failed to create response spinner timer")
	local running = true

	local function stop_timer()
		if not running then
			return
		end

		running = false
		timer:stop()
		timer:close()
	end

	local response_bufnr = open_scratch_response("66 response", {
		spinner_frames[frame] .. " Loading...",
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

			frame = frame % #spinner_frames + 1
			vim.api.nvim_buf_set_lines(response_bufnr, 0, 1, false, {
				spinner_frames[frame] .. " Loading...",
			})
		end)
	)

	run_opencode(command, function(result, text)
		stop_timer()

		if not vim.api.nvim_buf_is_valid(response_bufnr) then
			return
		end

		if result.code ~= 0 then
			text = string.format("opencode exited with code %d\n\n%s", result.code, text)
		end
		if text == "" then
			text = "opencode completed without output."
		end

		vim.api.nvim_buf_set_lines(response_bufnr, 0, -1, false, vim.split(text, "\n", { plain = true }))
	end)
end

local function parse_search_result(line)
	local filepath, lnum_raw, col_raw, count_raw, notes = line:match("^(/.*):(%d+):(%d+),(%d+),?(.*)$")
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

local function quickfix_title(question)
	local title = question:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
	if #title > 80 then
		title = title:sub(1, 77) .. "..."
	end
	return "66 Search: " .. title
end

local function show_search_raw_output(question, text)
	if text == "" then
		text = "Project Search completed without parseable Search Results."
	end
	open_scratch_response("66 search output", {
		"No parseable Search Results.",
		"",
		quickfix_title(question),
		"",
		text,
	}, "markdown")
end

local function show_search_error(code, text)
	local lines = vim.split(string.format("opencode exited with code %d\n\n%s", code, text), "\n", { plain = true })
	open_scratch_response("66 search error", lines, "markdown")
end

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

local function capture_prompt(title, name, label, on_submit)
	local prompt_bufnr = open_prompt_float(title, name)

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

--- Ask opencode about the current visual selection without editing source buffers.
function M.ask()
	local ok, context = pcall(selection_context)
	if not ok then
		vim.notify("Ask66 requires a visual selection", vim.log.levels.ERROR)
		return
	end

	capture_prompt(" 66 ask ", "66 ask", "Ask66", function(question)
		show_response(opencode_command(build_prompt(question, context)))
	end)
end

--- Search the current project and open matching locations in quickfix.
function M.search()
	capture_prompt(" 66 search ", "66 search", "Search66", function(question)
		local stop_spinner = start_status_spinner("Searching")
		run_opencode(opencode_command(build_search_prompt(question)), function(result, text)
			stop_spinner()

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
		end)
	end)
end

--- Configure the 66 prototype.
--- @param opts? { model?: string, variant?: string, agent?: string, max_file_lines?: integer, response_layout?: "right_split"|"bottom_split"|"float"|"tab", keymap?: string|false, search_keymap?: string|false }
function M.setup(opts)
	config = vim.tbl_deep_extend("force", defaults, opts or {})
	if not response_layouts[config.response_layout] then
		error("invalid 66 response_layout: " .. tostring(config.response_layout), 0)
	end

	vim.api.nvim_create_user_command("Ask66", function()
		M.ask()
	end, { desc = "Ask opencode about the visual selection", range = true })

	vim.api.nvim_create_user_command("Search66", function()
		M.search()
	end, { desc = "Search the current project with opencode" })

	if config.keymap and not did_setup then
		vim.keymap.set("v", config.keymap, function()
			M.ask()
		end, { desc = "66 ask about selection" })
	end

	if config.search_keymap and not did_setup then
		vim.keymap.set("n", config.search_keymap, function()
			M.search()
		end, { desc = "66 search project" })
	end

	did_setup = true
end

return M
