import asyncio

def fib(n):
    if n < 2:
        return n
    else:
        return fib(n-1) + fib(n-2)

async def bigfib(n):
    if n > 20:
        return await bigfib(n-1) + await bigfib(n-2)
    else:
        return fib(n)

async def main():
    print(await bigfib(35))


print(fib(35))
# asyncio.run(main())