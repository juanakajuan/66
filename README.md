# 66

66 is a Neovim plugin for asking an AI agent about selected code and making explicit, localized edits from a visual selection.

## Features

- Ask opencode about a visual selection.
- Explain a visual selection with a preset prompt.
- Edit a visual selection with a localized edit boundary.
- Search the current project and open results in quickfix.
- Browse opencode session history for the current project.
- Cancel the active opencode request.

## Setup

66 shells out to the `opencode` CLI, so `opencode` must be available on your
`PATH`.

```lua
require("66").setup()
```

Pass options to override the defaults:

```lua
require("66").setup({
  model = "openai/gpt-5.5",
  variant = "low",
  agent = "build",
  response_layout = "bottom_split",
  ask_keymap = "<leader>6a",
  explain_keymap = "<leader>6x",
  search_keymap = "<leader>6s",
  history_keymap = "<leader>6h",
  edit_keymap = "<leader>6e",
  cancel_keymap = "<leader>6c",
})
```

Set any keymap option to `false` to disable it.

## Options

- `model`: opencode model identifier.
- `variant`: opencode variant name.
- `agent`: opencode agent name.
- `max_file_lines`: maximum current-file lines sent with Ask/Explain context. Default: `400`.
- `edit_context_lines`: maximum nearby source lines sent with Edit context. Default: `120`.
- `response_layout`: one of `"bottom_split"`, `"right_split"`, `"float"`, or `"tab"`.
- `ask_keymap`: visual-mode Ask About Selection mapping, or `false`.
- `explain_keymap`: visual-mode Explain Selection mapping, or `false`.
- `search_keymap`: normal-mode Project Search mapping, or `false`.
- `history_keymap`: normal-mode Session History mapping, or `false`.
- `edit_keymap`: visual-mode Edit Selection mapping, or `false`.
- `cancel_keymap`: normal-mode Cancel Active Request mapping, or `false`.

## Commands

- `:Ask66`: ask about the visual selection.
- `:Explain66`: explain the visual selection.
- `:Edit66`: edit the visual selection.
- `:Search66`: search the current project.
- `:History66`: open session history.
- `:Cancel66`: cancel the active opencode request.

`Ask66`, `Explain66`, and `Edit66` read the current visual selection. `Search66`,
`History66`, and `Cancel66` run from normal mode.

## Workflows

- Ask/Explain are read-only and display the assistant answer in a scratch Response View.
- Edit asks opencode to change the selected code or immediately adjacent lines, then applies the changed source back into the live buffer.
- Search asks opencode for project locations and opens parsed results in quickfix.
- History lists recent `[66]` opencode sessions for the current working directory and opens the selected assistant response.
- Cancel terminates the newest still-running 66 request in the current Neovim instance.

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
