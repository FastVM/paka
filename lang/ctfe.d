import app;

pragma(msg, ctfeRun!q{
    def fib(x) {
        if (x < 2) {
            return x
        } else {
            return fib(x-2) + fib(x-1)
        }
    }

    def fibfast(n) {
        [a, b] = [0, 1];
        while (n > 0) {
            [a, b, n] -= [a - b, -a, 1];
        }
        return a;
    }

    fibfast(20)
});
