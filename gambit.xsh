make paka purr DC=ldc2 -Bj
./bin/purr --load ./paka.so --lang paka combo.dext > out.mak
make -f out.mak clean 
make -f out.mak --no-print-directory -B all FILES="bench/fib.dext"
./times.xsh | sort -n