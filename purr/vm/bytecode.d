module purr.vm.bytecode;

import purr.io;
import core.memory;

alias Number = double;
alias String = immutable(char)*;

extern (C) void vm_run(VM* vm, Function *func, void* argv);

struct VM
{
    void* linear;
    Frame* frames;
}

struct Frame
{
    int index;
    void* argv;
    void* stack;
    void* locals;
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
}

alias Bytecode = Function*;
struct Function
{
    void* bytecode;
    int stackSize;
    int localSize;
    int bytecodeLength;

    static Function* empty()
    {
        Function* ret = cast(Function*) GC.calloc(Function.sizeof);
        ret.bytecode = new void[2 ^^ 16].ptr;
        ret.stackSize = 256;
        ret.localSize = 256;
        return ret;
    }
}

enum Opcode : char
{
    exit,
    return_nil,
    return1,
    return2,
    return4,
    return8,
    push1,
    push2,
    push4,
    push8,
    pop1,
    pop2,
    pop4,
    pop8,
    arg1,
    arg2,
    arg4,
    arg8,
    store1,
    store2,
    store4,
    store8,
    load1,
    load2,
    load4,
    load8,
    add_float,
    sub_float,
    mul_float,
    div_float,
    mod_float,
    add_integer,
    sub_integer,
    mul_integer,
    div_integer,
    mod_integer,
    not,
    neg_float,
    lt_float,
    gt_float,
    lte_float,
    gte_float,
    eq_float,
    neq_float,
    print_float,
    neg_integer,
    lt_integer,
    gt_integer,
    lte_integer,
    gte_integer,
    eq_integer,
    neq_integer,
    print_integer,
    jump,
    iftrue,
    iffalse,
    call,
    rec,
    ec_cons,
    ec_call,
    max1,
    max2p = 128,
}
