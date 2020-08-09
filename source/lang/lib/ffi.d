module lang.lib.ffi;

import core.memory;
import core.sys.posix.dlfcn;
import lang.data.ffi;
import lang.dynamic;
import std.algorithm;
import std.string;
import std.stdio;
import std.array;

void*[string] libs;

class Library
{
    void* lib;
    this(string v)
    {
        void** libptr = v in libs;
        if (libptr != null)
        {
            lib = libptr;
        }
        else if (v == null)
        {
            lib = dlopen(null, RTLD_LAZY);
        }
        else
        {
            lib = dlopen(v.toStringz, RTLD_LAZY);
        }
        if (lib == null)
        {
            throw new Exception("dlopen error, cannot load");
        }
        libs[v] = lib;
    }

    ~this()
    {
        dlclose(lib);
    }

    void* sym(string v)
    {
        void* ret = dlsym(lib, v.toStringz);

        char* err = dlerror();
        if (err != null)
        {
            throw new Exception(cast(string)("dlsym error: " ~ err.fromStringz));
        }
        return ret;
    }
}

float call(float n)
{
    return n * 2;
}

ffi_type* ffiGetty(string name)
{
    if (name[$ - 1] == '*')
    {
        return &ffi_type_pointer;
    }
    switch (name)
    {
    default:
        throw new Exception("unknown type name in ffi: " ~ name);
    case "void":
        return &ffi_type_void;
    case "ubyte":
        return &ffi_type_uint8;
    case "byte":
        return &ffi_type_sint8;
    case "ushort":
        return &ffi_type_uint16;
    case "short":
        return &ffi_type_sint16;
    case "uint":
        return &ffi_type_uint32;
    case "int":
        return &ffi_type_sint32;
    case "ulong":
        return &ffi_type_uint64;
    case "long":
        return &ffi_type_sint64;
    case "float":
        return &ffi_type_float;
    case "double":
        return &ffi_type_double;
    case "string":
        return &ffi_type_pointer;
    }
}

void* ffiGetTypeValue(Dynamic value, string type)
{
    if (type[$ - 1] == '*')
    {
        alias P = void*;
        return cast(void*) new P(ffiGetTypeValue(value.unbox, cast(string) type[0 .. $ - 1]));
    }
    switch (type)
    {
    default:
        throw new Exception("unknown type name in ffi: " ~ type);
    case "ubyte":
        return cast(void*) new ubyte(cast(ubyte) value.num);
    case "byte":
        return cast(void*) new byte(cast(byte) value.num);
    case "short":
        return cast(void*) new short(cast(short) value.num);
    case "ushort":
        return cast(void*) new ushort(cast(ushort) value.num);
    case "int":
        return cast(void*) new int(cast(int) value.num);
    case "uint":
        return cast(void*) new uint(cast(uint) value.num);
    case "long":
        return cast(void*) new long(cast(long) value.num);
    case "ulong":
        return cast(void*) new ulong(cast(ulong) value.num);
    case "float":
        return cast(void*) new float(cast(float) value.num);
    case "double":
        return cast(void*) new double(cast(double) value.num);
    case "string":
        alias P = char*;
        return cast(void*) new P(cast(P) value.str.toStringz);
    }
}

void ffiGetValueArg(void* ptr, Dynamic val, string type)
{
    if (type[$ - 1] == '*')
    {
        *val.box = ffiGetValue(*cast(void**) ptr, type[0 .. $ - 1]);
    }
}

Dynamic ffiGetValue(void* ptr, string type)
{
    switch (type)
    {
    default:
        throw new Exception("unknown type name in ffi: " ~ type);
    case "ubyte":
        return dynamic(cast(double)*cast(ubyte*) ptr);
    case "byte":
        return dynamic(cast(double)*cast(byte*) ptr);
    case "ushort":
        return dynamic(cast(double)*cast(ushort*) ptr);
    case "short":
        return dynamic(cast(double)*cast(short*) ptr);
    case "uint":
        return dynamic(cast(double)*cast(uint*) ptr);
    case "int":
        return dynamic(cast(double)*cast(int*) ptr);
    case "ulong":
        return dynamic(cast(double)*cast(ulong*) ptr);
    case "long":
        return dynamic(cast(double)*cast(long*) ptr);
    case "float":
        return dynamic(cast(double)*cast(float*) ptr);
    case "double":
        return dynamic(*cast(double*) ptr);
    case "string":
        GC.addRange(ptr, (char*).sizeof);
        return dynamic(cast(string) fromStringz(cast(char*) ptr));
    }
}

Dynamic libselfload(Dynamic[] args)
{
    string libname = args[0].type == Dynamic.Type.nil ? null : args[0].str;
    args = args[1 .. $];
    string name = args[0].str;
    args = args[1 .. $];
    Library lib = new Library(libname);
    void* sym = lib.sym(name);
    ffi_cif cif;
    ffi_type* retty = ffiGetty(args[0].str);
    ffi_type*[] argty = args[1 .. $].map!(d => d.str.ffiGetty).array;
    ffi_prep_cif(&cif, ffi_abi.FFI_DEFAULT_ABI, cast(uint) argty.length, retty, argty.ptr);
    Dynamic[] iargs = args.dup;
    return dynamic((Dynamic[] largs) {
        if (largs.length != iargs.length - 1)
        {
            throw new Exception("too many arguments to ffi function: " ~ name);
        }
        void*[] fargs;
        foreach (i, v; largs)
        {
            fargs ~= ffiGetTypeValue(v, iargs[i + 1].str);
        }
        void* fret = new ubyte[size_t.sizeof].ptr;
        ffi_call(&cif, sym, fret, fargs.ptr);
        foreach (i; 0 .. largs.length)
        {
            ffiGetValueArg(fargs[i], largs[i], iargs[i + 1].str);
        }
        return ffiGetValue(fret, iargs[0].str);
    });
}

// static this()
// {
//     ffi_cif cif;
//     ffi_type*[] args;
//     ffi_type* ret = &ffi_type_float;
//     args ~= &ffi_type_float;
//     ffi_prep_cif(&cif, ffi_abi.FFI_DEFAULT_ABI, cast(uint) args.length, ret, args.ptr);
//     float f = 10;
//     void** fargs = cast(void**)[&f].ptr;
//     void* fret = &f;
//     ffi_call(&cif, &call, fret, fargs);
// }
