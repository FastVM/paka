local x = 0
local leak = {}
while x < 100000000 do
    leak = {{{{{{{{{{x}}}}}}}}}}
    x = x + 1
end
print(leak[1][1][1][1][1][1][1][1][1][1])