# Run all test files, or a single test file in FILE, if given.
#
# FILE arg example:
# 	make test FILE=test-add-key-trigger.lua
#
# Note: since this is the first target, just `make` runs all tests too.

test: tests/mini.test
	@if [ -z "$(FILE)" ]; then \
		nvim --headless --noplugin -u ./tests/minimal-config/init.lua \
			-c "lua MiniTest.run()"; \
	else \
		nvim --headless --noplugin -u ./tests/minimal-config/init.lua \
			-c "lua MiniTest.run_file('tests/' .. '$(FILE)')"; \
	fi

# Download 'mini.test'
tests/mini.test:
	git clone --filter=blob:none https://github.com/nvim-mini/mini.test $@

clean:
	rm -rf ./tests/mini.test
