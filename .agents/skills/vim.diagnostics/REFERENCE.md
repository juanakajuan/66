# Neovim Diagnostics API Reference

This is intentionally not an exhaustive API dump. Use the active Neovim runtime docs for exact signatures.

## Preferred Sources

- `:help diagnostic-api`
- `:help vim.diagnostic`
- `:help diagnostic-quickfix`
- `:help diagnostic-handlers`

## Common Patterns

```lua
local ns = vim.api.nvim_create_namespace("66")

vim.diagnostic.set(ns, bufnr, diagnostics, opts)
local current = vim.diagnostic.get(bufnr, { namespace = ns })
vim.diagnostic.reset(ns, bufnr)

vim.diagnostic.open_float({ scope = "cursor" })
vim.diagnostic.setqflist({ title = "66 diagnostics" })
```

## Avoid

- Do not implement custom diagnostic storage when `vim.diagnostic` covers the lifecycle.
- Do not use private diagnostic internals unless the task explicitly requires them.
- Keep plugin-owned diagnostics in a namespace.
