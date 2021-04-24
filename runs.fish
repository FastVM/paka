set cmds 
for run in (ls bin)
    set cmd bin/$run --file bench/paka/fib.paka
    set cmds $cmds "$cmd"
    set cmd bin/$run --file bench/passerine/src/fib.pn
    set cmds $cmds "$cmd"
end

hyperfine --warmup 3 $cmds