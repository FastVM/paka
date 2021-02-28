#include <stdio.h>

int main() {
    int ret = 0;
    for (int at = 2; at < 100000; at++) {
        int is_prime = 1;
        for (int test = 2; test < at; test++) {
            if (at % test < 1) {
                is_prime = 0;
            }
        }
        if (is_prime) {
            ret = ret + 1;
        }
    }
    printf("%i\n", ret);
}