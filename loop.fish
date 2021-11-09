echo building bin/minivm
gmake -C minivm -Bj10 > /dev/null
echo building bin/stage1
gmake -B bin/stage1 > /dev/null
for cur in (seq 1 (math $argv[1] - 1))
    set next (math $cur + 1)
    echo building bin/stage$next
    ./minivm/minivm bin/stage$cur -o bin/stage$next src/paka.paka
end
