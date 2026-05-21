local ui = require("66.ui")

local M = {}

local MAX_SESSIONS = 50
local SESSION_TITLE_PREFIX = "[66]"

--- @class OpencodeSession
--- @field id string
--- @field title string
--- @field updated integer
--- @field directory string

--- @class OpencodeMessagePart
--- @field type string
--- @field text? string

--- @class OpencodeMessage
--- @field info { role?: string, time?: { created?: integer } }
--- @field parts OpencodeMessagePart[]

local function decode_json(text)
	local object_start = text:find("{", 1, true)
	local array_start = text:find("[", 1, true)
	local start = object_start
	if array_start and (not start or array_start < start) then
		start = array_start
	end

	if not start then
		return nil
	end

	local ok, decoded = pcall(vim.json.decode, text:sub(start))
	if not ok then
		return nil
	end

	return decoded
end

local function format_time(ms)
	if type(ms) ~= "number" then
		return "unknown time"
	end

	return os.date("%Y-%m-%d %H:%M", math.floor(ms / 1000))
end

--- Return true when the session was created by this plugin.
--- @param session OpencodeSession
--- @return boolean
local function is_66_session(session)
	return type(session.title) == "string" and vim.startswith(session.title, SESSION_TITLE_PREFIX)
end

--- Extract assistant text from an exported opencode session.
--- @param messages OpencodeMessage[]
--- @return string
local function assistant_response(messages)
	local responses = {}
	for _, message in ipairs(messages) do
		local role = message.info and message.info.role or ""
		if role == "assistant" then
			for _, part in ipairs(message.parts or {}) do
				if part.type == "text" and part.text and part.text:gsub("%s", "") ~= "" then
					table.insert(responses, part.text)
				end
			end
		end
	end

	return table.concat(responses, "\n\n")
end

--- @param session OpencodeSession
--- @param exported { info?: { title?: string, time?: { updated?: integer } }, messages?: OpencodeMessage[] }
--- @return string[]
local function render_session(session, exported)
	local info = exported.info or {}
	local messages = exported.messages or {}
	local title = session.title or info.title or session.id
	local response = assistant_response(messages)
	local lines = {
		"# " .. title,
		"",
		"- Updated: " .. format_time(session.updated or (info.time and info.time.updated)),
		"",
	}

	if response == "" then
		table.insert(lines, "No assistant response text found in this session.")
	else
		vim.list_extend(lines, vim.split(response, "\n", { plain = true }))
	end

	return lines
end

local function run_command(command, on_complete)
	local stdout = {}
	local stderr = {}
	vim.system(
		command,
		{
			text = true,
			cwd = vim.fn.getcwd(),
			stdout = function(_, data)
				if data and data ~= "" then
					table.insert(stdout, data)
				end
			end,
			stderr = function(_, data)
				if data and data ~= "" then
					table.insert(stderr, data)
				end
			end,
		},
		vim.schedule_wrap(function(result)
			local text = table.concat(stdout, "")
			if result.code ~= 0 then
				text = text .. table.concat(stderr, "")
			end
			on_complete(result, text)
		end)
	)
end

local function show_error(title, code, text)
	ui.open_scratch_response(
		title,
		vim.split(string.format("opencode exited with code %d\n\n%s", code, text), "\n", {
			plain = true,
		}),
		"markdown"
	)
end

--- @param session OpencodeSession
local function open_session(session)
	local stop_spinner = ui.start_status_spinner("Loading session")
	run_command({ "opencode", "export", session.id }, function(result, text)
		stop_spinner()
		if result.code ~= 0 then
			show_error("66 history error", result.code, text)
			return
		end

		local exported = decode_json(text)
		if type(exported) ~= "table" then
			local lines = { "Could not parse opencode session export.", "" }
			vim.list_extend(lines, vim.split(text, "\n", { plain = true }))
			ui.open_scratch_response("66 history error", lines, "markdown")
			return
		end

		ui.open_scratch_response("66 history", render_session(session, exported), "markdown")
	end)
end

--- @param sessions OpencodeSession[]
local function select_session(sessions)
	vim.ui.select(sessions, {
		prompt = "66 session history",
		format_item = function(session)
			return string.format("%s  %s", format_time(session.updated), session.title or "Untitled")
		end,
	}, function(session)
		if not session then
			return
		end
		open_session(session)
	end)
end

--- Show opencode sessions for the current project and open a selected transcript.
function M.run()
	local stop_spinner = ui.start_status_spinner("Loading history")
	run_command(
		{ "opencode", "session", "list", "--format", "json", "--max-count", tostring(MAX_SESSIONS) },
		function(result, text)
			stop_spinner()
			if result.code ~= 0 then
				show_error("66 history error", result.code, text)
				return
			end

			local sessions = decode_json(text)
			if type(sessions) ~= "table" then
				local lines = { "Could not parse opencode session list.", "" }
				vim.list_extend(lines, vim.split(text, "\n", { plain = true }))
				ui.open_scratch_response("66 history error", lines, "markdown")
				return
			end
			local plugin_sessions = vim.tbl_filter(is_66_session, sessions)
			if #plugin_sessions == 0 then
				vim.notify("No 66 sessions found for this project", vim.log.levels.INFO)
				return
			end

			select_session(plugin_sessions)
		end
	)
end

return M
