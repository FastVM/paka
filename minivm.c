
typedef _Bool bool;
#define false ((bool)0)
#define true ((bool)1)

#define NULL ((void *)0)


// #ifndef VM_UNTYPED
// #define VM_TYPED
// #endif

#ifdef __clang__
#define vm_assume(expr) (__builtin_assume(expr))
#else
#define vm_assume(expr) ((void) 0)
#endif

typedef double number_t;

struct obj_t;
struct func_t;
struct vm_t;
union value_t;
enum form_t;
enum type_t;
enum opcode_t;
enum errro_t;

typedef struct obj_t obj_t;
typedef struct array_t array_t;
typedef struct vm_t vm_t;
typedef struct func_t func_t;
typedef enum type_t type_t;
typedef enum opcode_t opcode_t;
typedef enum form_t form_t;
typedef enum error_t error_t;

obj_t vm_run(vm_t *vm, func_t basefunc, int argc, obj_t *argv);
void vm_print_int(int i);
void vm_print_ptr(void *p);
void vm_memcpy(void *dest, void *src, long len);
void *vm_alloc(long len);
void *vm_realloc(void *mem, long len);
void vm_impl_print(obj_t arg);

enum type_t
{
    TYPE_NONE,
    TYPE_BOOLEAN,
    TYPE_NUMBER,
    TYPE_STRING,
    TYPE_ARRAY,
    TYPE_FUNCTION,
    TYPE_ERROR,
    TYPE_MAX1,
    TYPE_MAX2P = 8,
};

enum error_t
{
    VM_ERROR_UNKNOWN,
    VM_ERROR_OOM,
    VM_ERROR_OPCODE,
};

struct array_t
{
    long length;
    long alloc;
    char values[0];
};

struct obj_t
{
    union
    {
        bool boolean;
        number_t number;
        array_t *arr;
        func_t *function;
        void *other;
        error_t error;
    };
    char type;
};

enum local_flags_t
{
    LOCAL_FLAGS_NONE = 0,
    LOCAL_FLAGS_ARG = 1,
};

enum capture_from_t
{
    CAPTURE_FROM_LOCAL,
    CAPTURE_FROM_ARGS,
    CAPTURE_FROM_CAPTURE,
};

struct func_t
{
    array_t *bytecode;
    func_t *parent;
    array_t *capture_from;
    array_t *capture_flags;
    int stack_used;
    int locals_used;
    array_t *captured;
};

enum opcode_t
{
    OPCODE_RETURN,
    OPCODE_EXIT,
    OPCODE_PUSH,
    OPCODE_POP,
    OPCODE_ARG,
    OPCODE_STORE,
    OPCODE_LOAD,
    OPCODE_LOADC,
    OPCODE_ADD,
    OPCODE_SUB,
    OPCODE_MUL,
    OPCODE_DIV,
    OPCODE_MOD,
    OPCODE_NEG,
    OPCODE_LT,
    OPCODE_GT,
    OPCODE_LTE,
    OPCODE_GTE,
    OPCODE_EQ,
    OPCODE_NEQ,
    OPCODE_PRINT,
    OPCODE_JUMP,
    OPCODE_IFTRUE,
    OPCODE_IFFALSE,
    OPCODE_CALL,
    OPCODE_REC,
    OPCODE_FUNC,
    OPCODE_MAX1,
    OPCODE_MAX2P = 128,
};


#include <stddef.h>

array_t *array_new(int elem_size)
{
    array_t *ret = vm_alloc(sizeof(array_t) + elem_size * 4 + 4);
    ret->length = 0;
    ret->alloc = 4;
    return ret;
}

void array_ensure(int elem_size, array_t **arr, long index)
{
    if (((*arr)->length + index) * elem_size >= (*arr)->alloc)
    {
        (*arr)->alloc *= 4;
        *arr = vm_realloc(*arr, sizeof(array_t) + elem_size * (*arr)->alloc + 4);
    }
}

#define seg (__builtin_trap())

void *array_index(int elem_size, const array_t *arr, long index)
{
    if (index < 0)
    {
        index += arr->length;
    }
    return (void *)(arr->values + elem_size * index);
}

void array_push(int elem_size, array_t **arr, void *value)
{
    array_ensure(elem_size, arr, 1);
    vm_memcpy((*arr)->values + (*arr)->length * elem_size, value, elem_size);
    (*arr)->length++;
}

void *array_pop(int elem_size, array_t **arr_ptr)
{
    array_t *arr = *arr_ptr;
    arr->length--;
    return arr->values + arr->length * elem_size;
}

