---
name: vim.diagnostics
description: Reference Neovim's diagnostics Lua API when editing diagnostic behavior. Use when code touches vim.diagnostic, namespaces, diagnostic display, virtual text, virtual lines, signs, floating diagnostics, quickfix, loclist, or diagnostic navigation.
---

# Neovim Diagnostics API

Use `vim.diagnostic.*` for diagnostics instead of custom storage or external Lua packages.

## Workflow

- Use diagnostic namespaces for plugin-owned diagnostics.
- Use `vim.diagnostic.set`, `get`, `reset`, `show`, and `hide` for diagnostic lifecycle.
- Use `vim.diagnostic.open_float`, `setqflist`, and `setloclist` for user-facing diagnostic output.
- Use `vim.diagnostic.jump` or navigation helpers for diagnostic movement.
- Check [REFERENCE.md](REFERENCE.md) for the diagnostics API dump.
