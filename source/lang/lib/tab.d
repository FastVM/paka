module lang.lib.tab;
import lang.base;
import lang.dynamic;
import lang.data.map;
import std.stdio;

Pair[] libtab()
{
    Pair[] ret = [Pair("len", &liblen),];
    return ret;
}

// void libmap(Cont cont, Args args)
// {
//     Mapping ret = emptyMapping;
//     foreach (key, value; args[0].tab)
//     {
//         ret[key] = args[1]([key, value]);
//     }
//     Table tab = new Table(ret);
//     cont(dynamic(tab));
//     return;
// }

// void libmaparr(Cont cont, Args args)
// {
//     Dynamic[] ret;
//     foreach (key, value; args[0].tab)
//     {
//         ret ~= args[1]([key, value]);
//     }
//     cont(dynamic(ret));
//     return;
// }

// void libeach(Cont cont, Args args)
// {
//     foreach (key, value; args[0].tab)
//     {
//         args[1]([key, value]);
//     }
//     cont(Dynamic.init);
//     return;
// }

// void libfiltervalues(Cont cont, Args args)
// {
//     Dynamic[] ret;
//     foreach (key, value; args[0].tab)
//     {
//         if (args[1]([key, value]).isTruthy)
//         {
//             ret ~= value;
//         }
//     }
//     cont(dynamic(ret));
//     return;
// }

// void libfilterkeys(Cont cont, Args args)
// {
//     Dynamic[] ret;
//     foreach (key, value; args[0].tab)
//     {
//         if (args[1]([key, value]).isTruthy)
//         {
//             ret ~= key;
//         }
//     }
//     cont(dynamic(ret));
//     return;
// }

// void libfilter(Cont cont, Args args)
// {
//     Mapping ret = emptyMapping;
//     foreach (key, value; args[0].tab)
//     {
//         if (args[1]([key, value]).isTruthy)
//         {
//             ret[key] = value;
//         }
//     }
//     Table tab = new Table(ret);
//     cont(dynamic(tab));
//     return;
// }

void liblen(Cont cont, Args args)
{
    cont(dynamic(args[0].tab.length));
    return;
}
