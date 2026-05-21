# Neovim LSP API Reference

This is intentionally not an exhaustive API dump. Use the active Neovim runtime docs for exact signatures.

## Preferred Sources

- `:help lsp`
- `:help vim.lsp`
- `:help lsp-config`
- `:help lsp-buf`
- `:help lsp-util`

## Common Patterns

```lua
local clients = vim.lsp.get_clients({ bufnr = bufnr })

vim.lsp.buf.hover()
vim.lsp.buf.definition()
vim.lsp.buf.references()
vim.lsp.buf.format({ async = true })

local params = vim.lsp.util.make_position_params(0, client.offset_encoding)
```

## Avoid

- Do not use external LSP helper packages unless the project already depends on them.
- Do not use private `vim.lsp._*` APIs unless the task explicitly requires them.
- Prefer `vim.diagnostic.*` for diagnostic UI/state rather than LSP diagnostic internals.
