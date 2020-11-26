module lang.loop;

import std.stdio;
import std.conv;
import lang.vm;
import lang.dynamic;
import lang.bytecode;
import lang.data.rope;
import std.algorithm;

alias Cont = void delegate(Dynamic ret);

immutable(void delegate())[] queue;

void push(immutable void delegate() val)
{
    queue ~= val;
}

Cont asPushable(Cont cont)
{
    return (Dynamic ret) { () { cont(ret); }.push; };
}

void pushify(ref Cont cont)
{
    Cont initcont = cont;
    cont = (Dynamic ret) { () { initcont(ret); }.push; };
}

version (parallel)
{
    import std.concurrency;
    import core.thread;
    import core.atomic;

    shared size_t checkin = 1;

    enum Status
    {
        dead,
    }

    void mainRunner(Tid owner, size_t me)
    {
        bool running = true;
        while (running)
        {
            receive((immutable void delegate() cur) {
                size_t ran = 0;
                cur();
                while (queue.length > 0)
                {
                    while (queue.length > 1)
                    {
                        send(owner, queue[0]);
                        queue = queue[1 .. $];
                    }
                    queue[0]();
                    queue = queue[1 .. $];
                    ran++;
                }
                immutable(void delegate())[] oldqueue = queue;
                queue = null;
                foreach (i; oldqueue)
                {
                    send(owner, i);
                }
                queue = null;
                send(owner, me);
            }, (Status st) { send(owner, st); running = false; });
        }
    }


    size_t cpuThreadsSpec = 1;

    void loopRun(T...)(Cont retcont, Function func, Dynamic[] args, T rest)
    {
        Tid[] tids;
        bool[] available;
        size_t running = cpuThreadsSpec;
        foreach (me; 0 .. running)
        {
            Tid tid = spawn(&mainRunner, thisTid, me);
            tids ~= tid;
            available ~= true;
        }
        void enque(T)(T v)
        {
            foreach (i, tid; tids)
            {
                if (available[i])
                {
                    available[i] = false;
                    send(tid, v);
                    return;
                }
            }
            v.push;
        }

        run((Dynamic args) {
            foreach (tid; tids)
            {
                send(tid, Status.dead);
            }
            retcont(args);
        }, func, args, rest);
        immutable(void delegate())[] oldqueue = queue;
        queue = null;
        foreach (i; oldqueue)
        {
            enque(i);
        }
        while (running != 0)
        {
            receive((immutable void delegate() ask) { enque(ask); }, (Status st) {
                running--;
            }, (size_t flip) {
                if (queue.length != 0)
                {
                    send(tids[flip], queue[0]);
                    queue = queue[1 .. $];
                }
                else
                {
                    available[flip] = true;
                }
            });
        }
    }
}
else
{
    void loopRun(T...)(Cont retcont, Function func, Dynamic[] args, T rest)
    {
        run(retcont, func, args, rest);
        while (queue.length != 0) {
            void delegate() cur = queue[0];
            queue = queue[1 .. $];
            cur();
        }    
    }
}