module lang.loop;

import std.stdio;
import std.conv;
import lang.vm;
import lang.dynamic;
import lang.bytecode;
import lang.data.rope;

alias Cont = void delegate(Dynamic ret);

shared void delegate()[] loopNext;

Cont asPushable(Cont cont)
{
    return (Dynamic ret) { loopNext ~= () { cont(ret); }; };
}

void pushify(ref Cont cont) 
{
    Cont initcont = cont;
    cont = (Dynamic ret) { loopNext ~= () { initcont(ret); }; };
}

void queueEvent(Cont cont, Dynamic fun, Dynamic[] args = null)
{
    loopNext ~= () { fun(cont, args); };
}

void loopRun(T...)(Cont retcont, Function func, Dynamic[] args, T rest)
{
    run(retcont, func, args, rest);
    while (loopNext.length > 0)
    {
        loopNext[0]();
        loopNext = loopNext[1 .. $];
    }
}