#define array_new(type) array_new(sizeof(type))
#define array_ensure(type, arr, ...) \
    array_ensure(sizeof(type), &(arr), (__VA_ARGS__))
#define array_push(type, arr, ...)                        \
    (                                                     \
        {                                                 \
            type pushval = (__VA_ARGS__);                 \
            array_push(sizeof(type), &(arr), &(pushval)); \
        })
#define array_pop(type, arr) ((type *)array_pop(sizeof(type), &(arr)))
#define array_index(type, arr, index) \
    ((type *)array_index(sizeof(type), (arr), (index)))
#define array_ptr(type, arr) ((type *)(arr)->values)

#ifdef VM_DEBUG
int printf(const char *fmt, ...);
#define debug_op \
    printf("%i: %i\n", cur_index, cur_bytecode[cur_index]);
#else
#define debug_op
#endif

typedef struct
{
    int index;
    int argc;
    obj_t *argv;
    obj_t *stack;
    obj_t *locals;
    func_t func;
} stack_frame_t;

#define vm_set_frame(frame_arg) (                           \
    {                                                       \
        stack_frame_t frame = frame_arg;                    \
        cur_index = frame.index;                            \
        cur_argc = frame.argc;                              \
        cur_argv = frame.argv;                              \
        cur_stack = frame.stack;                            \
        cur_locals = frame.locals;                          \
        cur_func = frame.func;                              \
        cur_bytecode = array_ptr(char, cur_func.bytecode); \
    })

struct vm_t
{
    array_t *linear;
    stack_frame_t *frames_low;
    stack_frame_t *frames_high;
};

#ifdef VM_TYPED
#define run_next_op2(TYPE1, TYPE0)                           \
    vm_assume(cur_bytecode[cur_index] < OPCODE_MAX1); \
    vm_assume(cur_bytecode[cur_index] >= 0);          \
    run_next_op(cur_bytecode[cur_index++] + TYPE1 * OPCODE_MAX2P + TYPE0 * OPCODE_MAX2P * TYPE_MAX2P)
#define run_next_op1(TYPE0)                                  \
    vm_assume(cur_bytecode[cur_index] < OPCODE_MAX1); \
    vm_assume(cur_bytecode[cur_index] >= 0);          \
    vm_assume((*(cur_stack - 1)).type < TYPE_MAX1);   \
    vm_assume((*(cur_stack - 1)).type >= 0);          \
    run_next_op(cur_bytecode[cur_index++] + (*(cur_stack - 1)).type * OPCODE_MAX2P + TYPE0 * OPCODE_MAX2P * TYPE_MAX2P)
#define run_next_op                                              \
    vm_assume(cur_bytecode[cur_index] < OPCODE_MAX1);     \
    vm_assume(cur_bytecode[cur_index] >= 0);              \
    vm_assume((*(cur_stack - 1)).type < TYPE_MAX1);       \
    vm_assume((*(cur_stack - 1)).type >= 0);              \
    vm_assume((*cur_stack).type < TYPE_MAX1);             \
    vm_assume((*cur_stack).type >= 0);                    \
    debug_op goto *ptrs[cur_bytecode[cur_index++] +              \
                        (*(cur_stack - 1)).type * OPCODE_MAX2P + \
                        (*cur_stack).type * OPCODE_MAX2P * TYPE_MAX2P];

void opcode_on2(void **ptrs, opcode_t op, type_t top2, type_t top1,
                void *then)
{
    ptrs[op + top2 * OPCODE_MAX2P + top1 * OPCODE_MAX2P * TYPE_MAX2P] = then;
}

void opcode_on1(void **ptrs, opcode_t op, type_t top1, void *then)
{
    for (int top2 = 0; top2 < TYPE_MAX2P; top2++)
    {
        ptrs[op + top2 * OPCODE_MAX2P + top1 * OPCODE_MAX2P * TYPE_MAX2P] = then;
    }
}

void opcode_on0(void **ptrs, opcode_t op, void *then)
{
    for (int top2 = 0; top2 < TYPE_MAX2P; top2++)
    {
        for (int top1 = 0; top1 < TYPE_MAX2P; top1++)
        {
            ptrs[op + top2 * OPCODE_MAX2P + top1 * OPCODE_MAX2P * TYPE_MAX2P] = then;
        }
    }
}
#else
#define run_next_op                                          \
    vm_assume(cur_bytecode[cur_index] < OPCODE_MAX1); \
    vm_assume(cur_bytecode[cur_index] >= 0);          \
    debug_op goto *ptrs[cur_bytecode[cur_index++]];

