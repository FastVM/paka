make paka purr DC=ldc2 -Bj
./bin/purr --load ./paka.so --lang paka combo.dext > out.mak
make -f out.mak clean 
make -f out.mak --no-print-directory -Bj all FILES="bench/fib35.dext"
./times.xsh | sort -n