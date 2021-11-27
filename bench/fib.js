
const fib = (n) => {
    if (n < 2) {
        return n;
    } else {
        return fib(n-2) + fib(n-1);
    }
};

if (process.argv.length !== 3) {
    console.log("error: need an integer argument")
} else {
    console.log(fib(Number(process.argv[2])));
}
