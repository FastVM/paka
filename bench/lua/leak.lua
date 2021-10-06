local x = 0
local leak = {}
while x < 1000 do
	leak = {leak, leak}
	x = x + 1
end
print(#leak)