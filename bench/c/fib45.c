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
    printf("%lf\n", fib(45));
    return 0;
}