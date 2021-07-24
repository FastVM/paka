#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>

int vm_run(void *mem);

int vm_main_file_length(FILE *input)
{
    fseek(input, 0L, SEEK_END);
    int size = ftell(input);
    fseek(input, 0, SEEK_SET);
    return size;
}

void vm_main_run(FILE *input)
{
    int file_len = vm_main_file_length(input);
    void *mem = calloc(1, file_len + 1);
    fread(mem, 1, file_len, input);
    vm_run(mem);
    free(mem);
}

int main(int argc, const char **argv)
{
    vm_main_run(stdin);
    for (int argno = 1; argno < argc; argno++)
    {
        const char *name = argv[argno];
        FILE *file = fopen(name, "rb");
        if (file == NULL)
        {
            printf("could not read file: %s\n", name);
            exit(1);
        }
        vm_main_run(file);
        fclose(file);
    }
}