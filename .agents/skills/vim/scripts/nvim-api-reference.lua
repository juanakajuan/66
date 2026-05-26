local version = vim.version()

local function line(text)
	vim.api.nvim_echo({ { text } }, false, {})
end

line("# Active Neovim API Reference")
line("")
line(string.format("Neovim: %d.%d.%d", version.major, version.minor, version.patch))
line("")
line("Use these live docs instead of static committed API dumps:")
line("")
line("- :help lua-api")
line("- :help api")
line("- :help vim.system")
line("- :help vim.json")
line("- :help lsp")
line("- :help diagnostic-api")
line("- :help lua-treesitter")
line("")
line("Core API functions exposed by this Neovim:")
line("")

local api_info = vim.fn.api_info()
local functions = api_info.functions or {}
table.sort(functions, function(left, right)
	return left.name < right.name
end)

for _, fn in ipairs(functions) do
	if not fn.name:match("^nvim__") then
		line("- " .. fn.name)
	end
end
