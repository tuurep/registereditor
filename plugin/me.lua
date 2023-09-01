local function set_register(reg)
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    local new_content = lines[1]
    vim.fn.setreg(reg, new_content)
end

local function open_editor_window(reg)
    if reg:len() > 1 or not reg:match("[a-zA-Z]") then
        print("Not a macro register: @" .. reg)
        return
    end

    -- window settings
    local split_direction = "below" -- "below" or "above"
    local window_height = 1
    local statusline_text = "@" .. reg

    vim.cmd(split_direction .. " " .. window_height .. "new " .. statusline_text)

    vim.wo.winfixheight = window_height
    vim.opt_local.number = false

    vim.bo.bufhidden = "wipe"
    vim.bo.swapfile = false
    vim.bo.buflisted = false

    if reg:match("[a-z]") then
        local reg_content = vim.fn.getreg(reg)
        vim.api.nvim_buf_set_text(0, 0, 0, 0 ,0, {reg_content})
        vim.bo.modified = false
    end

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
