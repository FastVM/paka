#include <stddef.h>
#include <stdio.h>
#include <stdbool.h>
#include <math.h>

#define DOUBLE_VAL

#ifdef DOUBLE_VAL
#define mod(x, y) (fmod(x, y))
typedef double number_t;
#define pnum(n) (printf("%lf", n))
#else
#define mod(x, y) ((x) % (y))
typedef size_t number_t;
#define pnum(n) (printf("%zu", n))
#endif

bool is_prime(number_t num) {
    number_t test = 2;
    while (test < num) {
        if (mod(test, num) == 0) {
            return false;
        }
        test += 1;
    }
    return true;
}

number_t sum_primes(number_t upto) {
    number_t ret = 0;
    number_t at = 2;
    while (at < upto) {
        if (is_prime(at)) {
            ret += 1;
        }
        at += 1;
    }
    return ret;
}

int main() {
    number_t res = sum_primes(30000);
    pnum(res);
    putchar('\n');
}

