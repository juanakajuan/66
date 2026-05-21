---
name: vim
description: Reference Neovim's core Lua API and built-in helpers when editing this Neovim plugin. Use when writing Lua code that touches buffers, windows, commands, autocmds, options, JSON, jobs, paths, strings, lists, tables, or other vim.* APIs.
---

# Neovim Lua API

Use Neovim-provided functions before Lua stdlib or package-resolution assumptions.

## Workflow

- Prefer `vim.api.*` for editor state, buffers, windows, commands, namespaces, extmarks, highlights, and autocmds.
- Prefer `vim.fn.*` for Vimscript-compatible utilities such as `strftime`, `getcwd`, `mode`, `getpos`, and quickfix helpers.
- Prefer Neovim helpers such as `vim.json`, `vim.split`, `vim.list_extend`, `vim.list_slice`, `vim.startswith`, and `vim.system`.
- Avoid assuming this is a standard Lua project. Do not use package-resolution or stdlib APIs when Neovim has a direct utility.
- Check [REFERENCE.md](REFERENCE.md) for the API dump.
