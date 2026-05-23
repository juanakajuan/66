lua_test:
	echo "===> Testing"
	nvim --headless --noplugin -u tests/minimal_init.lua \
		-c "PlenaryBustedDirectory tests { minimal_init = 'tests/minimal_init.lua' }"

lua_fmt:
	echo "===> Formatting"
	stylua lua/ --config-path=.stylua.toml

lua_fmt_check:
	echo "===> Checking format"
	stylua lua/ --config-path=.stylua.toml --check

lua_lint:
	echo "===> Linting"
	PATH="$(HOME)/.luarocks/bin:$(PATH)" luacheck lua/ --globals vim
