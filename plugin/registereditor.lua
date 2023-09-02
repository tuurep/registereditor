local function set_register(reg, is_macro, is_append)
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

    local new_contents

    if is_macro or is_append then
        new_contents = table.concat(lines)
    else
        new_contents = lines
    end

    vim.fn.setreg(reg, new_contents)
end

local function open_editor_window(reg)
    local is_macro =    reg:match("[a-z]")
    local is_append =   reg:match("[A-Z]")
    local is_other =    reg:match('["0-9-*+/=_]')
    local is_readonly = reg:match("[.:%%#]")

    local invalid_reg = reg:len() > 1 or
                        (not is_macro and not is_append and
                         not is_other and not is_readonly)

    if invalid_reg then
        print("Not a register: @" .. reg)
        return
    end

    local reg_contents = vim.fn.getreg(reg, 1, 1)

    local window_height = is_append and 1 or #reg_contents
    local split_direction = "below" -- "below" or "above"
    local statusline_text = "@\\" .. reg

    vim.cmd(split_direction .. " " .. window_height .. "new " .. statusline_text)

    vim.wo.winfixheight = window_height
    vim.opt_local.number = false

    vim.bo.bufhidden = "wipe"
    vim.bo.swapfile = false
    vim.bo.buflisted = false

    -- Uppercase letter contains its lowercase variants contents
    -- It appends to the lowercase variant on save
    -- So don't set any initial content for uppercase
    if not is_append then
        vim.api.nvim_buf_set_lines(0, 0, -1, false, reg_contents)
        vim.bo.modified = false
    end

    if is_readonly then
        vim.bo.readonly = true
    end

    vim.api.nvim_create_autocmd({"BufWriteCmd"}, {
        buffer = 0,
        callback = function()
            vim.bo.modified = false
            set_register(reg, is_macro, is_append)
        end
    })
end

vim.api.nvim_create_user_command("Re", function(opts)
    open_editor_window(opts.args)
end, {nargs=1})
