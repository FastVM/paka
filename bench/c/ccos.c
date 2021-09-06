#include <math.h>
#include <stdio.h>

int main() {
    double res = 0;
    for (int x = 0; x < 10000000; x++)
    {
        res += cos(res);
        res -= sin(res);
    }
    printf("%.3f\n", res);
    return 0;
}
