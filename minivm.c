
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <math.h>

#define VM_REG_NUM ((256))
#define VM_FRAME_NUM ((16))

#ifdef __clang__
#define vm_assume(expr) (__builtin_assume(expr))
#else
#define vm_assume(expr) (__builtin_expect(expr, true))
#endif

#define vm_fetch (next_op_value = ptrs[basefunc[cur_index]])
#define next_op (cur_index++, next_op_value)

typedef int number_t;
typedef char opcode_t;

struct value_t;
enum errro_t;

typedef struct value_t value_t;
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

struct value_t
{
  union
  {
    bool logical;
    number_t number;
    int bytecode;
  };
};

enum opcode_t
{
  OPCODE_EXIT,
  OPCODE_STORE_REG,
  OPCODE_STORE_LOG,
  OPCODE_STORE_NUM,
  OPCODE_STORE_FUN,
  OPCODE_EQUAL,
  OPCODE_EQUAL_NUM,
  OPCODE_NOT_EQUAL,
  OPCODE_NOT_EQUAL_NUM,
  OPCODE_LESS,
  OPCODE_LESS_NUM,
  OPCODE_GREATER,
  OPCODE_GREATER_NUM,
  OPCODE_LESS_THAN_EQUAL,
  OPCODE_LESS_THAN_EQUAL_NUM,
  OPCODE_GREATER_THAN_EQUAL,
  OPCODE_GREATER_THAN_EQUAL_NUM,
  OPCODE_JUMP_ALWAYS,
  OPCODE_JUMP_IF_FALSE,
  OPCODE_JUMP_IF_TRUE,
  OPCODE_JUMP_IF_EQUAL,
  OPCODE_JUMP_IF_EQUAL_NUM,
  OPCODE_JUMP_IF_NOT_EQUAL,
  OPCODE_JUMP_IF_NOT_EQUAL_NUM,
  OPCODE_JUMP_IF_LESS,
  OPCODE_JUMP_IF_LESS_NUM,
  OPCODE_JUMP_IF_GREATER,
  OPCODE_JUMP_IF_GREATER_NUM,
  OPCODE_JUMP_IF_LESS_THAN_EQUAL,
  OPCODE_JUMP_IF_LESS_THAN_EQUAL_NUM,
  OPCODE_JUMP_IF_GREATER_THAN_EQUAL,
  OPCODE_JUMP_IF_GREATER_THAN_EQUAL_NUM,
  OPCODE_INC,
  OPCODE_INC_NUM,
  OPCODE_DEC,
  OPCODE_DEC_NUM,
  OPCODE_ADD,
  OPCODE_ADD_NUM,
  OPCODE_SUB,
  OPCODE_SUB_NUM,
  OPCODE_MUL,
  OPCODE_MUL_NUM,
  OPCODE_DIV,
  OPCODE_DIV_NUM,
  OPCODE_MOD,
  OPCODE_MOD_NUM,
  OPCODE_CALL,
  OPCODE_REC,
  OPCODE_TAIL_CALL,
  OPCODE_TAIL_REC,
  OPCODE_RETURN,
  OPCODE_PRINTLN,
  OPCODE_MAX1,
  OPCODE_MAX2P = 128,
};

#ifdef VM_DEBUG
#define debug_op vm_print_opcode(cur_index, basefunc);
#else
#define debug_op
#endif

typedef struct
{
  int index;
  int func;
  int bytecode;
  int outreg;
} stack_frame_t;

#define vm_set_frame(frame_arg)          \
  (                                      \
      {                                  \
        stack_frame_t frame = frame_arg; \
        cur_index = frame.index;         \
        cur_func = frame.func;           \
      })

#define run_next_op                             \
  vm_assume(basefunc[cur_index] < OPCODE_MAX1); \
  vm_assume(basefunc[cur_index] >= 0);          \
  debug_op goto *next_op;

#define cur_bytecode_next(Type)                   \
  (                                               \
      {                                           \
        Type ret = *(Type *)&basefunc[cur_index]; \
        cur_index += sizeof(Type);                \
        ret;                                      \
      })

#define read_reg (cur_bytecode_next(unsigned char))
#define read_bool (cur_bytecode_next(bool))
#define read_int (cur_bytecode_next(int))
#define read_num (cur_bytecode_next(number_t))
#define read_loc (cur_bytecode_next(int))

void vm_error(error_t err)
{
  printf("error: (todo)");
}

