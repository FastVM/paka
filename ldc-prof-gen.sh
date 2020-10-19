ldc2 -i source/app.d -Isource -L-lgmp -L-lmpfr -of dext -O3 -ffast-math -enable-inlining --boundscheck=off -flto-binary=/usr/lib/llvm -fprofile-instr-use=default.profdata -g && \
    ./dext $1 && \
    ldc-profdata merge -output=default.profdata default.profraw