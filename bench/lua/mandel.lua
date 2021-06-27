local width = 100
local height = width / 2
local iters = 100000
local write = io.write

for y=0, height-1 do
    local Ci = y * 2 / height- 1
    for x=0, width-1 do
        local Zr, Zi, Zrq, Ziq = 0.0, 0.0, 0.0, 0.0
        local Cr = x * 2 / width - 1.5
        local done = false
        for i=1,iters do
            local Zri = Zr*Zi
            Zr = Zrq - Ziq + Cr
            Zi = Zri + Zri + Ci
            Zrq = Zr*Zr
            Ziq = Zi*Zi
            if Zrq + Ziq > 4 then
                done = true
            end
        end
        if done then
            write(' ')
        else
            write('#')
        end
    end
    write('\n')
end