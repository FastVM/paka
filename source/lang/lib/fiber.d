module lang.lib.fiber;

import lang.dynamic;
import lang.base;
import lang.error;
import std.typecons;
import std.process;
import std.algorithm;
import std.stdio;
import std.conv;
import core.thread.fiber;

Pair[] libfiber()
{
    Pair[] ret = [Pair("cons", &libcons), Pair("yield", &libyield)];
    return ret;
}

private:

class DynamicFiber : Fiber {
    Dynamic func;
    Dynamic ret;
    Args args;
    this(Dynamic f) {
        super(&run);
        func = f;
    }
    void run() {
        ret = func(args);
        Fiber.yield;
    }
    Dynamic dextCall(Args argv) {
        args = argv;
        call();
        return ret;
    }
}

Dynamic libcons(Args args)
{
    DynamicFiber fiber = new DynamicFiber(args[0]);
    Table table = new Table();
    table.native = cast(Object) fiber;
    table.set(dynamic("call"), dynamic(&fiber.dextCall));
    return dynamic(table);
}

Dynamic libyield(Args args)
{
    DynamicFiber fiber = cast(DynamicFiber) args[0].tab.native;
    if (args.length == 0)
    {
        fiber.ret = Dynamic.nil;
    }
    else
    {
        fiber.ret = args[0];
    }
    Fiber.yield;
    return fiber.ret;
}
