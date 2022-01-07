#!/usr/bin/env sh

SRCDIR=$(dirname $0)

LUAJIT=luajit
MINIVM=./bin/minivm
CC=cc
NODE=node

TREE=20

$CC -Ofast bench/tree.c -o bin/opt-tree

printf "%s\n" "$NODE bench/tree.js $TREE"
time $NODE bench/tree.js $TREE > /dev/null
echo

printf "%s\n" "$MINIVM bins/boot.bc bench/tree.paka -- $TREE"
time $MINIVM bins/boot.bc bench/tree.paka -- $TREE > /dev/null
echo

printf "%s\n" "./bin/opt-tree $TREE"
time ./bin/opt-tree $TREE > /dev/null
echo

printf "%s\n" "$LUAJIT bench/tree.lua $TREE"
time $LUAJIT bench/tree.lua $TREE > /dev/null
echo
