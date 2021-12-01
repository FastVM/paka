# mkdir -p bin
# echo building bin/minivm
# gmake -C minivm -Bj4 > /dev/null
# cp minivm/minivm bin/minivm
mkdir -p bin
cp bins/boot.bc bin/stage0
for cur in (seq 0 (math $argv[1] - 1))
    set next (math $cur + 1)
    echo building bin/stage$next
    ./minivm/minivm bin/stage$cur -o bin/stage$next src/main.paka
end
