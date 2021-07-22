let sum = 0;
let cur = 2;
while (cur < 10000) {
    let test = 2;
    let is_prime = true;
    while (test < cur) {
        if (cur % test === 0) {
            is_prime = false;
        }
        ++test;
    }
    if (is_prime) {
        sum += cur;
    }
    ++cur;
}
console.log(sum);