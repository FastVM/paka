
typedef _Bool bool;
#define false ((bool)0)
#define true ((bool)1)

#define NULL ((void *)0)

void *vm_alloc(int size);
int printf(const char *fmt, ...);
double fmod(double lhs, double rhs);

typedef char val1_t;
typedef short val2_t;
typedef int val4_t;
typedef long val8_t;

_Static_assert(sizeof(val1_t) == 1, "sizeof(val1_t) != 1");
_Static_assert(sizeof(val2_t) == 2, "sizeof(val2_t) != 2");
_Static_assert(sizeof(val4_t) == 4, "sizeof(val4_t) != 4");
_Static_assert(sizeof(val8_t) == 8, "sizeof(val8_t) != 8");

#ifdef __clang__
#define vm_assume(expr) (__builtin_assume(expr))
#else
#define vm_assume(expr) ((void)0)
#endif

typedef double float_t;
typedef long integer_t;
typedef char opcode_t;

struct func_t;
struct vm_t;
struct cont_t;
union value_t;
enum errro_t;

typedef struct vm_t vm_t;
typedef struct func_t func_t;
typedef struct cont_t cont_t;
typedef enum error_t error_t;

enum error_t
{
    VM_ERROR_UNKNOWN,
    VM_ERROR_OOM,
    VM_ERROR_OPCODE,
};

enum local_flags_t
{
    LOCAL_FLAGS_NONE = 0,
    LOCAL_FLAGS_ARG = 1,
};

struct func_t
{
    void *bytecode;
    int stack_used;
    int locals_used;
};

enum opcode_t
{
    OPCODE_EXIT,
    OPCODE_RETURN_NIL,
    OPCODE_RETURN1,
    OPCODE_RETURN2,
    OPCODE_RETURN4,
    OPCODE_RETURN8,
    OPCODE_PUSH1,
    OPCODE_PUSH2,
    OPCODE_PUSH4,
    OPCODE_PUSH8,
    OPCODE_POP1,
    OPCODE_POP2,
    OPCODE_POP4,
    OPCODE_POP8,
    OPCODE_ARG1,
    OPCODE_ARG2,
    OPCODE_ARG4,
    OPCODE_ARG8,
    OPCODE_STORE1,
    OPCODE_STORE2,
    OPCODE_STORE4,
    OPCODE_STORE8,
    OPCODE_LOAD1,
    OPCODE_LOAD2,
    OPCODE_LOAD4,
    OPCODE_LOAD8,
    OPCODE_ADD_FLOAT,
    OPCODE_SUB_FLOAT,
    OPCODE_MUL_FLOAT,
    OPCODE_DIV_FLOAT,
    OPCODE_MOD_FLOAT,
    OPCODE_ADD_INTEGER,
    OPCODE_SUB_INTEGER,
    OPCODE_MUL_INTEGER,
    OPCODE_DIV_INTEGER,
    OPCODE_MOD_INTEGER,
    OPCODE_NOT,
    OPCODE_NEG_FLOAT,
    OPCODE_LT_FLOAT,
    OPCODE_GT_FLOAT,
    OPCODE_LTE_FLOAT,
    OPCODE_GTE_FLOAT,
    OPCODE_EQ_FLOAT,
    OPCODE_NEQ_FLOAT,
    OPCODE_PRINT_FLOAT,
    OPCODE_NEG_INTEGER,
    OPCODE_LT_INTEGER,
    OPCODE_GT_INTEGER,
    OPCODE_LTE_INTEGER,
    OPCODE_GTE_INTEGER,
    OPCODE_EQ_INTEGER,
    OPCODE_NEQ_INTEGER,
    OPCODE_PRINT_INTEGER,
    OPCODE_JUMP,
    OPCODE_IFTRUE,
    OPCODE_IFFALSE,
    OPCODE_CALL,
    OPCODE_REC,
    OPCODE_EC_CONS,
    OPCODE_EC_CALL,
    OPCODE_MAX1,
    OPCODE_MAX2P = 128,
};

#ifdef VM_DEBUG
#define debug_op \
    printf("%i: %i\n", cur_index, cur_bytecode[cur_index]);
#else
#define debug_op
#endif

typedef struct
{
    int index;
    void *argv;
    void *stack;
    void *locals;
    func_t func;
} stack_frame_t;

#define vm_set_frame(frame_arg) (         \
    {                                     \
        stack_frame_t frame = frame_arg;  \
        cur_index = frame.index;          \
        cur_argv = frame.argv;            \
        cur_stack = frame.stack;          \
        cur_locals = frame.locals;        \
        cur_func = frame.func;            \
        cur_bytecode = cur_func.bytecode; \
    })

