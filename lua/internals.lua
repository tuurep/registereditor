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

-- https://gist.github.com/kgriffs/124aae3ac80eefe57199451b823c24ec
function string:endswith(ending)
    return ending == "" or self:sub(-#ending) == ending
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

-- set the contents of a buffer and mark it is not modified
local function set_buffer_content(buffer, content)
    vim.api.nvim_buf_set_lines(buffer, 0, -1, false, content)
    vim.api.nvim_set_option_value("modified", false, { buf = buffer })
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

    set_buffer_content(0, buf_lines)

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

M.open_all_windows = function(arg)
    -- check all args and build table
    local registers = {}
    local count = 0
    for register in arg:gmatch("[^%s]+") do
        if not check_string_is_register(register) then
            print("Not a register: @" .. register)
            return
        end
        count = count + 1
        table.insert(registers, register)
    end

    -- open a new editor window for each register specified
    for i, register in ipairs(registers) do
        open_editor_window(register)
        if i ~= count then
            vim.cmd("wincmd p")
        end
    end
end

-- tells whether or not a buffer belongs to this plugin
local function check_buffer_is_register_buffer(buffer)
    return vim.api.nvim_get_option_value("filetype", { buf = buffer })
        == "registereditor"
end

-- updates a given buffer with the given content if it matches the given
-- register
local function update_register_buffer(buffer, register, content)
    -- if the buffer is named @<register>, then it should be updated
    if vim.api.nvim_buf_get_name(buffer):endswith("@" .. register) then
        -- update the buffer with the register contents
        vim.schedule(function()
            set_buffer_content(buffer, content)
        end)
    end
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

-- update all open RegisterEdit buffers
M.update_register_buffers = function(register, content)
    loop_over_register_buffers(function(buffer)
        update_register_buffer(buffer, register, content)
    end)
end

-- updates a buffer to match the contents of the underlying register
local function refresh_register_buffer(buffer)
    -- find the register for this buffer
    local register = string.sub(vim.api.nvim_buf_get_name(buffer), -1, -1)
    assert(check_string_is_register(register))
    -- get the contents of the register
    local content = vim.fn.getreg(register):split("\n")
    -- update the buffer contents to match the register
    set_buffer_content(buffer, content)
end

M.refresh_all_register_buffers = function()
    loop_over_register_buffers(function(buffer)
        refresh_register_buffer(buffer)
    end)
end

return M
