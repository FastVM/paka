module lang.loop;

import std.stdio;
import std.conv;
import std.algorithm;
import core.memory;
import lang.vm;
import lang.dynamic;
import lang.bytecode;
import lang.data.rope;
import core.atomic;

alias RawCont = void delegate(Dynamic ret);

version (threads)
{
    import std.parallelism : parallel, TaskPool, task;

    size_t cpuThreadsSpec = 1;
    __gshared TaskPool pool = null;


    struct Cont
    {
        RawCont cont;
        Dynamic arg;
        this(T...)(RawCont c)
        {
            cont = c;
        }

        void opCall() immutable
        {
            cont(arg);
        }

        void opCall(Dynamic a)
        {
            arg = a;
            pool.put(task(cont, arg));
        }
    }

    Cont asCont(RawCont cont)
    {
        return Cont(cont);
    }

    void loopRun(A, T...)(A retcont, T args)
    {
        pool = new TaskPool(cpuThreadsSpec);
        run((Dynamic arg) {
            retcont(arg);
            pool.stop;
        }.asCont, args);
    }

}
else
{
    struct Cont
    {
        RawCont cont;
        Dynamic arg;
        this(T...)(RawCont c)
        {
            cont = c;
        }

        void opCall() immutable
        {
            cont(arg);
        }

        void opCall(Dynamic a)
        {
            arg = a;
            synchronized
            {
                queue ~= this;
            }
        }
    }

    immutable(Cont)[] queue;

    Cont asCont(RawCont cont)
    {
        return Cont(cont);
    }

    void loopRun(T...)(T args)
    {
        run(args);
        while (queue.length != 0)
        {
            immutable Cont cur = queue[$ - 1];
            queue.length--;
            cur();
        }
    }
}
