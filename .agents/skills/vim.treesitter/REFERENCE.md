# Neovim Treesitter API Reference

This is intentionally not an exhaustive API dump. Use the active Neovim runtime docs for exact signatures.

## Preferred Sources

- `:help treesitter`
- `:help lua-treesitter`
- `:help treesitter-query`
- `:help vim.treesitter`

## Common Patterns

```lua
local parser = vim.treesitter.get_parser(bufnr, filetype)
local tree = parser:parse()[1]
local root = tree:root()

for child in root:iter_children() do
	local start_row, start_col, end_row, end_col = child:range()
	local node_type = child:type()
end
```

## Avoid

- Do not depend on private `vim._*` Treesitter helpers unless the task explicitly requires them.
- Do not assume parser availability without handling missing parsers.
- Keep query behavior tied to Neovim runtime files when possible.
