local lua_utils = require("lua_utils")
local vim_utils = require("vim_utils")

local M = {}

-- maximum height of a registereditor window. This can become a configurable
-- option in the future
local MAX_BUFFER_LINES = 20

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
local function set_buffer_content(buf, content)
    -- get existing buffer content
    local existing_content = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

    -- determine if the content changed or not
    local content_changed = false
    if #existing_content ~= #content then
        content_changed = true
    else
        for line_number, line in ipairs(existing_content) do
            if line ~= content[line_number] then
                content_changed = true
            end
        end
    end

    -- if the content changed, then actually modify the buffer
    if content_changed then
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)
        vim.api.nvim_set_option_value("modified", false, { buf = buf })
        vim.api.nvim_win_set_height(
            vim.fn.bufwinid(buf),
            math.min(#content, MAX_BUFFER_LINES)
        )
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

    local buf_lines = lua_utils.newline_split(reg_content)
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

    set_buffer_content(vim.fn.bufnr(), buf_lines)

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
    local regs = {}
    for reg in arg:gmatch("[^%s]+") do
        if not check_string_is_register(reg) then
            print("Not a register: @" .. reg)
            return
        end
        table.insert(regs, reg)
    end
    return regs
end

local function open_all_windows(arg)
    -- check all args and build table
    local regs = parse_register_list(arg)
    if regs == nil or #regs == 0 then
        return
    end

    -- open a new editor window for each register specified
    for i, reg in ipairs(regs) do
        open_editor_window(reg)
        if i ~= #regs then
            vim.cmd("wincmd p")
        end
    end
end

-- tells whether or not a buffer belongs to this plugin
local function check_buffer_is_register_buffer(buf)
    return vim.api.nvim_get_option_value("filetype", { buf = buf }) == "registereditor"
end

-- perform an action on all registereditor buffers
local function loop_over_register_buffers(action)
    -- iterate over all buffers
    for _, buf in pairs(vim.api.nvim_list_bufs()) do
        -- ensure the buffer has the 'registereditor' filetype
        if check_buffer_is_register_buffer(buf) then
            action(buf)
        end
    end
end

-- gets the register name from the buffer
local function get_register_from_buffer(buf)
    return string.sub(vim.api.nvim_buf_get_name(buf), -1, -1)
end

local function close_windows(arg)
    -- see what registers were specified. If there were none, then registers
    -- will be nil
    local regs = nil
    if arg ~= nil and arg ~= "" then
        regs = parse_register_list(arg)
    end

    -- loop over all the buffers and close the appropriate ones
    loop_over_register_buffers(function(buf)
        -- find out what register the buffer corresponds to
        local reg = get_register_from_buffer(buf)

        -- determine if the buffer should be closed based on the supplied
        -- list of registers. If the registers list is nil or empty, then
        -- always close the buffer
        if regs == nil or #regs == 0 or vim.tbl_contains(regs, reg) then
            vim_utils.close_buffer(buf)
        end
    end)
end

-- loop over all open buffers and update them based on the register contents.
-- The filter parameter allows for skipping some buffers. It can be a map from
-- register name to `true`, or it can be `nil` to include all buffers.
-- `content` is an optional parameter that supersedes getting the new register
-- content via vim.fn.getreg()
M.refresh_all_registereditor_buffers = function(filter, content)
    loop_over_register_buffers(function(buf)
        -- get register name
        local reg = get_register_from_buffer(buf)

        -- skip things that are filtered out
        if filter ~= nil and filter[reg] == nil then
            return
        end

        -- get register content
        local content = vim_utils.get_register_lines(reg)

        -- update the buffer with the register contents
        vim.schedule(function()
            set_buffer_content(buf, content)
        end)
    end)
end

-- main entry point for the :RegisterEditor user command
M.registereditor_command = function(arg)
    -- split the first argument from the rest of the arguments
    local split_result = lua_utils.split_first_token(arg)

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
