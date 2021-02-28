int printf(const char *fmt, ...);
double fmod(double x, double y);

int main() {
    double upto = 20000;
    double ret = 0;
    double at = 0;
    
    while (at < upto) {
        int is_prime = 1;
        double test = 2;
        while (test < at) {
            if (fmod(at, test) < 1) {
                is_prime = 0;
            };
            test = test + 1;
        };
        if (is_prime) {
            ret = ret + 1;
        };
        at = at + 1;
    };

    printf("%lf\n", ret);
}