import app;

pragma(msg, ctfeRun!q{
    def fib(x) {
        if (x < 2) {
            return x
        } else {
            return fib(x-2) + fib(x-1)
        }
    }

    fib(20)
});
