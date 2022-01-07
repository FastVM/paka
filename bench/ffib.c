
int printf(const char *fmt, ...);
double atof(const char *src);

double fib(double n) {
    if (n < 2) {
        return n;
    } else {
        return fib(n-2) + fib(n-1);
    }
}

int main(int argc, const char **argv) {
    if (argc < 1) {
        printf("error: need an integer argument\n");
        return 1;
    }
    printf("%f\n", fib(atof(argv[1])));
    return 0;
}
