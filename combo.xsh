#!/usr/bin/env xonsh

echo "#!/usr/bin/env bash" > test.sh
echo "rm -f res.txt" >> test.sh
echo "rm -f dexts/*" >> test.sh

do_opt = True

opts = ["none"]
opts.append("all")

count = 0
for DC in ["dmd", "ldc2"]:
    for LD in ["dmd", "ldc2", "clang", "gcc", "ld.gold", "ld.bfd"]:
        extra = []
        if DC == "ldc2":
            extra.append("size")
        for OPT in opts + extra:
            # echo f"echo make dext quest -j DC={DC} LINK={LD} OPT={OPT}" >> test.sh
            echo f"echo make dext quest -j DC={DC} LINK={LD} OPT={OPT} >> res.txt" >> test.sh
            echo f"make clean && /usr/bin/time -f'{DC} {LD} {OPT}: %es' make dext quest -j DC={DC} LINK={LD} OPT={OPT} >> res.txt" >> test.sh
            echo f"mv dext dexts/dext.{DC}_{LD}_{OPT}" >> test.sh
            echo f"mv out/lib/libdext_quest.so dexts/libdext_quest.so.{DC}_{LD}_{OPT}" >> test.sh
            echo f"echo >> res.txt" >> test.sh
            echo >> test.sh
            # /usr/bin/time -f%es make dext quest
            # assert (./dext --load quest test/quest/test.sj).strip() == 'quest: good day'
            # assert (./dext test/good/test.dext).strip() == 'dext: howdy'
            count += 1

print(f"generated {count} cases")
