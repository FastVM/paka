int printf(const char *fmt, ...);

long fib(long n) {
    if (n < 2) {
        return n;
    }
    else {
        return fib(n-2) + fib(n-1);
    }
}

int main() {
    printf("%li\n", fib(45));
    return 0;
}