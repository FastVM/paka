module purr.vm.bytecode;

import purr.dynamic;
import std.stdio;
import core.memory;

alias Number = double;
alias String = immutable(char)*;

extern(C) Dynamic vm_run(VM *vm, Bytecode func, int argc, Dynamic* argv);

struct List
{
    long length;
    long alloc;
    void[0] values;

pragma(inline, true)
    static List* empty(T)()
    {
        return array_new(T.sizeof);
    }
}

void ensure(T)(ref List* self, long index)
{
    array_ensure(T.sizeof, self, index);
}

void push(T)(ref List* self, T arg)
{
    array_push(T.sizeof, self, cast(void*) &arg);
}

ref T index(T)(const List* self, long index)
{
    return *cast(T*) array_index(T.sizeof, self, index);
}

ref T pop(T)(ref List* self)
{
    return *cast(T*) array_pop(T.sizeof, self);
}

T* ptr(T)(List* self)
{
    return cast(T*) &self.values;
}

extern (C)
{
    List* array_new(int elem_size);
    void array_ensure(int elem_size, ref List* arr, long index);
    void* array_index(int elem_size, const List* arr, long index);
    void array_push(int elem_size, ref List* arr, void *value);
    void* array_pop(int elem_size, ref List* arr_ptr);
}

struct VM
{
    List* linear;
    Frame* framesLow;
    Frame* framesHigh;
}

struct Frame
{
    int index;
    int argc;
    Dynamic *argv;
    Dynamic *stack;
    Dynamic *locals;
    Function func;
}

enum Local
{
    none = 0,
    arg = 1,
}

enum Capture
{
    local,
    arg,
    parent,
}

alias Bytecode = Function*;
struct Function
{
    List* bytecode;
    Bytecode parent;
    List* captureFrom;
    List* captureFlags;
    int stackSize;
    int localSize;
    List* captured;

    static Function* from(Function* last)
    {
        Function* ret = cast(Function*) GC.calloc(Function.sizeof);
        ret.parent = last;
        ret.bytecode = List.empty!(int);
        ret.captureFrom = List.empty!(int);
        ret.captureFlags = List.empty!(int);
        ret.stackSize = 128;
        ret.localSize = 128;
        return ret;
    }
}

enum Opcode : char
{
    ret,
    exit,
    push,
    pop,
    arg,
    store,
    load,
    loadc,
    add,
    sub,
    mul,
    div,
    mod,
    neg,
    lt,
    gt,
    lte,
    gte,
    eq,
    neq,
    print,
    jump,
    iftrue,
    iffalse,
    call,
    rec,
    func,
    max1,
    max2p = 128,
}


extern (C) void vm_impl_print(Dynamic arg)
{
    write(arg);
}