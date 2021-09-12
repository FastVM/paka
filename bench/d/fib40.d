import std.stdio;

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

void main()
{
    writeln(fib(40));
}