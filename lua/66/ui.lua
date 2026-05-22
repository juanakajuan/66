local config = require("66.config")

local M = {}

--- Animated glyphs used by Response View and status throbbers.
M.throbber_frames = { "⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷" }

--- Apply common scratch-buffer options.
--- @param bufnr integer
--- @param buftype string
--- @param filetype string
local function configure_scratch_buffer(bufnr, buftype, filetype)
	vim.bo[bufnr].buftype = buftype
	vim.bo[bufnr].bufhidden = "wipe"
	vim.bo[bufnr].swapfile = false
	vim.bo[bufnr].filetype = filetype
end

--- Name and populate the current scratch buffer.
--- @param name string
--- @param lines string[]
--- @param filetype? string
--- @return integer bufnr
local function prepare_scratch_buffer(name, lines, filetype)
	local bufnr = vim.api.nvim_get_current_buf()

	configure_scratch_buffer(bufnr, "nofile", filetype or "markdown")
	vim.api.nvim_buf_set_name(bufnr, name)
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

	return bufnr
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

--- Open the floating prompt buffer used to collect user questions.
--- @param title string
--- @param name string
--- @return integer bufnr
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

	configure_scratch_buffer(bufnr, "acwrite", "markdown")
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

	configure_scratch_buffer(bufnr, "nofile", "")

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
		frame = frame % #M.throbber_frames + 1
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

return M
