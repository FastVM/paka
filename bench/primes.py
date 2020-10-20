def is_prime(num):
    test = 2
    while test < num:
        if num % test == 0:
            return False
        test += 1
    return True

def sum_primes(upto):
    ret = 0
    at = 2
    while at < upto:
        if is_prime(at):
            ret += 1
        at += 1
    return ret

res = sum_primes(30000)
print(res)