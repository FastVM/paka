module purr.vm;

import purr.vm.bytecode;
import purr.dynamic;

import core.memory;
import core.stdc.stdlib;

VM* vm;

static this()
{
    vm = cast(VM*) GC.calloc(VM.sizeof);
    vm.linear = cast(List*) GC.malloc(List.sizeof + (1 << 24));
    vm.linear.length = 0;
    vm.framesLow = cast(Frame*) GC.malloc((1 << 16) * Frame.sizeof);
    vm.framesPtr = vm.framesLow;
    vm.framesHigh = vm.framesLow + (1 << 16) - 2;
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

        writeln("DEBUG: ", ptr);
        void* base = GC.addrOf(ptr);
        assert(base !is null);
        size_t len = GC.sizeOf(ptr);
        // writeln("size: ", len);
        // writeln("base: ", base);
        // writeln("head: ", ptr - base);
        // writeln("data: ", base[0 .. len]);
    }

    extern (C) void* vm_alloc(int len)
    {
        import std.stdio : writeln;

        void* ret = GC.calloc(len);
        return ret;
    }

    extern (C) void* vm_realloc(void* ptr, int len)
    {
        void* ret = GC.realloc(ptr, cast(size_t) len);
        return ret;
    }

    extern (C) void vm_error(int op, int top2, int top1)
    {
        import std.conv : to;
        throw new Error("interal error " ~ [op, top2, top1].to!string);
    }

    extern (C) void vm_memcpy(void* src, void* dest, int len)
    {
        src[0 .. len] = dest[0 .. len];
    }
}

Dynamic run(Bytecode func, Dynamic[] args)
{
    return vm_run(vm, func, cast(int) args.length, args.ptr);
}
