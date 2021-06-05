module purr.vm;

import purr.vm.bytecode;
import purr.dynamic;

import core.memory;
import core.stdc.stdlib;

VM* vm;

static this()
{
    vm = cast(VM*) GC.calloc(VM.sizeof);
    int lalloc = (1 << 16) * Dynamic.sizeof;
    vm.linear = cast(List*) GC.malloc(List.sizeof + lalloc);
    vm.linear.length = 0;
    vm.linear.alloc = lalloc;
    vm.framesLow = cast(Frame*) GC.malloc((1 << 8) * Frame.sizeof);
    vm.framesHigh = vm.framesLow + (1 << 8) - 1;
}

extern (C)
{
    extern (C) void vm_print_int(int i)
    {
        import std.stdio : writeln;

        writeln(i);
    }

    extern (C) void vm_print_ptr(void* ptr)
    {
        import std.stdio : writeln;

        void* base = GC.addrOf(ptr);
        assert(base !is null);
        size_t len = GC.sizeOf(ptr);
        writeln("size: ", len);
        writeln("base: ", base);
        writeln("head: ", ptr - base);
        writeln("data: ", base[0 .. len]);
    }

    extern (C) void* vm_alloc(long len)
    {
        import std.stdio : writeln;

        void* ret = GC.calloc(len);
        return ret;
    }

    extern (C) void* vm_realloc(void* ptr, long len)
    {
        void* ret = GC.realloc(ptr, cast(size_t) len);
        return ret;
    }
    extern (C) void vm_memcpy(void* src, void* dest, long len)
    {
        src[0 .. len] = dest[0 .. len];
    }
}

Dynamic run(Bytecode func, Dynamic[] args)
{
    Dynamic ret = vm_run(vm, func, cast(int) args.length, args.ptr);
    if (ret.isError)
    {
        final switch (ret.value.err)
        {
        case Dynamic.Error.unknown:
            throw new Exception("internal error in vm: an unknown error has occured");
        case Dynamic.Error.oom:
            throw new Exception("internal error in vm: out of memory");
        case Dynamic.Error.opcode:
            throw new Exception("internal error in vm: typed instruction given wrong types");
        }
    }
    return ret;
}
