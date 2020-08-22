module john;

import core.stdc.stdio;

extern (C) int main(int argc, char** argv)
{
    for (size_t i = 1; i < argc; i++)
    {
        printf("arg %d: %s\n", i, argv[i]);
    }
    return 0;
}
