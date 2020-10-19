ldc2 -i source/app.d -Isource -L-lgmp -L-lmpfr -of dext -O3 -ffast-math -enable-inlining --boundscheck=off -flto-binary=/usr/lib/llvm -fprofile-instr-generate -g && \
    ./dext $1