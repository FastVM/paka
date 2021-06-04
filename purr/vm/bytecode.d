module purr.vm.bytecode;

import purr.dynamic;
import std.stdio;
import core.memory;

alias Number = double;
alias String = immutable(char)*;

extern(C) Dynamic vm_run(VM *vm, Bytecode func, int argc, Dynamic* argv, bool is_run1);

struct List
{
    int length;
    int alloc;
    void[0] values;

    static List* empty(T)()
    {
        return array_new(T.sizeof);
    }
}

void ensure(T)(ref List* self, int index)
{
    array_ensure(T.sizeof, self, index);
}

void push(T)(ref List* self, T arg)
{
    array_push(T.sizeof, self, cast(void*) &arg);
}

ref T index(T)(List* self, int index)
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
    void array_ensure(int elem_size, ref List* arr, int index);
    void* array_index(int elem_size, List* arr, int index);
    void array_push(int elem_size, ref List* arr, void *value);
    void* array_pop(int elem_size, ref List* arr_ptr);
}

struct VM
{
    List* frames;
    List* linear;
}

enum Local
{
    none = 0,
    arg = 1,
}

enum Capture
{
    parent_local,
    parent_arg,
    parent_capture,
}

alias Bytecode = Function*;
struct Function
{
    List* bytecode;
    List* constants;
    Bytecode parent;
    List* localNames;
    List* localFlags;
    List* captureNames;
    List* captureFrom;
    List* captureFlags;
    int stackSize;
    int localSize;
    List* captured;

    static Function* empty(Function* last)
    {
        Function* ret = cast(Function*) GC.malloc(Function.sizeof);
        ret.parent = last;
        ret.bytecode = List.empty!(int);
        ret.constants = List.empty!(Dynamic);
        ret.localNames = List.empty!(char *);
        ret.localFlags = List.empty!(int);
        ret.captureNames = List.empty!(char *);
        ret.captureFrom = List.empty!(int);
        ret.captureFlags = List.empty!(int);
        ret.stackSize = 32;
        ret.localSize = 32;
        return ret;
    }
}

enum Opcode
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
    tailrec,
    func,
    max1,
    max2p = 128,
}


extern (C) void vm_impl_println(Dynamic arg)
{
    writeln(arg);
}