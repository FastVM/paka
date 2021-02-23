upto = 20000

ret = 0
at = 20000
while at < upto:
    is_prime = True
    test = 2
    while test < at:
        if at % test < 1:
            is_prime = False
        test = test + 1
    if is_prime:
        ret = ret + 1
    at = at + 1

print(ret)