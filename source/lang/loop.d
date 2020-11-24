module lang.loop;

import std.stdio;
import lang.vm;
import lang.dynamic;
import lang.bytecode;
import lang.data.rope;

alias Cont = void delegate(Dynamic ret);

void delegate()[] loopNext;

Cont asPushable(Cont cont)
{
    return (Dynamic ret) { loopNext ~= () { cont(ret); }; };
}

void pushify(ref Cont cont)
{
    Cont initcont = cont;
    cont = (Dynamic ret) { loopNext = loopNext ~ () { initcont(ret); }; };
}

void loopRun(T...)(Cont retcont, Function func, Dynamic[] args, T rest)
{
    run(retcont, func, args, rest);
    while (loopNext.length != 0)
    {
        void delegate() cur = loopNext[$-1];
        loopNext.length--;
        cur();
    }
}
