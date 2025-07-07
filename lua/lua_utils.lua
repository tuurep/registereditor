local M = {}

-- https://stackoverflow.com/questions/72386387/lua-split-string-to-table
-- Split string into table on newlines, include empty lines (\n\n\n)
function string:split(separator)
    local separator = separator or "\n"
    local result = {}
    local i = 1
    for c in (self .. separator):gmatch("(.-)" .. separator) do
        result[i] = c
        i = i + 1
    end
    return result
end

M.newline_split = function(value)
    return value:split("\n")
end

-- https://gist.github.com/kgriffs/124aae3ac80eefe57199451b823c24ec
M.string_ends_with = function(value, ending)
    return ending == "" or value:sub(-#ending) == ending
end

M.split_first_token = function(value)
    local first, rest = value:match("^(%S+)%s*(.*)")
    return { first = first, rest = rest }
end

return M
