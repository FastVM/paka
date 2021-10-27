local charmap = { [0]=" ", ".", ":", "-", "=", "+", "*", "#", "%", "@" }
local y = 0-1
while y < 1 do
    local x = 0-2
    while x < 1 do
        local zi = 0
        local zr = 0
        local i = 0
        while i < 100000 and zi*zi+zr*zr < 4 do
            local lzr = zr
            local lzi = zi
            zr = lzr * lzr - lzi * zi + x
            zi = 2 * lzr * lzi + y
            i = i + 1
        end
        io.write(charmap[i % 10])
        x = x + 2/100
    end
  print()
  y = y + 4/100
end