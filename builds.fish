echo -n > out.makes.txt
for dc in gdc ldc2 dmd
    for makecmd in debug release
        set cmd make $makecmd DC=$dc
        echo >> out.makes.txt
        echo $cmd >> out.makes.txt
        cp bin/purr bin/$dc-$makecmd
        /usr/bin/time -f"%es %P" $cmd 2>> out.makes.txt
    end
    for opt in full none
        for ld in lld ldc2 dmd gold clang
            set cmd make bin/purr -Bj DC=$dc LD=$ld OPT=$opt
            echo >> out.makes.txt
            echo $cmd >> out.makes.txt
            cp bin/purr bin/$dc-$ld-$opt
            /usr/bin/time -f"%es %P" $cmd 2>> out.makes.txt
        end
    end
end
rm bin/purr bin/purr.o