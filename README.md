# 66

66 is a Neovim plugin for asking an AI agent about selected code and making explicit, localized edits from a visual selection.

## Features

- Ask opencode about a visual selection.
- Explain a visual selection with a preset prompt.
- Edit a visual selection with a localized edit boundary.
- Search the current project and open results in quickfix.
- Browse opencode session history for the current project.

## Setup

```lua
require("66").setup()
```

## Commands

- `:Ask66`: ask about the visual selection.
- `:Explain66`: explain the visual selection.
- `:Edit66`: edit the visual selection.
- `:Search66`: search the current project.
- `:History66`: open session history.

## Testing

66 uses Plenary tests under headless Neovim.

Clone Plenary into the default local dependency path:

```sh
mkdir -p deps
git clone --depth 1 https://github.com/nvim-lua/plenary.nvim deps/plenary.nvim
```

Or point at an existing checkout with `PLENARY_PATH`.

Run the test suite:

```sh
make lua_test
```

Format Lua source files:

```sh
make lua_fmt
```

Check Lua source formatting:

```sh
make lua_fmt_check
```

Lint Lua source files:

```sh
make lua_lint
```
