module purr.vm;

import purr.vm.bytecode;
import purr.dynamic;

import core.memory;
import core.stdc.stdlib;

VM* vm;

static this()
{
    vm = cast(VM*) GC.malloc(VM.sizeof);
    vm.frames = cast(List*) GC.calloc(1, 1 << 20);
    vm.linear = cast(List*) GC.calloc(1, 1 << 20);
}

private extern (C)
{
    extern (C) void vm_print_int(int i)
    {
        import std.stdio: writeln;
        writeln(i);
    }

    extern (C) void vm_print_ptr(void* p)
    {
        import std.stdio: writeln;
        // assert(GC.addrOf(p) !is null);
        // size_t len = GC.sizeOf(p);
        // writeln("len: ", len);
        writeln("ptr: ", p);
        // writeln("data: ", p[0..len]);
    }

    extern (C) void* vm_alloc(int len)
    {
        return calloc(len, cast(size_t) len);
        // return GC.calloc(len, cast(size_t) len);
    }

    extern (C) void * vm_realloc(void * ptr, int len)
    {
        return realloc(ptr, cast(size_t) len);
        // return GC.realloc(ptr, cast(size_t) len);
    }

    extern (C) void vm_error()
    {
        throw new Error("interal error");
    }

    extern (C) void vm_memcpy(void* src, void* dest, int len)
    {
        src[0..len] = dest[0..len]; 
    }
}

Dynamic run(Bytecode func, Dynamic[] args)
{
    return vm_run(vm, func, cast(int) args.length, args.ptr, true);
}
