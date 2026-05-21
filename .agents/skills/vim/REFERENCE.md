# Neovim Lua API Reference

This is intentionally not an exhaustive API dump. Neovim APIs change with the installed version, so prefer live runtime documentation.

## Preferred Sources

- `:help lua-api`
- `:help api`
- `:help vim.system`
- `:help vim.json`
- `nvim --api-info` for machine-readable core API metadata
- `nvim --headless -u NONE -l .agents/skills/vim/scripts/nvim-api-reference.lua` for a local snapshot from the active Neovim

## Common Patterns

```lua
local bufnr = vim.api.nvim_get_current_buf()
local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

local cwd = vim.fn.getcwd()
local timestamp = vim.fn.strftime("%Y-%m-%d %H:%M", vim.fn.localtime())

local decoded = vim.json.decode(text)
local parts = vim.split(text, "\n", { plain = true })

vim.system({ "opencode", "run", prompt }, { text = true }, vim.schedule_wrap(function(result)
	vim.notify(result.stdout or result.stderr or "")
end))
```

## Avoid

- Do not use `os.*`, `io.*`, or `package.*` when Neovim has a direct API.
- Avoid private/internal APIs such as `vim._*` and `nvim__*` unless the task explicitly requires them.
- Do not assume Lua package resolution behaves like a standalone Lua project.
