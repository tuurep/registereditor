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

    if reg:len() > 1 or not reg:match('["0-9a-zA-Z-*+.:%%#/=_]') then
        print("Not a register: @" .. reg)
        return
    end

    local reg_content = ""

    -- Registers A-Z are append registers, they should have no initial content
    if not reg:match("[A-Z]") then
        reg_content = vim.fn.getreg(reg)
    end

    local buf_lines = reg_content:split("\n")
    local window_height = #buf_lines

    vim.cmd("below " .. window_height .. "new @\\" .. reg)

    vim.wo.winfixheight = true

    -- Scratch buffer settings
    vim.bo.bufhidden = "wipe"
    vim.bo.swapfile = false
    vim.bo.buflisted = false

    vim.api.nvim_buf_set_lines(0, 0, -1, false, buf_lines)

    vim.bo.modified = false
    
    -- Special readonly registers
    if reg:match("[.:%%#]") then
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

vim.api.nvim_create_user_command("RegisterEdit", function(opts)
    open_editor_window(opts.args)
end, {nargs=1})