const char *vm_opcode_internal_name(opcode_t op)
{
  switch (op)
  {
  default:
    return "error";
  case OPCODE_EXIT:
    return "exit";
  case OPCODE_STORE_REG:
    return "store_reg";
  case OPCODE_STORE_LOG:
    return "store_log";
  case OPCODE_STORE_NUM:
    return "store_num";
  case OPCODE_STORE_FUN:
    return "store_fun";
  case OPCODE_EQUAL:
    return "equal";
  case OPCODE_EQUAL_NUM:
    return "equal_num";
  case OPCODE_NOT_EQUAL:
    return "not_equal";
  case OPCODE_NOT_EQUAL_NUM:
    return "not_equal_num";
  case OPCODE_LESS:
    return "less";
  case OPCODE_LESS_NUM:
    return "less_num";
  case OPCODE_GREATER:
    return "greater";
  case OPCODE_GREATER_NUM:
    return "greater_num";
  case OPCODE_LESS_THAN_EQUAL:
    return "less_than_equal";
  case OPCODE_LESS_THAN_EQUAL_NUM:
    return "less_than_equal_num";
  case OPCODE_GREATER_THAN_EQUAL:
    return "greater_than_equal";
  case OPCODE_GREATER_THAN_EQUAL_NUM:
    return "greater_than_equal_num";
  case OPCODE_JUMP_ALWAYS:
    return "jump_always";
  case OPCODE_JUMP_IF_FALSE:
    return "jump_if_false";
  case OPCODE_JUMP_IF_TRUE:
    return "jump_if_true";
  case OPCODE_JUMP_IF_EQUAL:
    return "jump_if_equal";
  case OPCODE_JUMP_IF_EQUAL_NUM:
    return "jump_if_equal_num";
  case OPCODE_JUMP_IF_NOT_EQUAL:
    return "jump_if_not_equal";
  case OPCODE_JUMP_IF_NOT_EQUAL_NUM:
    return "jump_if_not_equal_num";
  case OPCODE_JUMP_IF_LESS:
    return "jump_if_less";
  case OPCODE_JUMP_IF_LESS_NUM:
    return "jump_if_less_num";
  case OPCODE_JUMP_IF_GREATER:
    return "jump_if_greater";
  case OPCODE_JUMP_IF_GREATER_NUM:
    return "jump_if_greater_num";
  case OPCODE_JUMP_IF_LESS_THAN_EQUAL:
    return "jump_if_less_than_equal";
  case OPCODE_JUMP_IF_LESS_THAN_EQUAL_NUM:
    return "jump_if_less_than_equal_num";
  case OPCODE_JUMP_IF_GREATER_THAN_EQUAL:
    return "jump_if_greater_than_equal";
  case OPCODE_JUMP_IF_GREATER_THAN_EQUAL_NUM:
    return "jump_if_greater_than_equal_num";
  case OPCODE_INC:
    return "inc";
  case OPCODE_INC_NUM:
    return "inc_num";
  case OPCODE_DEC:
    return "dec";
  case OPCODE_DEC_NUM:
    return "dec_num";
  case OPCODE_ADD:
    return "add";
  case OPCODE_ADD_NUM:
    return "add_num";
  case OPCODE_SUB:
    return "sub";
  case OPCODE_SUB_NUM:
    return "sub_num";
  case OPCODE_MUL:
    return "mul";
  case OPCODE_MUL_NUM:
    return "mul_num";
  case OPCODE_DIV:
    return "div";
  case OPCODE_DIV_NUM:
    return "div_num";
  case OPCODE_MOD:
    return "mod";
  case OPCODE_MOD_NUM:
    return "mod_num";
  case OPCODE_CALL:
    return "call";
  case OPCODE_REC:
    return "rec";
  case OPCODE_TAIL_CALL:
    return "tail_call";
  case OPCODE_TAIL_REC:
    return "tail_rec";
  case OPCODE_RETURN:
    return "return";
  case OPCODE_PRINTLN:
    return "println";
  }
}

