module purr.async;

import core.memory;
import core.thread.fiber;
import std.parallelism;
import purr.dynamic;
import purr.io;
import purr.locks;

alias DynamicTask = Task!(run, Dynamic, Dynamic[])*;

// __gshared 
size_t cur;
// __gshared 
DynamicTask[size_t] tasks;
// __gshared 
Dynamic[size_t] results;

void stopAllAsyncCalls()
{
//     DynamicTask[size_t] next = tasks;
//     foreach (key, value; next)
//     {
//         key.stopAsyncCall;
//     }
}

size_t startAsyncCall(Dynamic func, Dynamic[] pargs)
{
    Dynamic[] args = pargs.dup;
    Dynamic raw = func.async!false;
    size_t taskNum;
    synchronized (taskLock)
    {
        taskNum = cur++;
    }
    DynamicTask theTask = task(raw, args);
    taskPool.put(theTask);
    synchronized (taskLock)
    {
        tasks[taskNum] = theTask;
    }
    return taskNum;
}

Dynamic stopAsyncCall(size_t num)
{
    Dynamic* ret;
    synchronized (taskLock)
    {
        ret = num in results;
    }
    if (ret !is null)
    {
        return *ret;
    }
    else
    {
        DynamicTask theTask;
        synchronized (taskLock)
        {
            theTask = tasks[num];
            tasks.remove(num);
        }
        Dynamic res = theTask.yieldForce;
        synchronized (taskLock)
        {
            results[num] = res;
        }
        return res;
    }
}

// module purr.async;

// import core.thread.osthread;
// import std.parallelism;
// import purr.dynamic;
// import purr.io;
// import purr.locks;

// __gshared size_t cur;
// __gshared Thread[size_t] tasks;
// __gshared Dynamic[size_t] results;

// void stopAllAsyncCalls()
// {
//     Thread[size_t] next = tasks;
//     foreach (key, value; next)
//     {
//         key.stopAsyncCall;
//     }
// }

// size_t startAsyncCall(Dynamic func, Dynamic[] pargs)
// {
//     Dynamic[] args = pargs.dup;
//     Dynamic raw = func.async!false;
//     size_t taskNum;
//     synchronized (taskLock)
//     {
//         taskNum = cur++;
//     }
//     void runme() { 
//         Dynamic dyn = raw(args);
//         synchronized (taskLock)
//         {
//             results[taskNum] = dyn;
//         }
//     }
//     Thread theTask = new Thread(&runme);
//     theTask.start;
//     synchronized (taskLock)
//     {
//         tasks[taskNum] = theTask;
//     }
//     return taskNum;
// }

// Dynamic stopAsyncCall(size_t num)
// {
//     redo:
//     Dynamic* ret;
//     synchronized(taskLock)
//     {
//         ret = num in results;
//     }
//     if (ret !is null)
//     {
//         return *ret;
//     }
//     else
//     {
//         Thread theTask;
//         synchronized (taskLock)
//         {
//             theTask = tasks[num];
//             tasks.remove(num);
//         }
//         theTask.join;
//         return results[num];
//     }
// }

// module purr.async;

// import core.thread.fiber;
// import std.parallelism;
// import purr.dynamic;
// import purr.io;
// import purr.locks;

// __gshared size_t cur;
// __gshared Fiber[size_t] tasks;
// __gshared Dynamic[size_t] results;

// void stopAllAsyncCalls()
// {
//     Fiber[size_t] next = tasks;
//     foreach (key, value; next)
//     {
//         key.stopAsyncCall;
//     }
// }

// size_t startAsyncCall(Dynamic func, Dynamic[] pargs)
// {
//     Dynamic[] args = pargs.dup;
//     Dynamic raw = func.async!false;
//     size_t taskNum;
//     synchronized (taskLock)
//     {
//         taskNum = cur++;
//     }
//     void runme() { 
//         Dynamic dyn = raw(args);
//         synchronized (taskLock)
//         {
//             results[taskNum] = dyn;
//         }
//     }
//     Fiber theTask = new Fiber(&runme);
//     synchronized (taskLock)
//     {
//         tasks[taskNum] = theTask;
//     }
//     return taskNum;
// }

// Dynamic stopAsyncCall(size_t num)
// {
//     redo:
//     Dynamic* ret;
//     synchronized(taskLock)
//     {
//         ret = num in results;
//     }
//     if (ret !is null)
//     {
//         return *ret;
//     }
//     else
//     {
//         Fiber theTask;
//         synchronized (taskLock)
//         {
//             theTask = tasks[num];
//             tasks.remove(num);
//         }
//         theTask.call;
//         return results[num];
//     }
// }
