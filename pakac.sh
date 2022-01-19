#!/usr/bin/env sh

set -e

if test ! "$DC"
then
    if test ! "$DC"
    then
        echo "could not find D compiler for commnands ldc2 or dmd"
        echo "rerun with prefix:"
        echo "  env DC=dmd"
        echo "  env DC=ldc2"
        exit
    fi
fi

if test "$1" == ""
then
    echo "please give this script a .paka file as an argument"
    exit
fi

if test ! "$1"
then
    echo "could not find input file: $1"
fi

OUTFILE=bin/$(basename $1 .paka)

PAKA="$(dirname $0)"
MVM="$PAKA/minivm"

make -C "$MVM" HOST=D DC="$DC" > /dev/null

mkdir -p "$MVM"/bin

test -f "$MVM"/bin/boot.bc && rm "$MVM"/bin/boot.bc

"$MVM"/minivm "$PAKA"/bins/boot.bc "$1" -o "$MVM"/bin/boot.bc

mkdir -p bin

$DC -i -I"$MVM" "$MVM"/vm/tod.d -of"$MVM"/bin/tod

"$MVM"/bin/tod "$MVM"/bin/boot.bc > "$OUTFILE".d

$DC -betterC $DFLAGS "$OUTFILE".d -of"$OUTFILE"
