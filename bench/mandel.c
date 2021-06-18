
int putchar(int chr);

int main() {
    int width = 1000;
    int height = width;
    int iters = 1000;
    for (int y = 0; y < height; y++) {
        double ci = y * 2.0 / height - 1;
        for (int x = 0; x < width; x++) {
            double zr=0, zi=0, zrq=0, ziq=0;
            double cr = x * 2.0 / width - 1.5;
            int done = 0;
            for (int i = 0; i < iters; i++) {
                double zri = zr * zi;
                zr = zrq - ziq + cr;
                zi = zri + zri + ci;
                zrq = zr*zr;
                ziq = zi*zi;
                if (zrq + ziq > 4) {
                    done = 1;
                }
            }
            if (done) {
                putchar(' ');
            }
            else {
                putchar('#');
            }
        }
        putchar('\n');
    }
}