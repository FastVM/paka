#!/usr/bin/env sh

SRCDIR=$(dirname $0)

LUAJIT=luajit
MINIVM=./bin/minivm
CC=cc
NODE=node

FIBN=40

$CC -O3 bench/fib.c -o bin/opt-fib
$CC -Ofast bench/ffib.c -o bin/opt-ffib

cd $SRCDIR && hyperfine --warmup 5 --runs 15 \
    "./bin/opt-fib $FIBN" \
    "$LUAJIT bench/fib.lua $FIBN" \
    "./bin/opt-ffib $FIBN" \
    "$NODE bench/fib.js $FIBN" \
    "$MINIVM bins/boot.bc bench/fib.paka -- $FIBN" \
    "$LUAJIT -joff bench/fib.lua $FIBN"