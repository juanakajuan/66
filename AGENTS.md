- Always use neovim provided functions.
- This is not a standard lua project. Package resolution and all things related to lua and std should be ignored in favor of neovim and its utilities.

## Commands

- `make lua_test`: run Plenary tests under headless Neovim.
- `make lua_fmt`: format Lua source files with StyLua.
- `make lua_fmt_check`: check Lua source formatting with StyLua.
- `make lua_lint`: lint Lua source files with luacheck.


## Agent skills

### Issue tracker

Issues and PRDs are tracked in GitHub Issues for `juanakajuan/66`. See `docs/agents/issue-tracker.md`.

### Triage labels

Use the default triage label vocabulary. See `docs/agents/triage-labels.md`.

### Domain docs

Use a single-context domain documentation layout. See `docs/agents/domain.md`.
