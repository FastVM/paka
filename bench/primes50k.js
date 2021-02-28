let ret = 0;
for (let at = 2; at < 50000; at++) {
    let is_prime = true;
    for (let test = 2; test < at; test++) {
        if (at % test < 1) {
            is_prime = false;
        }
    }
    if (is_prime) {
        ret = ret + 1;
    }
}

console.log(ret);