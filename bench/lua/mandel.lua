local charmap = { [0]=" ", ".", ":", "-", "=", "+", "*", "#", "%", "@" }
for y = -1, 1, 0.04 do
  for x = -2, 1, 0.02 do
    local zi, zr, i = 0, 0, 0
    while i < 100000 and zi*zi+zr*zr < 4 do
      zr, zi, i = zr*zr-zi*zi+x, 2*zr*zi+y, i+1
    end
    io.write(charmap[i%10])
  end
  print()
end