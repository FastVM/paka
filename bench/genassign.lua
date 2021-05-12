print("local x = 0")
print("local y")
print("while x < 100000 do")
local x = 0
while x < 1000 do
    print("    y = x");
    print("    x = y");
    x = x + 1
end
print("    x = x + 1")
print("end");
print("print(x)")