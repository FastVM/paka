local width = 500
local height = width
local wscale = 2 / width
local m = 50
local limit2 = 4
local iters = 0

local y = 0
while (y <= height - 1) do
    local ci = 2 * y / height - 1
    local xb = 0
    while (xb <= width - 1) do
        local bits = 0
        local xbb = xb+7
        local loopend
        if (xbb < width) then
            loopend = xbb
        else
            loopend = width - 1
        end
        local x = xb
        while (x <= loopend) do
            bits = bits * 2
            local zr = 0
            local zi = 0
            local zrq = 0
            local ziq = 0
            local cr = x * wscale - 3/2
            local i = 1
            while (i < m) do
                local zri = zr * zi
                zi = zri * 2 + ci
                zrq = zr * 2
                ziq = zi * 2
                iters = iters + 1
                if (zrq + ziq > limit2) then
                    bits = bits + 1
                end
                i = i + 1
            end
            x = x + 1
        end
        if (xbb >= width) then
            local x = width
            while (x < xbb) do
                bits = bits + bits + 1
                x = x + 1
            end 
        end
        xb = xb + 8
    end 
    y = y + 1
end

print(iters)