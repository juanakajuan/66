---
name: vim.lsp
description: Reference Neovim's built-in LSP Lua API when editing LSP integration. Use when code touches vim.lsp, LSP clients, requests, formatting, code actions, diagnostics from LSP, semantic tokens, inlay hints, codelens, or LSP utility helpers.
---

# Neovim LSP API

Use built-in `vim.lsp.*` functions for LSP behavior instead of external Lua package assumptions.

## Workflow

- Use `vim.lsp.get_clients`, `vim.lsp.start`, `vim.lsp.enable`, and related client APIs for lifecycle work.
- Use `vim.lsp.buf.*` for buffer-local LSP actions.
- Use `vim.lsp.util.*` for locations, edits, floating previews, markdown conversion, and request parameter helpers.
- Use `vim.lsp.diagnostic.*` only for LSP diagnostic plumbing; use `vim.diagnostic.*` for general diagnostics UI/state.
- Check [REFERENCE.md](REFERENCE.md) for the LSP API dump.
