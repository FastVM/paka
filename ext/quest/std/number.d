module quest.std.number;

import std.conv;
import std.stdio;
import std.algorithm;
import lang.dynamic;
import quest.qscope;
import quest.maker;
import quest.globals;

Dynamic numberText(Args args)
{
    if (args[0].tab is globalNumber)
    {
        return "Number".makeText;
    }
    return args[0].tab.meta["val".dynamic].as!double.to!string.makeText;
}

Dynamic numberAdd(Args args)
{
    return makeNumber(args[0].getNumber + args[1].getNumber); 
} 

Dynamic numberSub(Args args)
{
    return makeNumber(args[0].getNumber - args[1].getNumber); 
} 

Dynamic numberMul(Args args)
{
    return makeNumber(args[0].getNumber * args[1].getNumber); 
} 

Dynamic numberDiv(Args args)
{
    return makeNumber(args[0].getNumber / args[1].getNumber); 
} 

Dynamic numberMod(Args args)
{
    return makeNumber(args[0].getNumber % args[1].getNumber); 
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

Dynamic numberCmp(Args args)
{
    double lhs = args[0].getNumber;
    double rhs = args[1].getNumber;
    if (lhs < rhs) {
        return makeNumber(-1);
    } 
    if (lhs == rhs)
    {
        return 0.makeNumber;
    }
    return 1.makeNumber;
}
