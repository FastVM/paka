int putchar(int c);

int main() {
    const char *charmap = " .:-=+*#%@";
    for (float y = -1; y < 1; y+=0.04) {
        for (float x = -2; x < 1; x+=0.02) {
            float zi = 0, zr = 0;
            int i = 0;
            while (i < 100000 && zi *zi + zr *zr < 4) {
                float lzr = zr;
                float lzi = zi;
                zr = lzr * lzr - lzi * zi + x;
                zi = 2 * lzr * lzi + y;
                i = i + 1;
            }
            putchar(charmap[i % 10]);
        }
        putchar('\n');
    }
    return 0;
}