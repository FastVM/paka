module quest.std.number;

import std.conv;
import std.stdio;
import std.algorithm;
import std.parallelism;
import std.range;
import core.memory;
import purr.dynamic;
import quest.qscope;
import quest.maker;
import quest.dynamic;
import quest.globals;

Dynamic numberText(Args args)
{
    if (args[0].isNumber)
    {
        return "Number".qdynamic;
    }
    return args[0].tab.meta["val".dynamic].as!double
        .to!string
        .qdynamic;
}

Dynamic numberAdd(Args args)
{
    return qdynamic(args[0].getNumber + args[1].getNumber);
}

Dynamic numberSub(Args args)
{
    return qdynamic(args[0].getNumber - args[1].getNumber);
}

Dynamic numberMul(Args args)
{
    return qdynamic(args[0].getNumber * args[1].getNumber);
}

Dynamic numberDiv(Args args)
{
    return qdynamic(args[0].getNumber / args[1].getNumber);
}

Dynamic numberMod(Args args)
{
    return qdynamic(args[0].getNumber % args[1].getNumber);
}

Dynamic numberPow(Args args)
{
    return qdynamic(args[0].getNumber ^^ args[1].getNumber);
}

Dynamic numberBitAnd(Args args)
{
    return qdynamic(args[0].getValue.as!int & args[1].getValue.as!int);
}

Dynamic numberBitOr(Args args)
{
    return qdynamic(args[0].getValue.as!int | args[1].getValue.as!int);
}

Dynamic numberBitXor(Args args)
{
    return qdynamic(args[0].getValue.as!int ^ args[1].getValue.as!int);
}

Dynamic numberBitNot(Args args)
{
    return qdynamic(~args[0].getValue.as!int);
}

Dynamic numberBitShiftRight(Args args)
{
    return qdynamic(args[0].getValue.as!int >> args[1].getValue.as!int);
}

Dynamic numberBitShiftLeft(Args args)
{
    return qdynamic(args[0].getValue.as!int << args[1].getValue.as!int);
}

Dynamic numberSetAdd(Args args)
{
    args[0].setValue(dynamic(args[0].getNumber + args[1].getNumber));
    return args[0];
}

Dynamic numberSetSub(Args args)
{
    args[0].setValue(dynamic(args[0].getNumber - args[1].getNumber));
    return args[0];
}

Dynamic numberSetMul(Args args)
{
    args[0].setValue(dynamic(args[0].getNumber * args[1].getNumber));
    return args[0];
}

Dynamic numberSetDiv(Args args)
{
    args[0].setValue(dynamic(args[0].getNumber / args[1].getNumber));
    return args[0];
}

Dynamic numberSetMod(Args args)
{
    args[0].setValue(dynamic(args[0].getNumber % args[1].getNumber));
    return args[0];
}

Dynamic numberSetPow(Args args)
{
    args[0].setValue(dynamic(args[0].getNumber ^^ args[1].getNumber));
    return args[0];
}

Dynamic numberSetBitAnd(Args args)
{
    args[0].setValue(dynamic(args[0].getNumber ^^ args[1].getNumber));
    return args[0];
}

Dynamic numberSetBitOr(Args args)
{
    args[0].setValue(dynamic(args[0].getValue.as!int & args[1].getValue.as!int));
    return args[0];
}

Dynamic numberSetBitXor(Args args)
{
    args[0].setValue(dynamic(args[0].getValue.as!int ^ args[1].getValue.as!int));
    return args[0];
}

Dynamic numberSetBitShiftLeft(Args args)
{
    args[0].setValue(dynamic(args[0].getValue.as!int << args[1].getValue.as!int));
    return args[0];
}

Dynamic numberSetBitShiftRight(Args args)
{
    args[0].setValue(dynamic(args[0].getValue.as!int >> args[1].getValue.as!int));
    return args[0];
}

Dynamic numberCall(Args args)
{
    return qdynamic(args[0].getNumber * args[1].getNumber);
}

Dynamic numberNeg(Args args)
{
    return qdynamic(-args[0].getNumber);
}

Dynamic numberNot(Args args)
{
    return qdynamic(!args[0].getNumber);
}

Dynamic numberPos(Args args)
{
    return qdynamic(-args[0].getNumber);
}

Dynamic numberEq(Args args)
{
    double lhs = args[0].getNumber;
    double rhs = args[1].getNumber;
    return qdynamic(lhs == rhs);
}

Dynamic numberCmp(Args args)
{
    double lhs = args[0].getNumber;
    double rhs = args[1].getNumber;
    if (lhs < rhs)
    {
        return qdynamic(-1);
    }
    if (lhs == rhs)
    {
        return 0.qdynamic;
    }
    return 1.qdynamic; 
}

Dynamic numberUpto(Args args)
{
    double dbegin = args[0].getNumber;
    double dabove = args[1].getNumber;
    assert(dbegin % 1 == 0);
    assert(dabove % 1 == 0);
    size_t begin = cast(size_t) dbegin;
    size_t above = cast(size_t) dabove;
    size_t diff = above - begin;
    Dynamic* ptr = cast(Dynamic*) GC.malloc(Dynamic.sizeof * diff, 0, typeid(Dynamic));
    foreach (i; 0..diff)
    {
        ptr[i] =.qdynamic(i + begin);
    }
    return ptr[0 .. diff].qdynamic;
}
