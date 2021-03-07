module paka.lib.math;

import purr.dynamic;
import purr.base;
import purr.error;
import purr.ast;
import purr.parse;
import purr.ir.walk;
import purr.vm;
import purr.inter;
import purr.srcloc;
import purr.bytecode;
import paka.parse;
import core.stdc.stdlib;
import core.runtime;
import std.algorithm;
import std.array;
import std.conv;
import std.random;
import purr.io;

typeof(MinstdRand0(0)) rnd;

Pair[] libmath()
{
    Pair[] ret = [];
    ret.addLib("random", librand);
    return ret;
}

Pair[] librand()
{
    rnd = MinstdRand0(unpredictableSeed);
    Pair[] ret = [];
    ret ~= FunctionPair!libseed("seed");
    ret ~= FunctionPair!librandom("range");
    return ret;
}

Dynamic libseed(Dynamic[] args)
{
    rnd = MinstdRand0(cast(uint) args[0].as!size_t);
    return Dynamic.nil;
}

Dynamic librandom(Dynamic[] args)
{
    if (args.length == 0)
    {
        return uniform(0, 1).dynamic;
    }
    if (args.length == 1)
    {
        return uniform(0, args[0].as!double, rnd).dynamic;
    }
    if (args.length == 2)
    {
        return uniform(args[0].as!double, args[1].as!double, rnd).dynamic;
    }
    throw new Exception("too many arguments");
}