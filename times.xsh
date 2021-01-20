for $i in $(ls out/*/time.txt).split(): 
    echo @($(cat $i)[:-1]) $i 