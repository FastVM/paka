module ext.bind.binder;
import std.string;
import core.memory;

private extern (C) char* bind_file_to_json(char* str);
private extern (C) char* bind_src_to_json(char* name, char* src);

extern (C) void* GC_calloc(size_t size)
{
    return GC.calloc(size);
}

extern (C) void* GC_realloc(void* ptr, size_t size)
{
    return GC.realloc(ptr, size);
}

extern (C) char* GC_strdup(immutable(char)* str)
{
    char[] ret;
    while (*str)
    {
        ret ~= *str;
        str++;
    }
    ret ~= *str;
    return ret.ptr;
}

extern (C) char* GC_strndup(immutable(char)* str, size_t size)
{
    char[] ret;
    size_t count = 0;
    while (*str && size > count)
    {
        ret ~= *str;
        str++;
        count++;
    }
    ret ~= '\0';
    return ret.ptr;
}

string bindings(string src)
{
    return bind_src_to_json("__main__".dup.ptr, cast(char*) src.dup.toStringz).fromStringz.idup;
}
