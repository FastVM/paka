local n = {0, 0}
while n[1] < 100000 do
    while n[2] < 1000 do
        n = {n[1], n[2] + 1, n}
    end
    n = {n[1] + 1, 0}
end
print(n[1] + n[2])