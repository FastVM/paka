: rm trace.def trace.log out.dot
dub build --compiler=ldc2 --build=profile
    ./d9c $1 && \
    dub run -q profdump -- -d > out.dot && \
    dot -Tpng out.dot -o out.png