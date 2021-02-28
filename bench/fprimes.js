function sum_primes(upto) {
    function is_prime(num) {
        let test = 2;
        while (test * test <= num) {
            if (num % test == 0) {
                return false;
            }
            test++;
        }
        return true;
    }
    let ret = 0;
    let at = 2;
    while (at < upto) {
        if (is_prime(at)) {
            ret++;
        }
        at++;
    }
    return ret;
}

console.log(sum_primes(1000000));