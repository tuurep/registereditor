# Run all test files
test: tests/mini.test
	nvim --headless --noplugin -u ./tests/minimal-config/init.lua -c "lua MiniTest.run()"

# Run test from file at `$FILE` environment variable
test_file: tests/mini.test
	nvim --headless --noplugin -u ./tests/minimal-config/init.lua -c "lua MiniTest.run_file('$(FILE)')"

# Download 'mini.test'
tests/mini.test:
	git clone --filter=blob:none https://github.com/nvim-mini/mini.test $@

clean:
	rm -rf ./tests/mini.test
