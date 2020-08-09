C = lambda f: lambda v: f(f)(v)
F = lambda f: lambda x: x if x < 2 else C(f)(x - 1) + C(f)(x - 2)
print(C(F)(30))