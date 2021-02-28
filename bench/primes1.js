var upto = 50000;
var ret = 0;
var at = 2;
while (at < upto) {
    var is_prime = true;
    var test = 2;
    while (test < at) {
        if (at % test < 1) {
            is_prime = false;
        }
        test = test + 1;
    }
    if (is_prime) {
        ret = ret + 1;
    }
    at = at + 1;
}

console.log(ret);