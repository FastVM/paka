echo building bin/stage1
gmake -j8 bin/stage1 > /dev/null
for cur in (seq (math $argv[1] - 1))
    set next (math $cur + 1)
    echo building bin/stage$next
    ./bin/minivm bin/stage$cur -o bin/stage$next src/paka.paka
end