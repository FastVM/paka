
ret = 0
for at in range(2, 50000):
    is_prime = True
    for test in range(2, at):
        if at % test < 1:
            is_prime = False
    if is_prime:
        ret = ret + 1

print(ret)