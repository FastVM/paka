module lang.inter;

import std.typecons;
import std.traits;
import std.stdio;
import std.functional;
import std.conv;
import std.algorithm;
import std.meta;
import lang.vm;
import lang.walk;
import lang.bytecode;
import lang.base;
import lang.ast;
import lang.dynamic;
import lang.parse;
import lang.vm;
import lang.inter;
import lang.dext.repl;

Dynamic eval(size_t ctx, string code)
{
    Node node = code.parse;
    Walker walker = new Walker;
    Function func = walker.walkProgram(node, ctx);
    func.captured = ctx.loadBase;
    Dynamic retval = run(func, null, func.exportLocalsToBaseCallback);
    return retval;
}

Dynamic evalFile(string code)
{
    size_t ctx = enterCtx;
    scope (exit)
    {
        exitCtx;
    }
    Node node = code.parse;
    Walker walker = new Walker;
    Function func = walker.walkProgram(node, ctx);
    func.captured = loadBase;
    Dynamic retval = run(func);
    return retval;
}

void define(T)(size_t ctx, string name, T value)
{
    ctx.rootBase ~= Pair(name, value.toDynamic);
}

// Dynamic toDext(T)(T fn) if (isFunctionPointer!T || isDelegate!T)
// {
//     alias R = ReturnType!T;
//     alias A = Parameters!T;
//     Dynamic newFn(Args newFnArgs)
//     {
//         A fnArgs;
//         static foreach (i; 0 .. A.length)
//         {
//             fnArgs[i] = newFnArgs[i].dextTo!(A[i]);
//         }
//         static if (is(R == void))
//         {
//             fn(fnArgs);
//             return Dynamic.nil;
//         }
//         else
//         {
//             return fn(fnArgs).toDext;
//         }
//     }

//     return dynamic(&newFn);
// }

// T dextTo(T)(Dynamic self) if (is(T == Dynamic))
// {
//     return self;
// }

// Dynamic toDext(Dynamic d)
// {
//     return d;
// }

// T dextTo(T)(Dynamic self) if (is(T == bool))
// {
//     return self.log;
// }

// Dynamic toDext(bool b)
// {
//     return b.dynamic;
// }

// static foreach (I; AliasSeq!(byte, ubyte, short, ushort, int, uint, long, ulong))
// {
//     T dextTo(T)(Dynamic self) if (is(T == I))
//     {
//         return self.as!double
//             .to!I;
//     }

//     Dynamic toDext(I s)
//     {
//         return dynamic(cast(double) s);
//     }
// }

// T dextTo(T)(Dynamic self) if (is(T == string))
// {
//     return self.str;
// }

// Dynamic toDext(string s)
// {
//     return s.dynamic;
// }

// Dynamic toDext(Dynamic[] a)
// {
//     return a.dynamic;
// }

// T dextTo(T)(Dynamic self) if (isArray!T)
// {
//     T ret;
//     foreach (i; self.arr)
//     {
//         ret ~= i.dextTo!(ForeachType!T);
//     }
//     return ret;
// }

// T dextTo(T)(Dynamic self) if (is(T == char))
// {
//     return self.str[0];
// }

// T dextTo(T)(Dynamic self) if (isPointer!T)
// {
//     return self.arr[0].to!(PointerTarget!T);
// }

// Dynamic toDext(char v)
// {
//     return v.to!string.dynamic;
// }

// Dynamic toDext(T)(T v) if (is(T == enum))
// {
//     return v.to!size_t.dynamic;
// }

// T dextTo(T)(Dynamic self) if (is(T == class))
// {
//     return cast(T) self.tab.rawIndex("self".dynamic).obj();
// }

// Dynamic toDext(T)(T self) if (is(T == class))
// {
//     alias Members = __traits(allMembers, T);

//     Dynamic getItem(Args args)
//     {
//         static foreach (m; Members)
//         {
//             static if (__traits(compiles, mixin("self." ~ m)) && !banned.canFind(m))
//             {
//                 if (args[1].str == m)
//                 {
//                     static if (isFunction!(mixin("self." ~ m)))
//                     {
//                         return mixin("&self." ~ m).toDext;
//                     }
//                     else static if (is(mixin("self." ~ m) == class))
//                     {
//                         return Class!(mixin("self." ~ m));
//                     }
//                     else
//                     {
//                         return mixin("self." ~ m).toDext;
//                     }
//                 }
//             }
//         }
//         throw new Exception("native object missing property");
//     }

//     Dynamic setItem(Args args)
//     {
//         static foreach (m; Members)
//         {
//             static if (__traits(compiles, mixin("self." ~ m)) && !banned.canFind(m))
//             {
//                 if (args[1].str == m)
//                 {
//                     static if (is(mixin("self." ~ m)))
//                     {
//                         pragma(msg, "type: ", m);
//                     }
//                     else static if (!isFunction!(mixin("self." ~ m)))
//                     {
//                         mixin("self." ~ m) = args[2].dextTo!(typeof(mixin("self." ~ m)));
//                         return Dynamic.nil;
//                     }
//                 }
//             }
//         }
//         throw new Exception("native object missing property for set");
//     }

//     Table meta = new Table(emptyMapping);
//     meta["set".dynamic] = dynamic( & setItem);
//     meta["get".dynamic] = dynamic( & getItem);
//     static if (__traits(hasMember, self, "opBinary"))
//     {
//         alias overs = __traits(getOverloads, self, "opBinary", true);
//         static foreach (op; overs) {
//             static foreach (i; ["~", "+", "*", "-", "/", "%"])
//             {
//                 pragma(msg, op.stringof);
//             }            
//             // pragma(msg, typeof(&op!"~"));
//             // meta["add".dynamic] = toDext(&op!"~");
//         }
//     }
//     Table tab = new Table(emptyMapping, meta);
//     tab.rawSet("self".dynamic, dynamic(cast(Object) self));
//     return tab.dynamic;
// }

// enum string[] banned = [__traits(allMembers, Object), "opBinary", "opUnary"];

// Dynamic Class(alias T)() if (!is(T))
// {
//     return Class!(T!Dynamic);
// }

// Dynamic Class(alias T)() if (is(T))
// {
//     return (Dynamic[] cons) {
//         pragma(msg, "T: ", T);
//         auto self = new T;
//         return self.toDext;
//     }.dynamic;
// }
