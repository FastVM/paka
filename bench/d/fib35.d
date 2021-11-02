
import std.stdio: writeln;

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

void main()
{
    writeln(fib(35));
}