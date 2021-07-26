#pragma once

#ifdef VM_USE_COSMO
#include "cosmopolitan.h"
#else
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <math.h>
#include <string.h>
#include <stdint.h>
#endif

typedef int reg_t;
typedef int integer_t;
typedef double number_t;
typedef char opcode_t;

struct value_t;

typedef struct value_t value_t;

struct value_t
{
    union
    {
        bool logical;
        number_t number;
        const char *text;
        int bytecode;
    };
};

enum opcode_t
{
    OPCODE_EXIT,
    OPCODE_STORE_REG,
    OPCODE_STORE_LOG,
    OPCODE_STORE_NUM,
    OPCODE_STORE_STR,
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

void vm_run(opcode_t *mem);
