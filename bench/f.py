Q = lambda f: lambda a: f(f)(a)
F = lambda f: lambda a: a if a < 2 else Q(f)(a - 1) + Q(f)(a - 2)
print(Q(F)(30))