---
name: vim.treesitter
description: Reference Neovim Treesitter APIs when editing syntax-tree logic. Use when code touches vim.treesitter, TSNode, TSTree, TSQuery, TSQueryCursor, parser handling, tree navigation, or Treesitter query behavior.
---

# Neovim Treesitter API

Use Neovim's Treesitter APIs for syntax-tree work instead of external parser assumptions.

## Workflow

- Use `TSNode` methods for node navigation, ranges, fields, and ancestry checks.
- Use `TSTree` methods for parsed buffer trees and edits.
- Use `TSQuery` and query cursor APIs for capture and match traversal.
- Keep parser and query behavior tied to Neovim's runtime model.
- Check [REFERENCE.md](REFERENCE.md) for the Treesitter API dump.
