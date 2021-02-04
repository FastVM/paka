module ext.ffi.base;

import core.sys.posix.dlfcn;
import std.conv;
import std.array;
import std.algorithm;
import std.stdio;
import std.string;
import purr.base;
import purr.dynamic;
import ffi.libffi;

static this()
{
    cif = new ffi_cif;
    bytetype = new BasicType!byte(FFIType.ffiByte).dyn;
    shorttype = new BasicType!short(FFIType.ffiShort).dyn;
    inttype = new BasicType!int(FFIType.ffiInt).dyn;
    longtype = new BasicType!long(FFIType.ffiLong).dyn;
    ubytetype = new BasicType!ubyte(FFIType.ffiUByte).dyn;
    ushorttype = new BasicType!ushort(FFIType.ffiUShort).dyn;
    uinttype = new BasicType!uint(FFIType.ffiUInt).dyn;
    ulongtype = new BasicType!ulong(FFIType.ffiULong).dyn;
    floattype = new BasicType!float(FFIType.ffiFloat).dyn;
    doubletype = new BasicType!double(FFIType.ffiDouble).dyn;
    realtype = new BasicType!real(FFIType.ffiReal).dyn;
}

Pair[] libffi()
{
    Pair[] ret;
    ret.addLib("type", libtypes);
    ret ~= Pair("open", &open);
    return ret;
}

private:

ffi_cif* cif;
Dynamic bytetype;
Dynamic shorttype;
Dynamic inttype;
Dynamic longtype;
Dynamic ubytetype;
Dynamic ushorttype;
Dynamic uinttype;
Dynamic ulongtype;
Dynamic floattype;
Dynamic doubletype;
Dynamic realtype;

Pair[] libtypes()
{
    Pair[] ret;
    ret ~= Pair("function", &functiontype);
    ret ~= Pair("pointer", &pointertype);
    ret ~= Pair("byte", bytetype);
    ret ~= Pair("short", shorttype);
    ret ~= Pair("int", inttype);
    ret ~= Pair("long", longtype);
    ret ~= Pair("ubyte", ubytetype);
    ret ~= Pair("ushort", ushorttype);
    ret ~= Pair("uint", uinttype);
    ret ~= Pair("ulong", ulongtype);
    ret ~= Pair("float", floattype);
    ret ~= Pair("double", doubletype);
    ret ~= Pair("real", realtype);
    return ret;
}

Dynamic functiontype(Dynamic[] args)
{
    return new FunctionType(args[0].getType, args[1].arr.map!(x => x.getType).array).dyn;
}

Dynamic pointertype(Dynamic[] args)
{
    return new PointerType(args[0].getType).dyn;
}

Dynamic open(Dynamic[] args)
{
    Dynamic dname = args[0];
    immutable(char)* name = void;
    if (dname.type == Dynamic.Type.nil)
    {
        name = null;
    }
    else
    {
        name = dname.str.toStringz;
    }
    void* handle = dlopen(name, RTLD_LAZY);
    if (handle is null)
    {
        string message = idup(
                "cannot ffi.open: " ~ dname.to!string ~ ", dlopen error: " ~ dlerror.fromStringz);
        throw new Exception(message);
    }
    Dynamic sym(Dynamic[] args)
    {
        immutable(char)* symname = args[0].str.toStringz;
        void* sym = dlsym(handle, symname);
        if (sym is null)
        {
            string message = idup(
                    "ffi.open(" ~ dname.to!string ~ ").sym(\"" ~ args[0].str
                    ~ "\"), dlopen error: " ~ dlerror.fromStringz);
            throw new Exception(message);
        }
        Type type = args[1].getType;
        return type.conv(sym);
    }

    Mapping tab = emptyMapping;
    tab["sym".dynamic] = dynamic(&sym);
    Mapping meta = emptyMapping;
    meta["str".dynamic] = dynamic("ffi.open(" ~ dname.to!string ~ ")");
    return new Table(tab, new Table(meta), handle).dynamic;
}

Type getType(Dynamic arg)
{
    return cast(Type)*cast(Object*)&arg.tab.native;
}

class Type
{
    string name = "unknown";

    FFIType* type()
    {
        assert(false);
    }

    Dynamic conv(void* arg)
    {
        assert(false);
    }

    void* conv(Dynamic arg)
    {
        assert(false);
    }

    void* empty()
    {
        assert(false);
    }

    final Dynamic dyn()
    {
        Mapping meta = emptyMapping;
        meta["str".dynamic] = name.dynamic;
        return new Table(emptyMapping, new Table(meta), cast(void*) cast(Object) this).dynamic;
    }

    final override string toString()
    {
        return name;
    }
}

class PointerType : Type
{
    Type member;

    this(Type m)
    {
        member = m;
        name = member.to!string ~ '*';
    }

    override FFIType* type()
    {
        return FFIType.ffiPointer;
    }

    override Dynamic conv(void* arg)
    {
        return member.conv(*cast(void**)arg);
    }

    override void* conv(Dynamic arg)
    {
        return [member.conv(arg)].ptr;
    }

    override void* empty()
    {
        return cast(void*) new void[size_t.sizeof];
    }
}

class BasicType(T) : Type
{
    FFIType* type_;

    this(FFIType* t)
    {
        type_ = t;
        name = typeid(T).to!string;
    }

    override FFIType* type()
    {
        return type_;
    }

    override Dynamic conv(void* val)
    {
        return dynamic(cast(double)*cast(T*) val);
    }

    override void* conv(Dynamic arg)
    {
        return cast(void*) new T(cast(T) arg.as!double);
    }

    override void* empty()
    {
        return cast(void*) new T;
    }
}

class FunctionType : Type
{
    Type ret;
    Type[] params;

    this(Type r, Type[] p)
    {
        ret = r;
        params = p;
        name = r.to!string ~ "" ~ "(" ~ params.to!string[1..$-1] ~ ")";
    }

    override Dynamic conv(void* val)
    {
        FFIFunction ffifunc = cast(FFIFunction) val;
        Dynamic retfun(Dynamic[] args)
        {
            void* retptr = ret.empty;
            void*[] argsptr;
            foreach (k, arg; args)
            {
                argsptr ~= params[k].conv(arg);
            }
            ffiCall(ffifunc, ret.type, params.map!(a => a.type).array, retptr, argsptr);
            return ret.conv(retptr);
        }

        return dynamic(&retfun);
    }
}
