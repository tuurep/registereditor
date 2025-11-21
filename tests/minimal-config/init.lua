-- Set up 'mini.test' only when calling headless Neovim (like with `make test`)
if #vim.api.nvim_list_uis() == 0 then
    vim.cmd('set rtp+=tests/mini.test')
    require('mini.test').setup({
        -- `make test` will run all files prefixed with 'test-'
        -- Note: changed from mini.test default 'test_' (underscore)
        collect = {
            find_files = function()
                return vim.fn.globpath('tests', '**/test-*.lua', true, true)
            end
        }
    })
end
