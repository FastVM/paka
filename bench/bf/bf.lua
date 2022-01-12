local function read(file)
    local fd = assert(io.open(file, "r"))
    local ret = fd:read("*all")
    fd:close()
    return ret
end

local function write(file, src)
    io.open(file, "w"):write(src)
end

local function bf_strip(src) 
    local ret = {}
    for i=1, #src do
        local from = src:sub(i, i)
        if from == "+" or from == "-" or from == ">" or from == "<" or from == "[" or from == "]" or from == "," or from == "." then
            ret[#ret+1] = from
        end
    end
    return ret
end

local function bf_stream_new(src)
    return {bf_strip(src), 1}
end

local function bf_stream_peek(src) 
    if src[2] <= #src[1] then
        return src[1][src[2]]
    else 
        return nil
    end
end

local function bf_stream_skip1(src)
    if src[2] <= #src[1] then
        src[2] = src[2] + 1
    end
end

local function bf_stream_read(src)
    local ret = bf_stream_peek(src)
    bf_stream_skip1(src)
    return ret
end

local function main(args) 
    if #args == 0 then
        print("bf.lua needs a file")
        return 1
    end
    local text = read(args[1])
    local fix_cell = "cell"
    local stdin = ""
    local index = 2
    local out = nil
    while index <= #args do
        local arg = args[index]
        index = index + 1
        if arg == "--wrap" then
            print("dont use --wrap, use --16bit")    
            return 1
        end
        if arg == "--8bit" then 
            fix_cell = "cell % 256"
        end
        if arg == "--16bit" then
            fix_cell = "cell % 65536"
        end
        if arg == "--out" then
            if index > #args then     
                print("--out: needs an output file")
            end
            out = args[index]
            index = index + 1
        end
        if arg == "--stdin" then
            if index > #args then 
                print("--stdin: needs a string")
            end
            stdin = args[index]
            index = index + 1
        end
    end
    local lua = {}
    lua[#lua+1] = "local stdin = (arg[1] or '') .. '\\0'"
    lua[#lua+1] = "local chr = 1"
    lua[#lua+1] = "local ptr = 15000"
    lua[#lua+1] = "local cell = 0"
    lua[#lua+1] = "local tape = {}"
    lua[#lua+1] = "for i=1, 30000 do tape[i] = 0 end"
    local src = bf_stream_new(text)
    while true do 
        local chr = bf_stream_read(src)
        if chr == nil then 
            local final = table.concat(lua, "\n")
            if out == nil then 
                local loaded, err = load(final)
                print(loaded, err)
                loaded()
                return 0
            else
                write(out, final)
                return 0
            end
        elseif chr == "+" then
            local n = 1
            while bf_stream_peek(src) == "+" do
                bf_stream_skip1(src)
                n = n + 1
            end
            lua[#lua+1] = "cell = cell + " .. n
        elseif chr == "-" then
            local n = 1
            while bf_stream_peek(src) == "-" do
                bf_stream_skip1(src)
                n = n + 1
            end
            lua[#lua+1] = "cell = cell - " .. n
        elseif chr == ">" then
            local n = 1
            while bf_stream_peek(src) == ">" do
                bf_stream_skip1(src)
                n = n + 1
            end
            lua[#lua+1] = "tape[ptr] = cell"
            lua[#lua+1] = "ptr = ptr + " .. n
            lua[#lua+1] = "cell = tape[ptr]"
        elseif chr == "<" then
            local n = 1
            while bf_stream_peek(src) == "<" do
                bf_stream_skip1(src)
                n = n + 1
            end
            lua[#lua+1] = "tape[ptr] = cell"
            lua[#lua+1] = "ptr = ptr - " .. n
            lua[#lua+1] = "cell = tape[ptr]"
        elseif chr == "[" then
            lua[#lua+1] = "while " .. fix_cell .. " ~= 0 do"
        elseif chr == "]" then
            lua[#lua+1] = "end"
        elseif chr == "." then 
            lua[#lua+1] = "io.write(string.char(" .. fix_cell .. "))"
        elseif chr == "," then 
            lua[#lua+1] = "cell = string.byte(stdin, chr)"
            lua[#lua+1] = "chr = chr + 1"
        end
    end
end

return main(arg)