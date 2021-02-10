local scl = 100
local it = 500
local xv = {-2, 6/10, 5/100 / scl}
local yv = {-1, 1, 5/100 / scl}
print("P1")
local width = (xv[2] - xv[1]) / xv[3]
local height = (yv[2] - yv[1]) / yv[3]
print(width, height)

local y = yv[1]
local yc = 0
while yc < height do
    local x = xv[1]
    local xc = 0;
    while xc < width do
        local zi = 0
        local zr = 0
        local i = 0
        while i < it and zi * zi + zr * zr < 4 do
            local zri = zr
            zr = zr * zr - zi * zi + x
            zi = 2 * zri * zi + y
            i = i + 1
        end
        if i == it then
            io.write(1, " ")
        else
            io.write(0, " ")
        end
        x = x + xv[3]
        xc = xc + 1
    end
    print()
    y = y + yv[3]
    yc = yc + 1
end