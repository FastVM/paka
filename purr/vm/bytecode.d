module purr.vm.bytecode;

import purr.io;
import core.memory;

alias Number = double;
alias String = immutable(char)*;

extern (C) void vm_run(Function* func);

struct Frame {
    int index;
    void* argv;
    void* stack;
    void* locals;
    Function func;
}

enum Local {
    none = 0,
    arg = 1,
}

enum Capture {
    local,
    arg,
}

alias Bytecode = Function*;
struct Function {
    void* bytecode;

    static Function* empty() {
        Function* ret = cast(Function*) GC.calloc(Function.sizeof);
        return ret;
    }
}

enum Opcode : char {
    exit,
    store_reg,
    store_log,
    store_num,
    store_fun,
    equal,
    equal_num,
    not_equal,
    not_equal_num,
    less,
    less_num,
    greater,
    greater_num,
    less_than_equal,
    less_than_equal_num,
    greater_than_equal,
    greater_than_equal_num,
    jump_always,
    jump_if_false,
    jump_if_true,
    jump_if_equal,
    jump_if_equal_num,
    jump_if_not_equal,
    jump_if_not_equal_num,
    jump_if_less,
    jump_if_less_num,
    jump_if_greater,
    jump_if_greater_num,
    jump_if_less_than_equal,
    jump_if_less_than_equal_num,
    jump_if_greater_than_equal,
    jump_if_greater_than_equal_num,
    inc,
    inc_num,
    dec,
    dec_num,
    add,
    add_num,
    sub,
    sub_num,
    mul,
    mul_num,
    div,
    div_num,
    mod,
    mod_num,
    call,
    rec,
    ret,
    println,
    max1,
    max2p = 128,
}
