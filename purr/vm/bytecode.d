module purr.vm.bytecode;

import core.memory;

alias Number = double;
alias String = immutable(char)*;

struct State;

extern (C) {
    void vm_run(State* state, size_t len, void* func);
    State* vm_state_new();
    void vm_state_del(State *);
}

enum Opcode : uint {
    exit,
    store_reg,
    store_none,
    store_bool,
    store_int,
    store_fun,
    fun_done,
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
    jump,
    branch_false,
    branch_true,
    branch_equal,
    branch_equal_num,
    branch_not_equal,
    branch_not_equal_num,
    branch_less,
    branch_less_num,
    branch_greater,
    branch_greater_num,
    branch_less_than_equal,
    branch_less_than_equal_num,
    branch_greater_than_equal,
    branch_greater_than_equal_num,
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
    concat,
    static_call0,
    static_call1,
    static_call2,
    static_call,
    tail_call0,
    tail_call1,
    tail_call2,
    tail_call,
    call0,
    call1,
    call2,
    call,
    ret,
    putchar,
    ref_new,
    box_new,
    string_new,
    array_new,
    map_new,
    ref_get,
    // ref_set,
    box_get,
    box_set,
    length,
    index_get,
    index_set,
    type,
    call_handler,
    set_handler,
    return_handler,
    exit_handler,
    exec,
}

bool noOutputs(Opcode op) {
    return op == Opcode.putchar 
        || op == Opcode.ret
        || op == Opcode.exit;
}

bool isJump(Opcode op) {
    return op == Opcode.jump
        || op == Opcode.branch_false 
        || op == Opcode.branch_true 
        || op == Opcode.branch_equal 
        || op == Opcode.branch_equal_num 
        || op == Opcode.branch_not_equal 
        || op == Opcode.branch_not_equal_num 
        || op == Opcode.branch_less 
        || op == Opcode.branch_less_num 
        || op == Opcode.branch_greater 
        || op == Opcode.branch_greater_num 
        || op == Opcode.branch_less_than_equal 
        || op == Opcode.branch_less_than_equal_num 
        || op == Opcode.branch_greater_than_equal 
        || op == Opcode.branch_greater_than_equal_num;
}