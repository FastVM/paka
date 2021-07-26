
#include <vm/vm.h>
#include <vm/debug.h>

#define vm_ref(value) *const value

void vm_asm_strip(const char **const src)
{
    while (**src == ' ' || **src == '\t')
    {
        *src += 1;
    }
}

void vm_asm_strip_endl(const char **const src)
{
    while (**src == ';' || **src == '\n' || **src == '\r' || **src == ' ' || **src == '\t')
    {
        *src += 1;
    }
}

integer_t vm_asm_read_num(const char **const src)
{
    const char *init = *src;
    bool negate = **src == '-';
    if (negate || **src == '+')
    {
        *src += 1;
    }
    integer_t ret = 0;
    int count = 0;
    while ('0' <= **src && **src <= '9')
    {
        ret = (ret * 10) + (**src - '0');
        *src += 1;
        count += 1;
    }
    if (count == 0)
    {
        *src = init;
        return 0;
    }
    return ret;
}

bool vm_asm_read_bool(const char **const src)
{
    if (!strncmp(*src, "true", 4))
    {
        *src += 4;
        return true;
    }
    else if (!strncmp(*src, "false", 5))
    {
        *src += 5;
        return true;
    }
    else
    {
        return false;
    }
}

void vm_asm_skip_fun(const char **const src)
{
    const char *init = *src;
}

reg_t vm_asm_read_reg(const char **const src)
{
    const char *init = *src;
    if (**src != 'r')
    {
        return 0;
    }
    *src += 1;
    const char *last = *src;
    integer_t ret = vm_asm_read_num(src);
    if (last == *src)
    {
        *src = init;
        return 0;
    }
    if (ret < 0)
    {
        *src = init;
        return 0;
    }
    return (reg_t)ret;
}

opcode_t vm_asm_match_opcode(const char **const src)
{
    for (opcode_t op = 0; op < OPCODE_MAX1; op++)
    {
        const char *orig = *src;
        vm_asm_strip(src);
        const char *name = vm_opcode_name(op);
        int len = strlen(name);
        if (!strncmp(name, *src, len))
        {
            *src += len;
            const char *ret = *src;
            const char *fmt = vm_opcode_format(op);
            while (true)
            {
                vm_asm_strip(src);
                char cur = *fmt;
                fmt += 1;
                switch (cur)
                {
                case 'r':
                {
                    const char *init = *src;
                    vm_asm_read_reg(src);
                    if (init == *src)
                    {
                        goto fail;
                    }
                    break;
                }
                case 'l':
                {
                    const char *init = *src;
                    vm_asm_read_bool(src);
                    if (init == *src)
                    {
                        goto fail;
                    }
                    break;
                }
                case 'j':
                {
                    if (**src != '[')
                    {
                        goto fail;
                    }
                    while (**src != ']')
                    {
                        *src += 1;
                    }
                    *src += 1;
                    goto success;
                }
                case 'n':
                {
                    const char *init = *src;
                    vm_asm_read_num(src);
                    if (init == *src)
                    {
                        goto fail;
                    }
                    break;
                }
                case 'c':
                {
                    if (**src != '(')
                    {
                        goto fail;
                    }
                    *src += 1;
                    vm_asm_strip(src);
                    while (**src != ')')
                    {
                        const char *last = *src;
                        vm_asm_read_reg(src);
                        if (last == *src)
                        {
                            goto fail;
                        }
                        vm_asm_strip(src);
                    }
                    *src += 1;
                    break;
                }
                case 'f':
                {
                    goto fail;
                }
                case '\0':
                {
                    vm_asm_strip(src);
                    if (**src == '\n' || **src == '\r' || **src == ';' || **src == '\0')
                    {
                        goto success;
                    }
                    else
                    {
                        goto fail;
                    }
                }
                default:
                {
                    printf("error: invalid opcode format: %c\n", cur);
                    return -1;
                }
                }
            }
        success:
            vm_asm_strip(&ret);
            *src = ret;
            return op;
        }
    fail:
        *src = orig;
    }
    return (opcode_t)-1;
}

int vm_asm_read_opcode(opcode_t *buffer, opcode_t op, const char **const src)
{
    opcode_t *init = buffer;
    const char *fmt = vm_opcode_format(op);
    *(opcode_t *)buffer = op;
    buffer += 1;
    while (true)
    {
        vm_asm_strip(src);
        char cur = *fmt;
        fmt += 1;
        switch (cur)
        {
        case 'r':
        {
            reg_t reg = vm_asm_read_reg(src);
            *(reg_t *)buffer = reg;
            buffer += sizeof(reg_t);
            break;
        }
        case 'l':
        {
            bool log = vm_asm_read_bool(src);
            *(bool *)buffer = log;
            buffer += sizeof(bool);
            break;
        }
        case 'n':
        {
            integer_t reg = vm_asm_read_num(src);
            *(integer_t *)buffer = reg;
            buffer += sizeof(integer_t);
            break;
        }
        case 'c':
        {
            *src += 1;
            vm_asm_strip(src);
            opcode_t *count_loc = buffer;
            buffer += sizeof(reg_t);
            reg_t count = 0;
            while (**src != ')')
            {
                printf("%s\n", *src);
                reg_t reg = vm_asm_read_reg(src);
                vm_asm_strip(src);
                *(reg_t *)buffer = reg;
                buffer += sizeof(reg_t);
                count += 1;
            }
            *(reg_t *)count_loc = count;
            *src += 1;
            printf("%s\n", *src);
            break;
        }
        case 'f':
        {
            printf("no funcs yet\n");
            return 0;
        }
        case '\0':
        {
            return buffer - init;
        }
        default:
        {
            printf("error: invalid opcode format: %c\n", cur);
            return -1;
        }
        }
    }
}

opcode_t *vm_assemble(const char *src)
{
    int nalloc = 1 << 16;
    opcode_t *ret = malloc(nalloc);
    opcode_t *mem = ret;
    vm_asm_strip_endl(&src);
    while (*src != '\0')
    {
        int index = mem - ret;
        if (index + (1 << 12) > nalloc)
        {
            nalloc = nalloc * 2 + (1 << 16);
            ret = realloc(ret, nalloc);
        }
        const char *last = src;
        opcode_t res = vm_asm_match_opcode(&src);
        if (last == src)
        {
            printf("%s", src);
            printf("error: could not figure out opcode\n");
            free(ret);
            return NULL;
        }
        if (res == -1)
        {
            printf("error: could not figure out opcode args\n");
            free(ret);
            return NULL;
        }
        vm_asm_strip(&src);
        int nbytes = vm_asm_read_opcode(mem, res, &src);
        if (nbytes == 0)
        {
            printf("error: internal reader of opcodes is broken somhow\n");
            free(ret);
            return NULL;
        }
        mem += nbytes;
        vm_asm_strip_endl(&src);
        printf("%s\n", src);
    }
    for (int i = 0; i < 16; i++)
    {
        *mem = OPCODE_EXIT;
        mem += 1;
    }
    return ret;
}

int main(int argc, const char **argv)
{
    for (int argno = 1; argno < argc; argno++)
    {
        const char *name = argv[argno];
        FILE *input = fopen(name, "r");
        fseek(input, 0L, SEEK_END);
        int size = ftell(input);
        fseek(input, 0, SEEK_SET);
        char *mem = calloc(1, size + 1);
        fread(mem, 1, size, input);
        mem[size] = '\0';
        fclose(input);
        opcode_t *opcodes = vm_assemble(mem);
        free(mem);
        if (opcodes == NULL)
        {
            return 1;
        }
        vm_run(opcodes);
    }
}
