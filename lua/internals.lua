local M = {}

-- maximum height of a registereditor window. This can become a configurable
-- option in the future
local MAX_BUFFER_LINES = 20

-- https://stackoverflow.com/questions/72386387/lua-split-string-to-table
-- Split string into table on newlines, include empty lines (\n\n\n)
function string:split(sep)
    local sep = sep or "\n"
    local result = {}
    local i = 1
    for c in (self .. sep):gmatch("(.-)" .. sep) do
        result[i] = c
        i = i + 1
    end
    return result
end

local function split_first_token(value)
    local first, rest = value:match("^(%S+)%s*(.*)")
    return { first = first, rest = rest }
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
    local window_height = math.min(#buf_lines, MAX_BUFFER_LINES)

    -- keep track of existing equalalways setting, and set equalalways to
    -- false. See https://github.com/tuurep/registereditor/issues/1 for
    -- details.
    local old_equalalways = vim.o.equalalways
    vim.o.equalalways = false

    -- get information about old window
    local old_window_id = vim.fn.win_getid()
    local old_window_height = vim.api.nvim_win_get_height(old_window_id)

    -- make sure the old window is big enough to split
    vim.api.nvim_win_set_height(old_window_id, old_window_height + 2)

    -- open the new window
    vim.cmd("below " .. window_height .. "new @\\" .. reg)

    -- return the old window to its previous size
    vim.api.nvim_win_set_height(old_window_id, old_window_height)

    -- resize the new window back to its proper size.
    vim.api.nvim_win_set_height(0, window_height)

    vim.wo.winfixheight = true

    -- restore the original equalalways setting
    vim.o.equalalways = old_equalalways

    -- Scratch buffer settings
    vim.bo.filetype = "registereditor"
    vim.bo.bufhidden = "wipe"
    vim.bo.swapfile = false
    vim.bo.buflisted = false

    vim.api.nvim_buf_set_lines(0, 0, -1, false, buf_lines)

    vim.bo.modified = false

    -- Special readonly registers
    if reg:match("[.:%%#]") then
        vim.bo.readonly = true
    end

    vim.api.nvim_create_autocmd({ "BufWriteCmd" }, {
        buffer = 0,
        callback = function()
            vim.bo.modified = false
            set_register(reg)
        end,
    })
end

local function check_string_is_register(value)
    return value:len() == 1 and value:match('["0-9a-zA-Z-*+.:%%#/=_]')
end

-- parse a list of single-character registers from a string argument. For
-- example, if the argument is "a b c" then the list should be {"a", "b", "c"}
local function parse_register_list(arg)
    local registers = {}
    for register in arg:gmatch("[^%s]+") do
        if not check_string_is_register(register) then
            print("Not a register: @" .. register)
            return
        end
        table.insert(registers, register)
    end
    return registers
end

local function open_all_windows(arg)
    -- check all args and build table
    local registers = parse_register_list(arg)
    if #registers == 0 then
        return
    end

    -- open a new editor window for each register specified
    for i, register in ipairs(registers) do
        open_editor_window(register)
        if i ~= #registers then
            vim.cmd("wincmd p")
        end
    end
end

-- tells whether or not a buffer belongs to this plugin
local function check_buffer_is_register_buffer(buffer)
    return vim.api.nvim_get_option_value("filetype", { buf = buffer })
        == "registereditor"
end

-- perform an action on all registereditor buffers
local function loop_over_register_buffers(action)
    -- iterate over all buffers
    for _, buffer in pairs(vim.api.nvim_list_bufs()) do
        -- ensure the buffer has the 'registereditor' filetype
        if check_buffer_is_register_buffer(buffer) then
            action(buffer)
        end
    end
end

local function get_register_from_buffer(buffer)
    return string.sub(vim.api.nvim_buf_get_name(buffer), -1, -1)
end

local function close_buffer(buffer)
    vim.cmd("bd " .. buffer)
end

local function close_windows(arg)
    -- see what registers were specified. If there were none, then registers
    -- will be nil
    local registers = nil
    if arg ~= nil and arg ~= "" then
        registers = parse_register_list(arg)
    end

    -- loop over all the buffers and close the appropriate ones.
    loop_over_register_buffers(function(buffer)
        -- if the registers list is nil or empty, then close all the buffers
        if registers == nil or #registers == 0 then
            close_buffer(buffer)
        else
            -- find out what register the buffer corresponds to
            local buffer_register = get_register_from_buffer(buffer)

            -- determine if the buffer should be closed based on the supplied
            -- list of registers
            local should_close = false
            for _, register in pairs(registers) do
                if register == buffer_register then
                    should_close = true
                end
            end

            -- close the buffer if necessary
            if should_close then
                close_buffer(buffer)
            end
        end
    end)
end

-- main entry point for the :RegisterEdit user command
M.register_edit_command = function(arg)
    -- split the first argument from the rest of the arguments
    local split_result = split_first_token(arg)

    -- check if the first argument is an action
    if split_result.first == "open" then
        open_all_windows(split_result.rest)
    elseif split_result.first == "close" then
        close_windows(split_result.rest)
    else
        open_all_windows(arg)
    end
end

return M
