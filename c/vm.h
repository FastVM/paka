
#if !defined(true) && !defined(false)
typedef _Bool bool;
#define false ((bool)0)
#define true ((bool)1)
#endif

#ifndef NULL
#define NULL ((void *)0)
#endif

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

// #define vm_fetch (next_op_value = ptrs[cur_bytecode[cur_index++]])
#define vm_fetch ((void)0)
#define next_op (ptrs[cur_bytecode[cur_index++]])

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

typedef void vm_main_t(void *ret, void *argv);

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
  vm_main_t *native;
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
  OPCODE_NEG_INTEGER,
  OPCODE_LT_INTEGER,
  OPCODE_GT_INTEGER,
  OPCODE_LTE_INTEGER,
  OPCODE_GTE_INTEGER,
  OPCODE_EQ_INTEGER,
  OPCODE_NEQ_INTEGER,
  OPCODE_PRINT_LOGICAL,
  OPCODE_PRINT_FLOAT,
  OPCODE_PRINT_INTEGER,
  OPCODE_PRINT_TEXT,
  OPCODE_JUMP,
  OPCODE_IFTRUE,
  OPCODE_IFFALSE,
  OPCODE_CALL,
  OPCODE_CALL_STATIC,
  OPCODE_REC,
  OPCODE_MAX1,
  OPCODE_MAX2P = 128,
};

#ifdef VM_DEBUG
#define debug_op printf("%i: %i\n", cur_index, cur_bytecode[cur_index]);
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

// void vm_jit(func_t *basefunc);
