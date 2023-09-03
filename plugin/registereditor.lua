-- https://stackoverflow.com/questions/72386387/lua-split-string-to-table
-- Split string into table on newlines, include empty lines (\n\n\n)
function string:split(sep)
    local sep = sep or "\n"
    local result = {}
    local i = 1
    for c in (self..sep):gmatch("(.-)"..sep) do
        result[i] = c
        i = i + 1
    end
    return result
end

local function set_register(reg)
    vim.fn.setreg(reg, "")

    local buf_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    local last_line = table.remove(buf_lines)

    if #buf_lines > 0 then
        vim.fn.setreg(reg, buf_lines)
    end

    -- Saving a buffer with a newline at the end puts ^J at the end of register
    -- If last line is text, ^J is omitted: for macros or something like "qy$
    if last_line ~= "" then
        vim.cmd("let @" .. reg .. " ..= '" .. last_line .. "'")
    end
end

local function open_editor_window(reg)
    local is_reg =      reg:match('["0-9a-zA-Z-*+.:%%#/=_]')
    local is_append =   reg:match("[A-Z]")
    local is_readonly = reg:match("[.:%%#]")

    if reg:len() > 1 or not is_reg then
        print("Not a register: @" .. reg)
        return
    end

    local reg_contents = ""

    if not is_append then
        reg_contents = vim.fn.getreg(reg)
    end

    local buf_lines = reg_contents:split("\n")

    local window_height = #buf_lines
    local split_direction = "below" -- "below" or "above"
    local buffer_name = "@\\" .. reg

    vim.cmd(split_direction .. " " .. window_height .. "new " .. buffer_name)

    vim.wo.winfixheight = window_height

    vim.bo.bufhidden = "wipe"
    vim.bo.swapfile = false
    vim.bo.buflisted = false

    vim.api.nvim_buf_set_lines(0, 0, -1, false, buf_lines)

    vim.bo.modified = false

    if is_readonly then
        vim.bo.readonly = true
    end

    vim.api.nvim_create_autocmd({"BufWriteCmd"}, {
        buffer = 0,
        callback = function()
            vim.bo.modified = false
            set_register(reg)
        end
    })
end

vim.api.nvim_create_user_command("Re", function(opts)
    open_editor_window(opts.args)
end, {nargs=1})
