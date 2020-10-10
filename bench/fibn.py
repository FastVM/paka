import math

def fib(n):
    i = 0
    a, b = 0, 1
    while i < n:
        tmp = b
        b = a + b
        a = tmp
        i += 1
    return a

print(10 ** (math.log10(fib(100000)) % 1))