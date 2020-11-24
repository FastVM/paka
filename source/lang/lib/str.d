module lang.lib.str;

import lang.base;
import lang.dynamic;
import lang.number;
import std.array;
import std.string;
import std.algorithm;
import std.stdio;
import std.conv;
import std.uni;

Pair[] libstr()
{
    Pair[] ret = [
        Pair("len", &liblen), Pair("split", &libsplit),
        Pair("join", &libjoin), Pair("chars", &libchars),
        Pair("subs", &libsubs), Pair("to_upper",
                dynamic(&libtoupper)), Pair("to_lower", &libtolower),
        Pair("to_number", &libtonumber),
        Pair("slice", &libslice), Pair("strip",
                dynamic(&libstrip)), Pair("char", &libchar),
        Pair("ascii", &libascii), Pair("from", &libfrom),
    ];
    return ret;
}

/// calls tostring of object
void libfrom(Cont cont, Args args)
{
    cont(dynamic(args[0].to!string));
    return;
}

/// gets length of string
void liblen(Cont cont, Args args)
{
    cont(dynamic(args[0].str.length));
    return;
}

/// reutrns ascii value of first char of string
void libascii(Cont cont, Args args)
{
    cont(dynamic(cast(double) args[0].str[0]));
    return;
}

/// reutrns first char of string
void libchar(Cont cont, Args args)
{
    cont(dynamic(cast(string) [cast(char) args[0].as!size_t]));
    return;
}

/// reutrns string split at deliminer
void libsplit(Cont cont, Args args)
{
    cont(dynamic(args[0].str.splitter(args[1].str).map!(x => dynamic(x)).array));
    return;
}

/// joins string to deliminer
void libjoin(Cont cont, Args args)
{
    cont(dynamic(cast(string) args[1].arr.map!(x => x.str).joiner(args[0].str).array));
    return;
}

/// reutrns string split at everey char
void libchars(Cont cont, Args args)
{
    cont(dynamic(args[0].str.map!(x => dynamic(x.to!string)).array));
    return;
}

/// replaces all occurrences of deliminer within string
void libsubs(Cont cont, Args args)
{
    cont(dynamic(cast(string) args[0].str.substitute(args[1].str, args[2].str).array));
    return;
}

/// return uppercase ascii string
void libtoupper(Cont cont, Args args)
{
    cont(dynamic(args[0].str.toUpper));
    return;
}

/// return lowercase ascii string
void libtolower(Cont cont, Args args)
{
    cont(dynamic(args[0].str.toLower));
    return;
}

/// return string converted to string
void libtonumber(Cont cont, Args args)
{
    cont(Dynamic.strToNum(args[0].str));
    return;
}

/// return string without whitespace on either end
void libstrip(Cont cont, Args args)
{
    cont(dynamic(args[0].str.strip));
    return;
}

/// return sliced string similar to arr.slice
void libslice(Cont cont, Args args)
{
    if (args.length == 2)
    {
        cont(dynamic(args[0].str[args[1].as!size_t .. $]));
        return;
    }
    else
    {
        cont(dynamic(args[0].str[args[1].as!size_t .. args[2].as!size_t]));
        return;
    }
}