#define vm_get_frame() \
    (stack_frame_t)             \
    {                           \
        .index = cur_index,     \
        .argv = cur_argv,       \
        .stack = cur_stack,     \
        .locals = cur_locals,   \
        .func = cur_func,       \
    }

struct vm_t
{
    void *linear;
    stack_frame_t *frames;
};

struct cont_t
{
    vm_t vm;
    stack_frame_t frame;
    int frame_number;
};

#define run_next_op                                   \
    vm_assume(cur_bytecode[cur_index] < OPCODE_MAX1); \
    vm_assume(cur_bytecode[cur_index] >= 0);          \
    debug_op goto *ptrs[cur_bytecode[cur_index++]];

#define cur_bytecode_next(Type) (                     \
    {                                                 \
        Type ret = *(Type *)&cur_bytecode[cur_index]; \
        cur_index += sizeof(Type);                    \
        ret;                                          \
    })

#define cur_stack_peek(Type) (*(Type *)(cur_stack - sizeof(Type)))
#define cur_stack_pop(Type) (cur_stack -= sizeof(Type), (void)0)
#define cur_stack_load_pop(Type) (cur_stack_pop(Type), *(Type *)cur_stack)
#define cur_stack_push(Type, value) ( \
    {                                 \
        *(Type *)cur_stack = value;   \
        cur_stack += sizeof(Type);    \
    })

void vm_error(error_t err)
{
    printf("error: (todo)");
}

