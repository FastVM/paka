module lang.lib.thread;

import lang.dynamic;
import lang.base;
import lang.vm;
import std.process;
import std.conv;
import std.stdio;
import core.thread.osthread;

Pair[] libthread()
{
    Pair[] ret = [Pair("from", &libcall)];
    return ret;
}

void libcall(Cont cont, Args args)
{
    void fun() {
        args[0](cont, args[1..$]);
    }
    Thread thread = new Thread(&fun);
    Table obj = new Table;
    obj[dynamic("start")] = dynamic((Cont cont, Args args) {
        thread.start();
        cont(Dynamic.nil);
    });
    obj[dynamic("join")] = dynamic((Cont cont, Args args) {
        thread.join();
        cont(Dynamic.nil);
    });
    cont(dynamic(obj));
}
