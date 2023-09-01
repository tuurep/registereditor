local function set_register(reg)
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    local new_content = lines[1]
    vim.fn.setreg(reg, new_content)
end

local function open_editor_window(reg)
    local win_height = 1
    local bname = "@" .. reg
    vim.cmd(win_height .. "new " .. bname)

    vim.bo.bufhidden = "wipe"
    vim.bo.swapfile = false
    vim.bo.buflisted = false

    vim.opt_local.number = false

    local reg_content = vim.fn.getreg(reg)
    vim.api.nvim_buf_set_text(0, 0, 0, 0 ,0, {reg_content})
    vim.bo.modified = false

    vim.api.nvim_create_autocmd({"BufWriteCmd"}, {
        buffer = 0,
        callback = function()
            vim.bo.modified = false
            set_register(reg)
        end
    })
end

vim.api.nvim_create_user_command("Me", function(opts)
    open_editor_window(opts.args)
end, {nargs=1})