#define run_next_op2(_1, _0) run_next_op
#define run_next_op1(_0) run_next_op

#endif

#define cur_bytecode_next(Type) ({Type ret = *(Type*)&cur_bytecode[cur_index]; cur_index += sizeof(Type); ret;})

obj_t vm_run(vm_t *pvm, func_t basefunc, int argc, obj_t *argv)
{
    vm_t vm = *pvm;
    int frames_max = vm.frames_high - vm.frames_low;
    int frame_number = 0;
    stack_frame_t next = (stack_frame_t){
        .func = basefunc,
        .argc = argc,
        .argv = argv,
        .index = 0,
    };
    int cur_index;
    int cur_argc;
    obj_t *cur_argv;
    func_t cur_func;
    obj_t *cur_stack;
    obj_t *cur_locals;
    char *cur_bytecode;
#ifdef VM_TYPED
    void *ptrs[OPCODE_MAX2P * TYPE_MAX2P * TYPE_MAX2P + 1] = {};
    for (int top2 = 0; top2 < TYPE_MAX2P; top2++)
    {
        for (int top1 = 0; top1 < TYPE_MAX2P; top1++)
        {
            for (int op = 0; op < OPCODE_MAX2P; op++)
            {
                ptrs[op + top2 * OPCODE_MAX2P + top1 * OPCODE_MAX2P * TYPE_MAX2P] =
                    &&do_err;
            }
        }
    }
    opcode_on0(ptrs, OPCODE_RETURN, &&do_return);
    opcode_on0(ptrs, OPCODE_EXIT, &&do_exit);
    opcode_on0(ptrs, OPCODE_PUSH, &&do_push);
    opcode_on0(ptrs, OPCODE_POP, &&do_pop);
    opcode_on0(ptrs, OPCODE_ARG, &&do_arg);
    opcode_on0(ptrs, OPCODE_STORE, &&do_store);
    opcode_on0(ptrs, OPCODE_LOAD, &&do_load);
    opcode_on0(ptrs, OPCODE_LOADC, &&do_loadc);
    opcode_on0(ptrs, OPCODE_PRINT, &&do_print);
    opcode_on0(ptrs, OPCODE_JUMP, &&do_jump);
    opcode_on0(ptrs, OPCODE_CALL, &&do_call);
    opcode_on0(ptrs, OPCODE_REC, &&do_rec);
    opcode_on1(ptrs, OPCODE_NEG, TYPE_NUMBER, &&do_neg);
    opcode_on1(ptrs, OPCODE_IFTRUE, TYPE_BOOLEAN, &&do_iftrue);
    opcode_on1(ptrs, OPCODE_IFFALSE, TYPE_BOOLEAN, &&do_iffalse);
    opcode_on1(ptrs, OPCODE_FUNC, TYPE_FUNCTION, &&do_func);
    opcode_on2(ptrs, OPCODE_ADD, TYPE_NUMBER, TYPE_NUMBER, &&do_add);
    opcode_on2(ptrs, OPCODE_SUB, TYPE_NUMBER, TYPE_NUMBER, &&do_sub);
    opcode_on2(ptrs, OPCODE_MUL, TYPE_NUMBER, TYPE_NUMBER, &&do_mul);
    opcode_on2(ptrs, OPCODE_DIV, TYPE_NUMBER, TYPE_NUMBER, &&do_div);
    opcode_on2(ptrs, OPCODE_MOD, TYPE_NUMBER, TYPE_NUMBER, &&do_mod);
    opcode_on2(ptrs, OPCODE_LT, TYPE_NUMBER, TYPE_NUMBER, &&do_lt);
    opcode_on2(ptrs, OPCODE_GT, TYPE_NUMBER, TYPE_NUMBER, &&do_gt);
    opcode_on2(ptrs, OPCODE_LTE, TYPE_NUMBER, TYPE_NUMBER, &&do_lte);
    opcode_on2(ptrs, OPCODE_GTE, TYPE_NUMBER, TYPE_NUMBER, &&do_gte);
    opcode_on2(ptrs, OPCODE_EQ, TYPE_NUMBER, TYPE_NUMBER, &&do_eq);
    opcode_on2(ptrs, OPCODE_NEQ, TYPE_NUMBER, TYPE_NUMBER, &&do_neq);
#else
    void *ptrs[OPCODE_MAX2P] = {NULL};
    ptrs[OPCODE_RETURN] = &&do_return;
    ptrs[OPCODE_EXIT] = &&do_exit;
    ptrs[OPCODE_PUSH] = &&do_push;
    ptrs[OPCODE_POP] = &&do_pop;
    ptrs[OPCODE_ARG] = &&do_arg;
    ptrs[OPCODE_STORE] = &&do_store;
    ptrs[OPCODE_LOAD] = &&do_load;
    ptrs[OPCODE_LOADC] = &&do_loadc;
    ptrs[OPCODE_ADD] = &&do_add;
    ptrs[OPCODE_SUB] = &&do_sub;
    ptrs[OPCODE_MUL] = &&do_mul;
    ptrs[OPCODE_DIV] = &&do_div;
    ptrs[OPCODE_MOD] = &&do_mod;
    ptrs[OPCODE_NEG] = &&do_neg;
    ptrs[OPCODE_LT] = &&do_lt;
    ptrs[OPCODE_GT] = &&do_gt;
    ptrs[OPCODE_LTE] = &&do_lte;
    ptrs[OPCODE_GTE] = &&do_gte;
    ptrs[OPCODE_EQ] = &&do_eq;
    ptrs[OPCODE_NEQ] = &&do_neq;
    ptrs[OPCODE_PRINT] = &&do_print;
    ptrs[OPCODE_JUMP] = &&do_jump;
    ptrs[OPCODE_IFTRUE] = &&do_iftrue;
    ptrs[OPCODE_IFFALSE] = &&do_iffalse;
    ptrs[OPCODE_CALL] = &&do_call;
    ptrs[OPCODE_REC] = &&do_rec;
    ptrs[OPCODE_FUNC] = &&do_func;
#endif
rec_call:
    if (frames_max <= frame_number + 2)
    {
        int mlen = frame_number * 2 + 2;
        long nalloc = mlen * sizeof(stack_frame_t);
        if (nalloc > (3L << 29))
        {
            return (obj_t){
                .type = TYPE_ERROR,
                .error = VM_ERROR_OOM,
            };
        }
        vm.frames_low = vm_realloc(vm.frames_low, mlen * nalloc);
        frames_max = mlen;
    }
    if (vm.linear->length * 2 > vm.linear->alloc)
    {
        long mlen = (long)vm.linear->alloc * 2 + 2;
        if (mlen > (3L << 29))
        {
            return (obj_t){
                .type = TYPE_ERROR,
                .error = VM_ERROR_OOM,
            };
        }
        vm.linear = vm_realloc(vm.linear, sizeof(array_t) + mlen);
        vm.linear->alloc = mlen;
    }
    vm.frames_low[frame_number++] = (stack_frame_t){
        .index = cur_index,
        .argc = cur_argc,
        .argv = cur_argv,
        .func = cur_func,
        .stack = cur_stack,
        .locals = cur_locals,
    };
    vm_set_frame(next);
    cur_stack = (obj_t *)(vm.linear->values + vm.linear->length);
    cur_locals = cur_stack + cur_func.stack_used;
    vm.linear->length += (cur_func.locals_used + cur_func.stack_used) * sizeof(obj_t);
    run_next_op2(TYPE_NONE, TYPE_NONE);
do_err:
{
    return (obj_t){
        .type = TYPE_ERROR,
        .error = VM_ERROR_OPCODE,
    };
};
do_return:
{
    obj_t retval = *cur_stack;
    vm.linear->length -= (cur_func.stack_used + cur_func.locals_used) * sizeof(obj_t);
    vm_set_frame(vm.frames_low[--frame_number]);
    *cur_stack = retval;
    run_next_op1(retval.type);
}
do_exit:
{
    obj_t retval = *cur_stack;
    vm.linear->length -= (cur_func.stack_used + cur_func.locals_used) * sizeof(obj_t);
    vm.frames_high = vm.frames_low + frames_max;
    *pvm = vm;
    return retval;
}
do_push:
{
    obj_t val = cur_bytecode_next(obj_t);
    *(++cur_stack) = val;
    run_next_op1(val.type);
}
do_pop:
{
    cur_stack--;
    run_next_op;
}
do_arg:
{
    obj_t val = cur_argv[cur_bytecode_next(int)];
    *(++cur_stack) = val;
    run_next_op1(val.type);
}
do_store:
{
    obj_t val = *cur_stack;
    cur_locals[cur_bytecode_next(int)] = val;
    run_next_op1(val.type);
}
do_load:
{
    obj_t val = cur_locals[cur_bytecode_next(int)];
    *(++cur_stack) = val;
    run_next_op1(val.type);
}
do_loadc:
{
    obj_t val = array_ptr(obj_t, cur_func.captured)[cur_bytecode_next(int)];
    *(++cur_stack) = val;
    run_next_op1(val.type);
}
do_add:
{
    number_t rhs = (cur_stack--)->number;
    cur_stack->number += rhs;
    run_next_op1(TYPE_NUMBER);
}
do_sub:
{
    number_t rhs = (cur_stack--)->number;
    cur_stack->number -= rhs;
    run_next_op1(TYPE_NUMBER);
}
do_mul:
{
    number_t rhs = (cur_stack--)->number;
    cur_stack->number *= rhs;
    run_next_op1(TYPE_NUMBER);
}
do_div:
{
    number_t rhs = (cur_stack--)->number;
    cur_stack->number /= rhs;
    run_next_op1(TYPE_NUMBER);
}
do_mod:
{
    number_t rhs = (cur_stack--)->number;
    cur_stack->number *= rhs;
    run_next_op1(TYPE_NUMBER);
}
do_neg:
{
    cur_stack->number *= -1;
    run_next_op1(TYPE_NUMBER);
}
do_lt:
{
    number_t rhs = (cur_stack--)->number;
    *cur_stack = (obj_t){
        .type = TYPE_BOOLEAN,
        .boolean = cur_stack->number < rhs,
    };
    run_next_op1(TYPE_BOOLEAN);
}
do_gt:
{
    number_t rhs = (cur_stack--)->number;
    *cur_stack = (obj_t){
        .type = TYPE_BOOLEAN,
        .boolean = cur_stack->number > rhs,
    };
    run_next_op1(TYPE_BOOLEAN);
}
do_lte:
{
    number_t rhs = (cur_stack--)->number;
    *cur_stack = (obj_t){
        .type = TYPE_BOOLEAN,
        .boolean = cur_stack->number <= rhs,
    };
    run_next_op1(TYPE_BOOLEAN);
}
do_gte:
{
    number_t rhs = (cur_stack--)->number;
    *cur_stack = (obj_t){
        .type = TYPE_BOOLEAN,
        .boolean = cur_stack->number >= rhs,
    };
    run_next_op1(TYPE_BOOLEAN);
}
do_eq:
{
    number_t rhs = (cur_stack--)->number;
    *cur_stack = (obj_t){
        .type = TYPE_BOOLEAN,
        .boolean = cur_stack->number == rhs,
    };
    run_next_op1(TYPE_BOOLEAN);
}
do_neq:
{
    number_t rhs = (cur_stack--)->number;
    *cur_stack = (obj_t){
        .type = TYPE_BOOLEAN,
        .boolean = cur_stack->number != rhs,
    };
    run_next_op1(TYPE_BOOLEAN);
}
do_print:
{
    vm_impl_print(*cur_stack);
    cur_stack->type = TYPE_NONE;
    run_next_op1(TYPE_NONE);
}
do_jump:
{
    cur_index = cur_bytecode_next(int);
    run_next_op;
}
do_iftrue:
{
    if ((cur_stack--)->boolean)
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
    if (!(cur_stack--)->boolean)
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
    int nargs = cur_bytecode_next(int);
    cur_stack -= nargs;
    next = (stack_frame_t){
        .func = *cur_stack->function,
        .argc = nargs,
        .argv = cur_stack + 1,
        .index = 0,
    };
    goto rec_call;
}
do_rec:
{
    int nargs = cur_bytecode_next(int);
    cur_stack -= nargs - 1;
    next = (stack_frame_t){
        .argc = nargs,
        .argv = cur_stack,
        .func = cur_func,
        .index = 0,
    };
    goto rec_call;
}
do_func:
{
    func_t *old_func = cur_stack->function;
    func_t *new_func = vm_alloc(sizeof(func_t));
    *new_func = *old_func;
    new_func->captured = array_new(obj_t);
    for (int index = 0; index < new_func->capture_from->length; index++)
    {
        int flags = array_ptr(int, new_func->capture_flags)[index];
        int from = array_ptr(int, new_func->capture_from)[index];
        switch (flags)
        {
        case CAPTURE_FROM_LOCAL:
            array_push(obj_t, new_func->captured, cur_locals[from]);
            break;
        case CAPTURE_FROM_ARGS:
            array_push(obj_t, new_func->captured, cur_argv[from]);
            break;
        case CAPTURE_FROM_CAPTURE:
            array_push(obj_t, new_func->captured,
                       array_ptr(obj_t, cur_func.captured)[from]);
            break;
        }
    }
    cur_stack->function = new_func;
    run_next_op1(TYPE_FUNCTION);
}
}
