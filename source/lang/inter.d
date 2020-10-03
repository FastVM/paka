module lang.inter;

import std.traits;
import std.stdio;
import std.functional;
import std.conv;
import lang.vm;
import lang.walk;
import lang.bytecode;
import lang.base;
import lang.ast;
import lang.dynamic;
import lang.dext.parse;
import lang.vm;
import lang.inter;
import lang.dext.repl;

Dynamic eval(size_t ctx, string code)
{
    Node node = code.parse;
    Walker walker = new Walker;
    Function func = walker.walkProgram(node, ctx);
    func.captured = ctx.loadBase;
    return run(func, [func.exportLocalsToBaseCallback]);
}

void define(T)(size_t ctx, string name, T value)
{
    ctx.rootBase ~= Pair(name, value.toDynamic);
}

// Dynamic toDynamic()
// {
//     return Dynamic.nil;
// }

// void fromDynamic(T)(Dynamic t) if (is(T == void))
// {
//     assert(t.type == Dynamic.Type.nil);
// }

// Dynamic toDynamic(Dynamic d)
// {
//     return d;
// }

// T fromDynamic(T)(Dynamic d) if (is(T == Dynamic))
// {
//     return d;
// }

// Dynamic toDynamic(T)(T v) if (isNumeric!T)
// {
//     return dynamic(v);
// }

// T fromDynamic(T)(Dynamic v) if (isNumeric!T)
// {
//     return cast(T) v.n um;
// }

// Dynamic toDynamic(T)(T[] v)
// {
//     Dynamic[] ret;
//     foreach (i; v)
//     {
//         ret ~= i.toDynamic;
//     }
//     return dynamic(ret);
// }

// Dynamic toDynamic(string v)
// {
//     return dynamic(v);
// }

// T fromDynamic(T)(Dynamic v) if (is(T == string))
// {
//     return v.str;
// }

// T fromDynamic(T)(Dynamic a) if (isArray!T && !is(T == string))
// {
//     T ret;
//     foreach (i, v; a.arr)
//     {
//         ret ~= v.fromDynamic!(ForeachType!T);
//     }
//     return ret;
// }

// Dynamic[] toDynamicArray(T...)(T args)
// {
//     Dynamic[] ret;
//     static foreach (arg; args)
//     {
//         ret ~= arg.toDynamic;
//     }
//     return ret;
// }

// Dynamic toDynamic(R, A...)(R function(A) arg)
// {
//     return dynamic((Dynamic[] args) {
//         A fargs;
//         foreach (i, T; A)
//         {
//             fargs[i] = args[i].fromDynamic!T;
//         }
//         static if (is(R == void))
//         {
//             arg(fargs);
//             return Dynamic.nil;
//         }
//         else
//         {
//             return arg(fargs).toDynamic;
//         }
//     });
// }

// Dynamic toDynamic(R, A...)(R delegate(A) arg)
// {
//     return dynamic((Dynamic[] args) {
//         A fargs;
//         foreach (i, T; A)
//         {
//             fargs[i] = args[i].fromDynamic!T;
//         }
//         static if (is(R == void))
//         {
//             arg(fargs);
//             return Dynamic.nil;
//         }
//         else
//         {
//             return arg(fargs).toDynamic;
//         }
//     });
// }

// T fromDynamic(T)(Dynamic v) if (isDelegate!T)
// {
//     alias Ret = ReturnType!T;
//     alias Args = Parameters!T;
//     return cast(Ret delegate(Args))(Args args) {
//         Dynamic[] dargs = toDynamicArray!Args(args);
//         switch (v.type)
//         {
//         default:
//             assert(0);
//         case Dynamic.Type.pro:
//             return run(v.fun.pro, dargs).fromDynamic!Ret;
//         case Dynamic.Type.del:
//             return (*v.fun.del)(dargs).fromDynamic!Ret;
//         case Dynamic.Type.fun:
//             return v.fun.fun(dargs).fromDynamic!Ret;
//         }
//     };
// }

// Dynamic overload(A...)(A args)
// {
//     return dynamic((Dynamic[] args) {});
// }

// // Dynamic toDynamic(Ret, Args...)(Ret delegate(Args) del)
// // {
// //     return dynamic((Dynamic[] dargs) {
// //         Args args;
// //         foreach (i, Arg; Args)
// //         {
// //             args[i] = dargs[i].fromDynamic!(Arg);
// //         }
// //         static if (is(Ret == void))
// //         {
// //             del(args);
// //         }
// //         else
// //         {
// //             return del(args).toDynamic;
// //         }
// //     });
// // }

// Dynamic eval(A...)(string code, A args)
// {
//     return evalTo!Dynamic(code, args);
// }