void vm_run(vm_t *pvm, func_t *basefunc, void *argv)
{
    vm_t vm = *pvm;
    int frame_number = 0;
    stack_frame_t next = (stack_frame_t){
        .func = *basefunc,
        .argv = argv,
        .index = 0,
    };
    int cur_index;
    int cur_argc;
    void *cur_argv;
    func_t cur_func;
    void *cur_stack;
    void *cur_locals;
    opcode_t *cur_bytecode;
    void *ptrs[OPCODE_MAX2P] = {NULL};
    ptrs[OPCODE_RETURN_NIL] = &&do_return_nil;
    ptrs[OPCODE_RETURN1] = &&do_return1;
    ptrs[OPCODE_RETURN2] = &&do_return2;
    ptrs[OPCODE_RETURN4] = &&do_return4;
    ptrs[OPCODE_RETURN8] = &&do_return8;
    ptrs[OPCODE_EXIT] = &&do_exit;
    ptrs[OPCODE_PUSH1] = &&do_push1;
    ptrs[OPCODE_PUSH2] = &&do_push2;
    ptrs[OPCODE_PUSH4] = &&do_push4;
    ptrs[OPCODE_PUSH8] = &&do_push8;
    ptrs[OPCODE_POP1] = &&do_pop1;
    ptrs[OPCODE_POP2] = &&do_pop2;
    ptrs[OPCODE_POP4] = &&do_pop4;
    ptrs[OPCODE_POP8] = &&do_pop8;
    ptrs[OPCODE_ARG1] = &&do_arg1;
    ptrs[OPCODE_ARG2] = &&do_arg2;
    ptrs[OPCODE_ARG4] = &&do_arg4;
    ptrs[OPCODE_ARG8] = &&do_arg8;
    ptrs[OPCODE_STORE1] = &&do_store1;
    ptrs[OPCODE_STORE2] = &&do_store2;
    ptrs[OPCODE_STORE4] = &&do_store4;
    ptrs[OPCODE_STORE8] = &&do_store8;
    ptrs[OPCODE_LOAD1] = &&do_load1;
    ptrs[OPCODE_LOAD2] = &&do_load2;
    ptrs[OPCODE_LOAD4] = &&do_load4;
    ptrs[OPCODE_LOAD8] = &&do_load8;
    ptrs[OPCODE_ADD_FLOAT] = &&do_add_float;
    ptrs[OPCODE_SUB_FLOAT] = &&do_sub_float;
    ptrs[OPCODE_MUL_FLOAT] = &&do_mul_float;
    ptrs[OPCODE_DIV_FLOAT] = &&do_div_float;
    ptrs[OPCODE_MOD_FLOAT] = &&do_mod_float;
    ptrs[OPCODE_ADD_INTEGER] = &&do_add_integer;
    ptrs[OPCODE_SUB_INTEGER] = &&do_sub_integer;
    ptrs[OPCODE_MUL_INTEGER] = &&do_mul_integer;
    ptrs[OPCODE_DIV_INTEGER] = &&do_div_integer;
    ptrs[OPCODE_MOD_INTEGER] = &&do_mod_integer;
    ptrs[OPCODE_NOT] = &&do_not;
    ptrs[OPCODE_NEG_FLOAT] = &&do_neg_float;
    ptrs[OPCODE_LT_FLOAT] = &&do_lt_float;
    ptrs[OPCODE_GT_FLOAT] = &&do_gt_float;
    ptrs[OPCODE_LTE_FLOAT] = &&do_lte_float;
    ptrs[OPCODE_GTE_FLOAT] = &&do_gte_float;
    ptrs[OPCODE_EQ_FLOAT] = &&do_eq_float;
    ptrs[OPCODE_NEQ_FLOAT] = &&do_neq_float;
    ptrs[OPCODE_PRINT_FLOAT] = &&do_print_float;
    ptrs[OPCODE_NEG_INTEGER] = &&do_neg_integer;
    ptrs[OPCODE_LT_INTEGER] = &&do_lt_integer;
    ptrs[OPCODE_GT_INTEGER] = &&do_gt_integer;
    ptrs[OPCODE_LTE_INTEGER] = &&do_lte_integer;
    ptrs[OPCODE_GTE_INTEGER] = &&do_gte_integer;
    ptrs[OPCODE_EQ_INTEGER] = &&do_eq_integer;
    ptrs[OPCODE_NEQ_INTEGER] = &&do_neq_integer;
    ptrs[OPCODE_PRINT_INTEGER] = &&do_print_integer;
    ptrs[OPCODE_JUMP] = &&do_jump;
    ptrs[OPCODE_IFTRUE] = &&do_iftrue;
    ptrs[OPCODE_IFFALSE] = &&do_iffalse;
    ptrs[OPCODE_CALL] = &&do_call;
    ptrs[OPCODE_REC] = &&do_rec;
    ptrs[OPCODE_EC_CONS] = &&do_ec_cons;
    ptrs[OPCODE_EC_CALL] = &&do_ec_call;
    goto first_call;
rec_call:
    vm.frames[frame_number++] = (stack_frame_t){
        .index = cur_index,
        .argv = cur_argv,
        .func = cur_func,
        .stack = cur_stack,
        .locals = cur_locals,
    };
first_call:
    vm_set_frame(next);
    cur_stack = vm.linear;
    cur_locals = cur_stack + cur_func.stack_used;
    vm.linear += cur_func.stack_used + cur_func.locals_used;
    run_next_op;
do_return_nil:
{
    vm.linear -= cur_func.stack_used + cur_func.locals_used;
    vm_set_frame(vm.frames[--frame_number]);
    run_next_op;
}
do_return1:
{
    val1_t retval = cur_stack_load_pop(val1_t);
    vm.linear -= cur_func.stack_used + cur_func.locals_used;
    vm_set_frame(vm.frames[--frame_number]);
    cur_stack_push(val1_t, retval);
    run_next_op;
}
do_return2:
{
    val2_t retval = cur_stack_load_pop(val2_t);
    vm.linear -= cur_func.stack_used + cur_func.locals_used;
    vm_set_frame(vm.frames[--frame_number]);
    cur_stack_push(val2_t, retval);
    run_next_op;
}
do_return4:
{
    val4_t retval = cur_stack_load_pop(val4_t);
    vm.linear -= cur_func.stack_used + cur_func.locals_used;
    vm_set_frame(vm.frames[--frame_number]);
    cur_stack_push(val4_t, retval);
    run_next_op;
}
do_return8:
{
    val8_t retval = cur_stack_load_pop(val8_t);
    vm.linear -= cur_func.stack_used + cur_func.locals_used;
    vm_set_frame(vm.frames[--frame_number]);
    cur_stack_push(val8_t, retval);
    run_next_op;
}
do_exit:
{
    return;
}
do_push1:
{
    val1_t val = cur_bytecode_next(val1_t);
    cur_stack_push(val1_t, val);
    run_next_op;
}
do_push2:
{
    val2_t val = cur_bytecode_next(val2_t);
    cur_stack_push(val2_t, val);
    run_next_op;
}
do_push4:
{
    val4_t val = cur_bytecode_next(val4_t);
    cur_stack_push(val4_t, val);
    run_next_op;
}
do_push8:
{
    val8_t val = cur_bytecode_next(val8_t);
    cur_stack_push(val8_t, val);
    run_next_op;
}
do_pop1:
{
    cur_stack -= 1;
    run_next_op;
}
do_pop2:
{
    cur_stack -= 2;
    run_next_op;
}
do_pop4:
{
    cur_stack -= 8;
    run_next_op;
}
do_pop8:
{
    cur_stack -= 8;
    run_next_op;
}
do_arg1:
{
    val1_t val = *(val1_t *)&cur_argv[cur_bytecode_next(int)];
    cur_stack_push(val1_t, val);
    run_next_op;
}
do_arg2:
{
    val2_t val = *(val2_t *)&cur_argv[cur_bytecode_next(int)];
    cur_stack_push(val2_t, val);
    run_next_op;
}
do_arg4:
{
    val4_t val = *(val4_t *)&cur_argv[cur_bytecode_next(int)];
    cur_stack_push(val4_t, val);
    run_next_op;
}
do_arg8:
{
    val8_t val = *(val8_t *)&cur_argv[cur_bytecode_next(int)];
    cur_stack_push(val8_t, val);
    run_next_op;
}
do_store1:
{
    val1_t val = cur_stack_peek(val1_t);
    *(val1_t *)&cur_locals[cur_bytecode_next(int)] = val;
    run_next_op;
}
do_store2:
{
    val2_t val = cur_stack_peek(val2_t);
    *(val2_t *)&cur_locals[cur_bytecode_next(int)] = val;
    run_next_op;
}
do_store4:
{
    val4_t val = cur_stack_peek(val4_t);
    *(val4_t *)&cur_locals[cur_bytecode_next(int)] = val;
    run_next_op;
}
do_store8:
{
    val8_t val = cur_stack_peek(val8_t);
    *(val8_t *)&cur_locals[cur_bytecode_next(int)] = val;
    run_next_op;
}
do_load1:
{
    val1_t val = *(val1_t *)&cur_locals[cur_bytecode_next(int)];
    cur_stack_push(val1_t, val);
    run_next_op;
}
do_load2:
{
    val2_t val = *(val2_t *)&cur_locals[cur_bytecode_next(int)];
    cur_stack_push(val2_t, val);
    run_next_op;
}
do_load4:
{
    val4_t val = *(val4_t *)&cur_locals[cur_bytecode_next(int)];
    cur_stack_push(val4_t, val);
    run_next_op;
}
do_load8:
{
    val8_t val = *(val8_t *)&cur_locals[cur_bytecode_next(int)];
    cur_stack_push(val8_t, val);
    run_next_op;
}
do_add_float:
{
    float_t rhs = cur_stack_load_pop(float_t);
    cur_stack_peek(float_t) += rhs;
    run_next_op;
}
do_sub_float:
{
    float_t rhs = cur_stack_load_pop(float_t);
    cur_stack_peek(float_t) -= rhs;
    run_next_op;
}
do_mul_float:
{
    float_t rhs = cur_stack_load_pop(float_t);
    cur_stack_peek(float_t) *= rhs;
    run_next_op;
}
do_div_float:
{
    float_t rhs = cur_stack_load_pop(float_t);
    cur_stack_peek(float_t) /= rhs;
    run_next_op;
}
do_mod_float:
{
    float_t rhs = cur_stack_load_pop(float_t);
    cur_stack_peek(float_t) = fmod(cur_stack_peek(float_t), rhs);
    run_next_op;
}
do_add_integer:
{
    integer_t rhs = cur_stack_load_pop(integer_t);
    cur_stack_peek(integer_t) += rhs;
    run_next_op;
}
do_sub_integer:
{
    integer_t rhs = cur_stack_load_pop(integer_t);
    cur_stack_peek(integer_t) -= rhs;
    run_next_op;
}
do_mul_integer:
{
    integer_t rhs = cur_stack_load_pop(integer_t);
    cur_stack_peek(integer_t) *= rhs;
    run_next_op;
}
do_div_integer:
{
    integer_t rhs = cur_stack_load_pop(integer_t);
    cur_stack_peek(integer_t) /= rhs;
    run_next_op;
}
do_mod_integer:
{
    integer_t rhs = cur_stack_load_pop(integer_t);
    cur_stack_peek(integer_t) %= rhs;
    run_next_op;
}
do_not:
{
    cur_stack_peek(bool) = !cur_stack_peek(bool);
    run_next_op;
}
do_neg_float:
{
    cur_stack_peek(float_t) *= -1;
    run_next_op;
}
do_lt_float:
{
    float_t rhs = cur_stack_load_pop(float_t);
    float_t lhs = cur_stack_load_pop(float_t);
    cur_stack_push(bool, lhs < rhs);
    run_next_op;
}
do_gt_float:
{
    float_t rhs = cur_stack_load_pop(float_t);
    float_t lhs = cur_stack_load_pop(float_t);
    cur_stack_push(bool, lhs > rhs);
    run_next_op;
}
do_lte_float:
{
    float_t rhs = cur_stack_load_pop(float_t);
    float_t lhs = cur_stack_load_pop(float_t);
    cur_stack_push(bool, lhs <= rhs);
    run_next_op;
}
do_gte_float:
{
    float_t rhs = cur_stack_load_pop(float_t);
    float_t lhs = cur_stack_load_pop(float_t);
    cur_stack_push(bool, lhs >= rhs);
    run_next_op;
}
do_eq_float:
{
    float_t rhs = cur_stack_load_pop(float_t);
    float_t lhs = cur_stack_load_pop(float_t);
    cur_stack_push(bool, lhs == rhs);
    run_next_op;
}
do_neq_float:
{
    float_t rhs = cur_stack_load_pop(float_t);
    float_t lhs = cur_stack_load_pop(float_t);
    cur_stack_push(bool, lhs != rhs);
    run_next_op;
}
do_print_float:
{
    printf("%lf\n", cur_stack_load_pop(float_t));
    run_next_op;
}
do_neg_integer:
{
    cur_stack_peek(integer_t) *= -1;
    run_next_op;
}
do_lt_integer:
{
    integer_t rhs = cur_stack_load_pop(integer_t);
    integer_t lhs = cur_stack_load_pop(integer_t);
    cur_stack_push(bool, lhs < rhs);
    run_next_op;
}
do_gt_integer:
{
    integer_t rhs = cur_stack_load_pop(integer_t);
    integer_t lhs = cur_stack_load_pop(integer_t);
    cur_stack_push(bool, lhs > rhs);
    run_next_op;
}
do_lte_integer:
{
    integer_t rhs = cur_stack_load_pop(integer_t);
    integer_t lhs = cur_stack_load_pop(integer_t);
    cur_stack_push(bool, lhs <= rhs);
    run_next_op;
}
do_gte_integer:
{
    integer_t rhs = cur_stack_load_pop(integer_t);
    integer_t lhs = cur_stack_load_pop(integer_t);
    cur_stack_push(bool, lhs >= rhs);
    run_next_op;
}
do_eq_integer:
{
    integer_t rhs = cur_stack_load_pop(integer_t);
    integer_t lhs = cur_stack_load_pop(integer_t);
    cur_stack_push(bool, lhs == rhs);
    run_next_op;
}
do_neq_integer:
{
    integer_t rhs = cur_stack_load_pop(integer_t);
    integer_t lhs = cur_stack_load_pop(integer_t);
    cur_stack_push(bool, lhs != rhs);
    run_next_op;
}
do_print_integer:
{
    printf("%ld\n", cur_stack_load_pop(integer_t));
    run_next_op;
}
do_jump:
{
    cur_index = cur_bytecode_next(int);
    run_next_op;
}
do_iftrue:
{
    if (cur_stack_load_pop(bool))
    {
        int res = cur_bytecode_next(int);
        cur_index = res;
    }
    else
    {
        cur_bytecode_next(int);
    }
    run_next_op;
}
do_iffalse:
{
    if (!cur_stack_load_pop(bool))
    {
        int res = cur_bytecode_next(int);
        cur_index = res;
    }
    else
    {
        cur_bytecode_next(int);
    }
    run_next_op;
}
do_call:
{
    int arg_size = cur_bytecode_next(int);
    cur_stack -= arg_size;
    void *argv = cur_stack;
    func_t next_func = *cur_stack_load_pop(func_t *);
    next = (stack_frame_t){
        .func = next_func,
        .argv = argv,
        .index = 0,
    };
    goto rec_call;
}
do_rec:
{
    int arg_size = cur_bytecode_next(int);
    cur_stack -= arg_size;
    next = (stack_frame_t){
        .argv = cur_stack,
        .func = cur_func,
        .index = 0,
    };
    goto rec_call;
}
do_ec_cons:
{
    cont_t *cont = vm_alloc(sizeof(cont_t));
    cont->frame = vm_get_frame();
    cont->vm = vm;
    cont->frame_number = frame_number;
    cur_stack_push(cont_t*, cont);
    run_next_op;
}
do_ec_call:
{
    cont_t *cont = cur_stack_load_pop(cont_t*);
    vm_set_frame(cont->frame);
    vm = cont->vm;
    frame_number = cont->frame_number;
    cur_stack_push(cont_t*, cont);
    run_next_op;
}
}
