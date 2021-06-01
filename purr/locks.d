module purr.locks;

import core.sync.mutex;

__gshared Mutex taskLock;

shared static this()
{
    taskLock = new Mutex;
}