const char *vm_opcode_name(opcode_t op)
{
  switch (op)
  {
  default:
    return "error";
  case OPCODE_EXIT:
    return "halt";
  case OPCODE_STORE_REG:
    return "mov";
  case OPCODE_STORE_LOG:
    return "mov";
  case OPCODE_STORE_NUM:
    return "mov";
  case OPCODE_STORE_FUN:
    return "mov";
  case OPCODE_EQUAL:
    return "eq";
  case OPCODE_EQUAL_NUM:
    return "eq";
  case OPCODE_NOT_EQUAL:
    return "neq";
  case OPCODE_NOT_EQUAL_NUM:
    return "neq";
  case OPCODE_LESS:
    return "lt";
  case OPCODE_LESS_NUM:
    return "lt";
  case OPCODE_GREATER:
    return "gt";
  case OPCODE_GREATER_NUM:
    return "gt";
  case OPCODE_LESS_THAN_EQUAL:
    return "lte";
  case OPCODE_LESS_THAN_EQUAL_NUM:
    return "lte";
  case OPCODE_GREATER_THAN_EQUAL:
    return "gte";
  case OPCODE_GREATER_THAN_EQUAL_NUM:
    return "gte";
  case OPCODE_JUMP_ALWAYS:
    return "jmp";
  case OPCODE_JUMP_IF_FALSE:
    return "jmpf";
  case OPCODE_JUMP_IF_TRUE:
    return "jmpt";
  case OPCODE_JUMP_IF_EQUAL:
    return "jmpeq";
  case OPCODE_JUMP_IF_EQUAL_NUM:
    return "jmpeq";
  case OPCODE_JUMP_IF_NOT_EQUAL:
    return "jmpneq";
  case OPCODE_JUMP_IF_NOT_EQUAL_NUM:
    return "jmpneq";
  case OPCODE_JUMP_IF_LESS:
    return "jmplt";
  case OPCODE_JUMP_IF_LESS_NUM:
    return "jmplt";
  case OPCODE_JUMP_IF_GREATER:
    return "jmpgt";
  case OPCODE_JUMP_IF_GREATER_NUM:
    return "jmpgt";
  case OPCODE_JUMP_IF_LESS_THAN_EQUAL:
    return "jmplte";
  case OPCODE_JUMP_IF_LESS_THAN_EQUAL_NUM:
    return "jmplte";
  case OPCODE_JUMP_IF_GREATER_THAN_EQUAL:
    return "jmpgte";
  case OPCODE_JUMP_IF_GREATER_THAN_EQUAL_NUM:
    return "jmpgte";
  case OPCODE_INC:
    return "add";
  case OPCODE_INC_NUM:
    return "add";
  case OPCODE_DEC:
    return "sub";
  case OPCODE_DEC_NUM:
    return "sub";
  case OPCODE_ADD:
    return "add";
  case OPCODE_ADD_NUM:
    return "add";
  case OPCODE_SUB:
    return "sub";
  case OPCODE_SUB_NUM:
    return "sub";
  case OPCODE_MUL:
    return "mul";
  case OPCODE_MUL_NUM:
    return "mul";
  case OPCODE_DIV:
    return "div";
  case OPCODE_DIV_NUM:
    return "div";
  case OPCODE_MOD:
    return "mod";
  case OPCODE_MOD_NUM:
    return "mod";
  case OPCODE_CALL:
    return "call";
  case OPCODE_REC:
    return "rec";
  case OPCODE_TAIL_CALL:
    return "tcall";
  case OPCODE_TAIL_REC:
    return "trec";
  case OPCODE_RETURN:
    return "ret";
  case OPCODE_PRINTLN:
    return "println";
  }
}

const char *vm_opcode_format(opcode_t op)
{
  switch (op)
  {
  default:
    return "e";
  case OPCODE_EXIT:
    return "";
  case OPCODE_STORE_REG:
    return "rr";
  case OPCODE_STORE_LOG:
    return "rl";
  case OPCODE_STORE_NUM:
    return "rn";
  case OPCODE_STORE_FUN:
    return "ra";
  case OPCODE_EQUAL:
    return "rrr";
  case OPCODE_EQUAL_NUM:
    return "rrn";
  case OPCODE_NOT_EQUAL:
    return "rrr";
  case OPCODE_NOT_EQUAL_NUM:
    return "rrn";
  case OPCODE_LESS:
    return "rrr";
  case OPCODE_LESS_NUM:
    return "rrn";
  case OPCODE_GREATER:
    return "rrr";
  case OPCODE_GREATER_NUM:
    return "rrn";
  case OPCODE_LESS_THAN_EQUAL:
    return "rrr";
  case OPCODE_LESS_THAN_EQUAL_NUM:
    return "rrn";
  case OPCODE_GREATER_THAN_EQUAL:
    return "rrr";
  case OPCODE_GREATER_THAN_EQUAL_NUM:
    return "rrn";
  case OPCODE_JUMP_ALWAYS:
    return "j";
  case OPCODE_JUMP_IF_FALSE:
    return "jr";
  case OPCODE_JUMP_IF_TRUE:
    return "jr";
  case OPCODE_JUMP_IF_EQUAL:
    return "jrr";
  case OPCODE_JUMP_IF_EQUAL_NUM:
    return "jrn";
  case OPCODE_JUMP_IF_NOT_EQUAL:
    return "jrr";
  case OPCODE_JUMP_IF_NOT_EQUAL_NUM:
    return "jrn";
  case OPCODE_JUMP_IF_LESS:
    return "jrr";
  case OPCODE_JUMP_IF_LESS_NUM:
    return "jrn";
  case OPCODE_JUMP_IF_GREATER:
    return "jrr";
  case OPCODE_JUMP_IF_GREATER_NUM:
    return "jrn";
  case OPCODE_JUMP_IF_LESS_THAN_EQUAL:
    return "jrr";
  case OPCODE_JUMP_IF_LESS_THAN_EQUAL_NUM:
    return "jrn";
  case OPCODE_JUMP_IF_GREATER_THAN_EQUAL:
    return "jrr";
  case OPCODE_JUMP_IF_GREATER_THAN_EQUAL_NUM:
    return "jrn";
  case OPCODE_INC:
    return "rr";
  case OPCODE_INC_NUM:
    return "rn";
  case OPCODE_DEC:
    return "rr";
  case OPCODE_DEC_NUM:
    return "rn";
  case OPCODE_ADD:
    return "rrr";
  case OPCODE_ADD_NUM:
    return "rrn";
  case OPCODE_SUB:
    return "rrr";
  case OPCODE_SUB_NUM:
    return "rrn";
  case OPCODE_MUL:
    return "rrr";
  case OPCODE_MUL_NUM:
    return "rrn";
  case OPCODE_DIV:
    return "rrr";
  case OPCODE_DIV_NUM:
    return "rrn";
  case OPCODE_MOD:
    return "rrr";
  case OPCODE_MOD_NUM:
    return "rrn";
  case OPCODE_CALL:
    return "rrc";
  case OPCODE_REC:
    return "rc";
  case OPCODE_TAIL_CALL:
    return "rc";
  case OPCODE_TAIL_REC:
    return "c";
  case OPCODE_RETURN:
    return "r";
  case OPCODE_PRINTLN:
    return "r";
  }
}

