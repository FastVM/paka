#!/usr/bin/env sh

SRCDIR=$(dirname $0)

LUAJIT=luajit
MINIVM=./bin/minivm
CC=cc
NODE=node

for TREE in $(seq 8 20)
do 
    $CC -Ofast bench/tree.c -o bin/opt-tree

    cd $SRCDIR && hyperfine --warmup 3 --runs 10 \
        "$NODE bench/tree.js $TREE" \
        "$MINIVM bins/boot.bc bench/tree.paka -- $TREE" \
        "./bin/opt-tree $TREE" \
        "$LUAJIT bench/tree.lua $TREE"
done