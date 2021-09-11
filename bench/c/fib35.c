int printf(const char *fmt, ...);

double fib(double n)
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
    printf("%g\n", fib(35));
}