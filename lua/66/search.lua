local opencode = require("66.opencode")
local prompts = require("66.prompts")
local ui = require("66.ui")

local M = {}

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
	ui.open_scratch_response("66 search output", {
		"No parseable Search Results.",
		"",
		quickfix_title(question),
		"",
		text,
	}, "markdown")
end

local function show_search_error(code, text)
	local lines = vim.split(string.format("opencode exited with code %d\n\n%s", code, text), "\n", { plain = true })
	ui.open_scratch_response("66 search error", lines, "markdown")
end

--- Run a Project Search and populate quickfix with parsed Search Results.
--- @param question string
function M.run(question)
	local stop_spinner = ui.start_status_spinner("Searching")
	opencode.run(opencode.command(prompts.search(question)), function(result, text)
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
end

return M
