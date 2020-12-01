local pow = 0
local n = 1.0
while n + 1 - n == 1 do
    n = n * 2
    pow = pow + 1
end
print(pow)