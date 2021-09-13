int printf(const char *fmt, ...);

int fib(int n)
{
    if (n < 2)
    {
        return n;
    }
    else
    {
        return fib(n - 1) + fib(n - 2);
    }
}

int main(void)
{
    printf("%i\n", fib(35));
}