void vm_print_opcode(int index, opcode_t *bytecode)
{
  opcode_t *head = &bytecode[index];
  opcode_t opcode = *head;
  head++;
  printf("[%i]: ", index);
  printf("%s", vm_opcode_name(opcode));
  const char *fmt = vm_opcode_format(opcode);
  for (int index = 0; fmt[index] != '\0'; index++)
  {
    if (index == 0)
    {
      printf(" ");
    }
    else
    {
      printf(", ");
    }
    switch (fmt[index])
    {
    case 'r':
    {
      printf("r%i", *(unsigned char *)head);
      head += 1;
      break;
    }
    case 'j':
    {
      printf("[%i]", *(int *)head);
      head += 4;
      break;
    }
    case 'l':
    {
      printf("%s", *(bool *)head ? "1" : "0");
      head += 1;
      break;
    }
    case 'c':
    {
      int nargs = *(unsigned char *)head;
      head += 1;
      printf("(");
      for (int argno = 0; argno < nargs; argno++)
      {
        if (argno != 0)
        {
          printf(", ");
        }
        printf("r%i", *(unsigned char *)head);
        head += 1;
      }
      printf(")");
      break;
    }
    case 'n':
    {
      if (fmod(*(number_t *)head, 1) == 0)
      {
        printf("%i", *(number_t *)head);
      }
      else
      {
        printf("%i", *(number_t *)head);
      }
      head += 8;
      break;
    }
    case 'a':
    {
      printf("{%i}", *(int *)head);
      head += *(int *)head + 4;
      break;
    }
    default:
    {
      printf("error");
    }
    }
  }
  printf("\n");
}

void vm_run(opcode_t *basefunc)
{
  stack_frame_t *frames_base = calloc(1, sizeof(stack_frame_t) * VM_FRAME_NUM);
  int allocn = VM_FRAME_NUM - 4;
  value_t *locals_base = calloc(1, sizeof(value_t) * VM_REG_NUM * VM_FRAME_NUM);

  stack_frame_t *cur_frame = frames_base;
  value_t *cur_locals = locals_base;
  int cur_index = 0;
  int cur_func = 0;

  void *next_op_value;
  void *ptrs[OPCODE_MAX2P] = {NULL};
  ptrs[OPCODE_EXIT] = &&do_exit;
  ptrs[OPCODE_STORE_REG] = &&do_store_reg;
  ptrs[OPCODE_STORE_LOG] = &&do_store_log;
  ptrs[OPCODE_STORE_NUM] = &&do_store_num;
  ptrs[OPCODE_STORE_FUN] = &&do_store_fun;
  ptrs[OPCODE_EQUAL] = &&do_equal;
  ptrs[OPCODE_EQUAL_NUM] = &&do_equal_num;
  ptrs[OPCODE_NOT_EQUAL] = &&do_not_equal;
  ptrs[OPCODE_NOT_EQUAL_NUM] = &&do_not_equal_num;
  ptrs[OPCODE_LESS] = &&do_less;
  ptrs[OPCODE_LESS_NUM] = &&do_less_num;
  ptrs[OPCODE_GREATER] = &&do_greater;
  ptrs[OPCODE_GREATER_NUM] = &&do_greater_num;
  ptrs[OPCODE_LESS_THAN_EQUAL] = &&do_less_than_equal;
  ptrs[OPCODE_LESS_THAN_EQUAL_NUM] = &&do_less_than_equal_num;
  ptrs[OPCODE_GREATER_THAN_EQUAL] = &&do_greater_than_equal;
  ptrs[OPCODE_GREATER_THAN_EQUAL_NUM] = &&do_greater_than_equal_num;
  ptrs[OPCODE_JUMP_ALWAYS] = &&do_jump_always;
  ptrs[OPCODE_JUMP_IF_FALSE] = &&do_jump_if_false;
  ptrs[OPCODE_JUMP_IF_TRUE] = &&do_jump_if_true;
  ptrs[OPCODE_JUMP_IF_EQUAL] = &&do_jump_if_equal;
  ptrs[OPCODE_JUMP_IF_EQUAL_NUM] = &&do_jump_if_equal_num;
  ptrs[OPCODE_JUMP_IF_NOT_EQUAL] = &&do_jump_if_not_equal;
  ptrs[OPCODE_JUMP_IF_NOT_EQUAL_NUM] = &&do_jump_if_not_equal_num;
  ptrs[OPCODE_JUMP_IF_LESS] = &&do_jump_if_less;
  ptrs[OPCODE_JUMP_IF_LESS_NUM] = &&do_jump_if_less_num;
  ptrs[OPCODE_JUMP_IF_GREATER] = &&do_jump_if_greater;
  ptrs[OPCODE_JUMP_IF_GREATER_NUM] = &&do_jump_if_greater_num;
  ptrs[OPCODE_JUMP_IF_LESS_THAN_EQUAL] = &&do_jump_if_less_than_equal;
  ptrs[OPCODE_JUMP_IF_LESS_THAN_EQUAL_NUM] = &&do_jump_if_less_than_equal_num;
  ptrs[OPCODE_JUMP_IF_GREATER_THAN_EQUAL] = &&do_jump_if_greater_than_equal;
  ptrs[OPCODE_JUMP_IF_GREATER_THAN_EQUAL_NUM] = &&do_jump_if_greater_than_equal_num;
  ptrs[OPCODE_INC] = &&do_inc;
  ptrs[OPCODE_INC_NUM] = &&do_inc_num;
  ptrs[OPCODE_DEC] = &&do_dec;
  ptrs[OPCODE_DEC_NUM] = &&do_dec_num;
  ptrs[OPCODE_ADD] = &&do_add;
  ptrs[OPCODE_ADD_NUM] = &&do_add_num;
  ptrs[OPCODE_SUB] = &&do_sub;
  ptrs[OPCODE_SUB_NUM] = &&do_sub_num;
  ptrs[OPCODE_MUL] = &&do_mul;
  ptrs[OPCODE_MUL_NUM] = &&do_mul_num;
  ptrs[OPCODE_DIV] = &&do_div;
  ptrs[OPCODE_DIV_NUM] = &&do_div_num;
  ptrs[OPCODE_MOD] = &&do_mod;
  ptrs[OPCODE_MOD_NUM] = &&do_mod_num;
  ptrs[OPCODE_CALL] = &&do_call;
  ptrs[OPCODE_REC] = &&do_rec;
  ptrs[OPCODE_TAIL_CALL] = &&do_tail_call;
  ptrs[OPCODE_TAIL_REC] = &&do_tail_rec;
  ptrs[OPCODE_RETURN] = &&do_return;
  ptrs[OPCODE_PRINTLN] = &&do_println;
  vm_fetch;
  run_next_op;
do_exit:
{
  free(locals_base);
  free(frames_base);
  return;
}
do_return:
{
  unsigned char from = read_reg;
  value_t val = cur_locals[from];
  cur_frame--;
  int outreg = cur_frame->outreg;
  cur_func = cur_frame->func;
  cur_index = cur_frame->index;
  cur_locals -= VM_REG_NUM;
  cur_locals[outreg] = val;
  vm_fetch;
  run_next_op;
}
do_call:
{
  if (cur_frame - frames_base >= allocn)
  {
    int len = cur_frame - frames_base;
    int alloc = allocn * 2 + 8;
    frames_base = realloc(frames_base, sizeof(stack_frame_t) * alloc);
    cur_frame = frames_base + len;
    allocn = alloc - 4;
    int nlocals = cur_locals - locals_base;
    locals_base = realloc(locals_base, sizeof(value_t) * VM_REG_NUM * alloc);
    cur_locals = locals_base + nlocals;
  }
  unsigned char func = read_reg;
  unsigned char outreg = read_reg;
  unsigned char nargs = read_reg;
  value_t *next_locals = cur_locals + VM_REG_NUM;
  for (int argno = 0; argno < nargs; argno++)
  {
    unsigned char regno = read_reg;
    next_locals[argno] = cur_locals[regno];
  }
  int next_func = cur_locals[func].bytecode;
  cur_locals = next_locals;
  cur_frame->index = cur_index;
  cur_frame->func = cur_func;
  cur_frame->outreg = outreg;
  cur_frame++;
  cur_index = next_func;
  cur_func = next_func;
  vm_fetch;
  run_next_op;
}
do_rec:
{
  if (cur_frame - frames_base >= allocn)
  {
    int len = cur_frame - frames_base;
    int alloc = allocn * 2 + 8;
    frames_base = realloc(frames_base, sizeof(stack_frame_t) * alloc);
    cur_frame = frames_base + len;
    allocn = alloc - 4;
    int nlocals = cur_locals - locals_base;
    locals_base = realloc(locals_base, sizeof(value_t) * VM_REG_NUM * alloc);
    cur_locals = locals_base + nlocals;
  }
  unsigned char outreg = read_reg;
  unsigned char nargs = read_reg;
  value_t *next_locals = cur_locals + VM_REG_NUM;
  for (int argno = 0; argno < nargs; argno++)
  {
    unsigned char regno = read_reg;
    next_locals[argno] = cur_locals[regno];
  }
  cur_locals = next_locals;
  cur_frame->index = cur_index;
  cur_frame->func = cur_func;
  cur_frame->outreg = outreg;
  cur_frame++;
  cur_index = cur_func;
  vm_fetch;
  run_next_op;
}
do_tail_call:
{
  unsigned char func = read_reg;
  unsigned char nargs = read_reg;
  for (int argno = 0; argno < nargs; argno++)
  {
    unsigned char from = read_reg;
    cur_locals[argno] = cur_locals[from];
  }
  int next_func = cur_locals[func].bytecode;
  cur_index = next_func;
  cur_func = next_func;
  vm_fetch;
  run_next_op;
}
do_tail_rec:
{
  unsigned char nargs = read_reg;
  for (int argno = 0; argno < nargs; argno++)
  {
    unsigned char from = read_reg;
    cur_locals[argno] = cur_locals[from];
  }
  cur_index = cur_func;
  vm_fetch;
  run_next_op;
}
do_store_reg:
{
  unsigned char to = read_reg;
  unsigned char from = read_reg;
  vm_fetch;
  cur_locals[to] = cur_locals[from];
  run_next_op;
}
do_store_num:
{
  unsigned char to = read_reg;
  number_t from = read_num;
  vm_fetch;
  cur_locals[to] = (value_t){.number = from};
  run_next_op;
}
do_store_log:
{
  unsigned char to = read_reg;
  bool from = read_bool;
  vm_fetch;
  cur_locals[to] = (value_t){.logical = from};
  run_next_op;
}
do_store_fun:
{
  unsigned char to = read_reg;
  int func_end = read_loc;
  int head = cur_index;
  cur_index = func_end;
  vm_fetch;
  cur_locals[to] = (value_t){.bytecode = head};
  run_next_op;
}
do_equal_num:
{
  unsigned char to = read_reg;
  unsigned char lhs = read_reg;
  number_t rhs = read_num;
  vm_fetch;
  cur_locals[to] = (value_t){
      .logical = cur_locals[lhs].number == rhs,
  };
  run_next_op;
}
do_not_equal:
{
  unsigned char to = read_reg;
  unsigned char lhs = read_reg;
  unsigned char rhs = read_reg;
  vm_fetch;
  cur_locals[to] = (value_t){
      .logical = cur_locals[lhs].number != cur_locals[rhs].number,
  };
  run_next_op;
}
do_not_equal_num:
{
  unsigned char to = read_reg;
  unsigned char lhs = read_reg;
  number_t rhs = read_num;
  vm_fetch;
  cur_locals[to] = (value_t){
      .logical = cur_locals[lhs].number != rhs,
  };
  run_next_op;
}
do_less:
{
  unsigned char to = read_reg;
  unsigned char lhs = read_reg;
  unsigned char rhs = read_reg;
  vm_fetch;
  cur_locals[to] = (value_t){
      .logical = cur_locals[lhs].number < cur_locals[rhs].number,
  };
  run_next_op;
}
do_less_num:
{
  unsigned char to = read_reg;
  unsigned char lhs = read_reg;
  number_t rhs = read_num;
  vm_fetch;
  cur_locals[to] = (value_t){
      .logical = cur_locals[lhs].number < rhs,
  };
  run_next_op;
}
do_greater:
{
  unsigned char to = read_reg;
  unsigned char lhs = read_reg;
  unsigned char rhs = read_reg;
  vm_fetch;
  cur_locals[to] = (value_t){
      .logical = cur_locals[lhs].number > cur_locals[rhs].number,
  };
  run_next_op;
}
do_greater_num:
{
  unsigned char to = read_reg;
  unsigned char lhs = read_reg;
  number_t rhs = read_num;
  vm_fetch;
  cur_locals[to] = (value_t){
      .logical = cur_locals[lhs].number > rhs,
  };
  run_next_op;
}
do_equal:
{
  unsigned char to = read_reg;
  unsigned char lhs = read_reg;
  unsigned char rhs = read_reg;
  vm_fetch;
  cur_locals[to] = (value_t){
      .logical = cur_locals[lhs].number == cur_locals[rhs].number,
  };
  run_next_op;
}
do_less_than_equal:
{
  unsigned char to = read_reg;
  unsigned char lhs = read_reg;
  unsigned char rhs = read_reg;
  vm_fetch;
  cur_locals[to] = (value_t){
      .logical = cur_locals[lhs].number <= cur_locals[rhs].number,
  };
  run_next_op;
}
do_less_than_equal_num:
{
  unsigned char to = read_reg;
  unsigned char lhs = read_reg;
  number_t rhs = read_num;
  vm_fetch;
  cur_locals[to] = (value_t){
      .logical = cur_locals[lhs].number <= rhs,
  };
  run_next_op;
}
do_greater_than_equal:
{
  unsigned char to = read_reg;
  unsigned char lhs = read_reg;
  unsigned char rhs = read_reg;
  vm_fetch;
  cur_locals[to] = (value_t){
      .logical = cur_locals[lhs].number >= cur_locals[rhs].number,
  };
  run_next_op;
}
do_greater_than_equal_num:
{
  unsigned char to = read_reg;
  unsigned char lhs = read_reg;
  number_t rhs = read_num;
  vm_fetch;
  cur_locals[to] = (value_t){
      .logical = cur_locals[lhs].number >= rhs,
  };
  run_next_op;
}
do_jump_always:
{
  int to = read_loc;
  cur_index = to;
  vm_fetch;
  run_next_op;
}
do_jump_if_false:
{
  int to = read_loc;
  unsigned char from = read_reg;
  if (cur_locals[from].logical == false)
  {
    cur_index = to;
  }
  vm_fetch;
  run_next_op;
}
do_jump_if_true:
{
  int to = read_loc;
  unsigned char from = read_reg;
  if (cur_locals[from].logical == true)
  {
    cur_index = to;
  }
  vm_fetch;
  run_next_op;
}
do_jump_if_equal:
{
  int to = read_loc;
  unsigned char lhs = read_reg;
  unsigned char rhs = read_reg;
  if (cur_locals[lhs].number == cur_locals[rhs].number)
  {
    cur_index = to;
  }
  vm_fetch;
  run_next_op;
}
do_jump_if_equal_num:
{
  int to = read_loc;
  unsigned char lhs = read_reg;
  number_t rhs = read_num;
  if (cur_locals[lhs].number == rhs)
  {
    cur_index = to;
  }
  vm_fetch;
  run_next_op;
}
do_jump_if_not_equal:
{
  int to = read_loc;
  unsigned char lhs = read_reg;
  unsigned char rhs = read_reg;
  if (cur_locals[lhs].number != cur_locals[rhs].number)
  {
    cur_index = to;
  }
  vm_fetch;
  run_next_op;
}
do_jump_if_not_equal_num:
{
  int to = read_loc;
  unsigned char lhs = read_reg;
  number_t rhs = read_num;
  if (cur_locals[lhs].number != rhs)
  {
    cur_index = to;
  }
  vm_fetch;
  run_next_op;
}
do_jump_if_less:
{
  int to = read_loc;
  unsigned char lhs = read_reg;
  unsigned char rhs = read_reg;
  if (cur_locals[lhs].number < cur_locals[rhs].number)
  {
    cur_index = to;
  }
  vm_fetch;
  run_next_op;
}
do_jump_if_less_num:
{
  int to = read_loc;
  unsigned char lhs = read_reg;
  number_t rhs = read_num;
  if (cur_locals[lhs].number < rhs)
  {
    cur_index = to;
  }
  vm_fetch;
  run_next_op;
}
do_jump_if_less_than_equal:
{
  int to = read_loc;
  unsigned char lhs = read_reg;
  unsigned char rhs = read_reg;
  if (cur_locals[lhs].number <= cur_locals[rhs].number)
  {
    cur_index = to;
  }
  vm_fetch;
  run_next_op;
}
do_jump_if_less_than_equal_num:
{
  int to = read_loc;
  unsigned char lhs = read_reg;
  number_t rhs = read_num;
  if (cur_locals[lhs].number <= rhs)
  {
    cur_index = to;
  }
  vm_fetch;
  run_next_op;
}
do_jump_if_greater:
{
  int to = read_loc;
  unsigned char lhs = read_reg;
  unsigned char rhs = read_reg;
  if (cur_locals[lhs].number > cur_locals[rhs].number)
  {
    cur_index = to;
  }
  vm_fetch;
  run_next_op;
}
do_jump_if_greater_num:
{
  int to = read_loc;
  unsigned char lhs = read_reg;
  number_t rhs = read_num;
  if (cur_locals[lhs].number > rhs)
  {
    cur_index = to;
  }
  vm_fetch;
  run_next_op;
}
do_jump_if_greater_than_equal:
{
  int to = read_loc;
  unsigned char lhs = read_reg;
  unsigned char rhs = read_reg;
  if (cur_locals[lhs].number >= cur_locals[rhs].number)
  {
    cur_index = to;
  }
  vm_fetch;
  run_next_op;
}
do_jump_if_greater_than_equal_num:
{
  int to = read_loc;
  unsigned char lhs = read_reg;
  number_t rhs = read_num;
  if (cur_locals[lhs].number >= rhs)
  {
    cur_index = to;
  }
  vm_fetch;
  run_next_op;
}
do_inc:
{
  unsigned char target = read_reg;
  unsigned char rhs = read_reg;
  vm_fetch;
  cur_locals[target] = (value_t){
      .number = cur_locals[target].number + cur_locals[rhs].number,
  };
  run_next_op;
}
do_inc_num:
{
  unsigned char target = read_reg;
  number_t rhs = read_num;
  vm_fetch;
  cur_locals[target] = (value_t){
      .number = cur_locals[target].number + rhs,
  };
  run_next_op;
}
do_dec:
{
  unsigned char target = read_reg;
  unsigned char rhs = read_reg;
  vm_fetch;
  cur_locals[target] = (value_t){
      .number = cur_locals[target].number - cur_locals[rhs].number,
  };
  run_next_op;
}
do_dec_num:
{
  unsigned char target = read_reg;
  number_t rhs = read_num;
  vm_fetch;
  cur_locals[target] = (value_t){
      .number = cur_locals[target].number - rhs,
  };
  run_next_op;
}
do_add:
{
  unsigned char to = read_reg;
  unsigned char lhs = read_reg;
  unsigned char rhs = read_reg;
  vm_fetch;
  cur_locals[to] = (value_t){
      .number = cur_locals[lhs].number + cur_locals[rhs].number,
  };
  run_next_op;
}
do_add_num:
{
  unsigned char to = read_reg;
  unsigned char lhs = read_reg;
  number_t rhs = read_num;
  vm_fetch;
  cur_locals[to] = (value_t){
      .number = cur_locals[lhs].number + rhs,
  };
  run_next_op;
}
do_mul:
{
  unsigned char to = read_reg;
  unsigned char lhs = read_reg;
  unsigned char rhs = read_reg;
  vm_fetch;
  cur_locals[to] = (value_t){
      .number = cur_locals[lhs].number * cur_locals[rhs].number,
  };
  run_next_op;
}
do_mul_num:
{
  unsigned char to = read_reg;
  unsigned char lhs = read_reg;
  number_t rhs = read_num;
  vm_fetch;
  cur_locals[to] = (value_t){
      .number = cur_locals[lhs].number * rhs,
  };
  run_next_op;
}
do_sub:
{
  unsigned char to = read_reg;
  unsigned char lhs = read_reg;
  unsigned char rhs = read_reg;
  vm_fetch;
  cur_locals[to] = (value_t){
      .number = cur_locals[lhs].number - cur_locals[rhs].number,
  };
  run_next_op;
}
do_sub_num:
{
  unsigned char to = read_reg;
  unsigned char lhs = read_reg;
  number_t rhs = read_num;
  vm_fetch;
  cur_locals[to] = (value_t){
      .number = cur_locals[lhs].number - rhs,
  };
  run_next_op;
}
do_div:
{
  unsigned char to = read_reg;
  unsigned char lhs = read_reg;
  unsigned char rhs = read_reg;
  vm_fetch;
  cur_locals[to] = (value_t){
      .number = cur_locals[lhs].number / cur_locals[rhs].number,
  };
  run_next_op;
}
do_div_num:
{
  unsigned char to = read_reg;
  unsigned char lhs = read_reg;
  number_t rhs = read_num;
  vm_fetch;
  cur_locals[to] = (value_t){
      .number = cur_locals[lhs].number / rhs,
  };
  run_next_op;
}
do_mod:
{
  unsigned char to = read_reg;
  unsigned char lhs = read_reg;
  unsigned char rhs = read_reg;
  vm_fetch;
  cur_locals[to] = (value_t){
      .number = fmod(cur_locals[lhs].number, cur_locals[rhs].number),
  };
  run_next_op;
}
do_mod_num:
{
  unsigned char to = read_reg;
  unsigned char lhs = read_reg;
  number_t rhs = read_num;
  vm_fetch;
  cur_locals[to] = (value_t){
      .number = fmod(cur_locals[lhs].number, rhs),
  };
  run_next_op;
}
do_println:
{
  unsigned char from = read_reg;
  vm_fetch;
  number_t num = cur_locals[from].number;
  if (fmod(num, 1) == 0)
  {
    printf("%i\n", num);
  }
  else
  {
    printf("%i\n", num);
  }
  run_next_op;
}
}
