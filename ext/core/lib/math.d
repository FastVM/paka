module ext.core.lib.math;

import purr.dynamic;
import purr.base;
import purr.ast.ast;
import purr.parse;
import purr.ir.walk;
import purr.vm;
import purr.inter;
import purr.srcloc;
import purr.bytecode;
import core.stdc.stdlib;
import core.runtime;
import std.algorithm;
import std.array;
import std.conv;
import std.random;
import std.math;
import purr.io;

typeof(MinstdRand0(0)) rnd;

Pair[] libmath()
{
    Pair[] ret;
    ret ~= FunctionPair!libabs("abs");
    ret ~= FunctionPair!libmin("min");
    ret ~= FunctionPair!libmax("max");
    ret ~= FunctionPair!libsqrt("sqrt");
    ret ~= FunctionPair!libcbrt("cbrt");
    ret ~= Pair("TAU", 2*PI);
    ret ~= Pair("PI", PI);
    ret ~= Pair("E", E);
    ret ~= Pair("SQRT2", SQRT2);
    ret ~= Pair("LN2", LN2);
    ret ~= Pair("LN10", LN10);
    ret ~= Pair("inf", double.infinity);
    ret ~= Pair("nan", double.nan);
    ret ~= lib2inspect;
    ret ~= lib2mod;
    ret ~= lib2cmp;
    ret ~= lib2pow;
    ret ~= lib2round;
    ret ~= lib2rand;
    ret ~= lib2trig;
    return ret;
}

Pair[] lib2inspect()
{
    Pair[] ret;
    ret ~= FunctionPair!libisfinite("finite?");
    ret ~= FunctionPair!libisinf("inf?");
    ret ~= FunctionPair!libisnan("nan?");
    ret ~= FunctionPair!libisnormal("normal?");
    ret ~= FunctionPair!libissubnormal("subnormal?");
    ret ~= FunctionPair!libsignbit("sign_bit");
    ret ~= FunctionPair!libispow2("pow2?");
    return ret;
}

Pair[] lib2rand()
{
    rnd = MinstdRand0(unpredictableSeed);
    Pair[] ret = [];
    ret ~= FunctionPair!libseed("seed");
    ret ~= FunctionPair!librandom("random");
    return ret;
}

Pair[] lib2trig()
{
    Pair[] ret;
    ret ~= FunctionPair!libsin("sin");
    ret ~= FunctionPair!libcos("cos");
    ret ~= FunctionPair!libtan("tan");
    ret ~= FunctionPair!libasin("asin");
    ret ~= FunctionPair!libacos("acos");
    ret ~= FunctionPair!libatan("atan");
    ret ~= FunctionPair!libatan2("atan2");
    ret ~= FunctionPair!libsinh("sinh");
    ret ~= FunctionPair!libcosh("cosh");
    ret ~= FunctionPair!libtanh("tanh");
    ret ~= FunctionPair!libasinh("asinh");
    ret ~= FunctionPair!libacosh("acosh");
    ret ~= FunctionPair!libatanh("atanh");
    return ret;
}

Pair[] lib2round()
{
    Pair[] ret;
    ret ~= FunctionPair!libceil("ceil");
    ret ~= FunctionPair!libfloor("floor");
    ret ~= FunctionPair!libround("round");
    ret ~= FunctionPair!liblround("lround");
    ret ~= FunctionPair!libtrunc("trunc");
    ret ~= FunctionPair!librint("rint");
    ret ~= FunctionPair!liblrint("lrint");
    ret ~= FunctionPair!libnearbyint("nearbyint");
    ret ~= FunctionPair!librndtol("rndtol");
    ret ~= FunctionPair!libquantize("quantize");
    return ret;
}

Pair[] lib2pow()
{
    Pair[] ret;
    ret ~= FunctionPair!libpow("pow");
    ret ~= FunctionPair!libexp("exp");
    ret ~= FunctionPair!libexp2("exp2");
    ret ~= FunctionPair!libexpm1("expm2");
    ret ~= FunctionPair!libldexp("ldexp");
    ret ~= FunctionPair!libfrexp("frexp");
    ret ~= FunctionPair!liblog("log");
    ret ~= FunctionPair!liblog2("log2");
    ret ~= FunctionPair!liblog10("log10");
    ret ~= FunctionPair!liblogb("logb");
    ret ~= FunctionPair!libilogb("ilogb");
    ret ~= FunctionPair!liblog1p("log1p");
    ret ~= FunctionPair!libscalbn("scalbn");
    return ret;
}

Pair[] lib2mod()
{
    Pair[] ret;
    ret ~= FunctionPair!libfmod("fmod");
    ret ~= FunctionPair!libremainder("remainder");
    return ret;
}

Pair[] lib2cmp()
{
    Pair[] ret;
    ret ~= FunctionPair!libcmp("cmp");
    ret ~= FunctionPair!libisidentical("identical?");
    ret ~= FunctionPair!libapprox("eq?");
    ret ~= FunctionPair!liblte("lte?");
    ret ~= FunctionPair!libgte("gte?");
    return ret;
}

private:
// ieee
Dynamic libflagget(Args args)
{
    FloatingPointControl fpctrl;
    return fpctrl.enabledExceptions.to!uint.dynamic;
}

Dynamic libflagset(Args args)
{
    FloatingPointControl fpctrl;
    FloatingPointControl.ExceptionMask em = args[0].as!uint.to!(FloatingPointControl.ExceptionMask);
    fpctrl.disableExceptions(FloatingPointControl.allExceptions);
    fpctrl.enableExceptions(em);
    return Dynamic.nil;
}

Dynamic libaserr(Args args)
{
    FloatingPointControl fpctrl;
    fpctrl.enableExceptions(args[0].as!size_t
            .to!(FloatingPointControl.ExceptionMask));
    return Dynamic.nil;
}

Dynamic libasnan(Args args)
{
    FloatingPointControl fpctrl;
    fpctrl.disableExceptions(args[0].as!size_t
            .to!(FloatingPointControl.ExceptionMask));
    return Dynamic.nil;
}

// inspect
Dynamic libisfinite(Args args)
{
    return args[0].as!double.isFinite.dynamic;
}

Dynamic libisinf(Args args)
{
    return args[0].as!double.isInfinity.dynamic;
}

Dynamic libisnan(Args args)
{
    return args[0].as!double.isNaN.dynamic;
}

Dynamic libisnormal(Args args)
{
    return args[0].as!double.isNormal.dynamic;
}

Dynamic libissubnormal(Args args)
{
    return args[0].as!double.isSubnormal.dynamic;
}

Dynamic libsignbit(Args args)
{
    return args[0].as!double.signbit.dynamic;
}

Dynamic libispow2(Args args)
{
    return args[0].as!double.isPowerOf2.dynamic;
}

// cmp
Dynamic libisidentical(Args args)
{
    return args[0].as!double.isIdentical(args[1].as!double).dynamic;
}

Dynamic libapprox(Args args)
{
    double rel = 0.01;
    double abs = 0.00001;
    if (args.length >= 3)
    {
        if (args[2].isNil)
        {
            rel = args[2].as!double;
        }
    }
    if (args.length >= 4)
    {
        if (args[3].isNil)
        {
            abs = args[3].as!double;
        }
    }
    double v1 = args[0].as!double;
    double v2 = args[1].as!double;
    return isClose(v1, v2, rel, abs).dynamic;
}

Dynamic libcmp(Args args)
{
    double rel = 0.01;
    double abs = 0.00001;
    if (args.length >= 3)
    {
        if (args[2].isNil)
        {
            rel = args[2].as!double;
        }
    }
    if (args.length >= 4)
    {
        if (args[3].isNil)
        {
            abs = args[3].as!double;
        }
    }
    double v1 = args[0].as!double;
    double v2 = args[1].as!double;
    bool same = isClose(v1, v2, rel, abs);
    if (same)
    {
        return dynamic(0);
    }
    if (v1 < v2)
    {
        return dynamic(-1);
    }
    return dynamic(1);
}

Dynamic liblte(Args args)
{
    double rel = 0.01;
    double abs = 0.00001;
    if (args.length >= 3)
    {
        if (args[2].isNil)
        {
            rel = args[2].as!double;
        }
    }
    if (args.length >= 4)
    {
        if (args[3].isNil)
        {
            abs = args[3].as!double;
        }
    }
    double v1 = args[0].as!double;
    double v2 = args[1].as!double;
    bool same = isClose(v1, v2, rel, abs);
    if (same || v1 < v2)
    {
        return true.dynamic;
    }
    return false.dynamic;
}

Dynamic libgte(Args args)
{
    double rel = 0.01;
    double abs = 0.00001;
    if (args.length >= 3)
    {
        if (args[2].isNil)
        {
            rel = args[2].as!double;
        }
    }
    if (args.length >= 4)
    {
        if (args[3].isNil)
        {
            abs = args[3].as!double;
        }
    }
    double v1 = args[0].as!double;
    double v2 = args[1].as!double;
    bool same = isClose(v1, v2, rel, abs);
    if (same || v1 > v2)
    {
        return true.dynamic;
    }
    return false.dynamic;
}

// mod
Dynamic libfmod(Args args)
{
    return args[0].as!double.fmod(args[1].as!double).dynamic;
}

Dynamic libremainder(Args args)
{
    return args[0].as!double.remainder(args[1].as!double).dynamic;
}

// pow
Dynamic libpow(Args args)
{
    return args[0].as!double.pow(args[1].as!double).dynamic;
}

Dynamic libexp(Args args)
{
    return args[0].as!double.exp.dynamic;
}

Dynamic libexp2(Args args)
{
    return args[0].as!double.exp2.dynamic;
}

Dynamic libexpm1(Args args)
{
    return args[0].as!double.expm1.dynamic;
}

Dynamic libldexp(Args args)
{
    return args[0].as!double.ldexp(args[1].as!int).dynamic;
}

Dynamic libfrexp(Args args)
{
    int iret;
    Dynamic a0 = args[0].as!double.frexp(iret).dynamic;
    Dynamic a1 = iret.dynamic;
    return [a0, a1].dynamic;
}

Dynamic liblog(Args args)
{
    return args[0].as!double.log.dynamic;
}

Dynamic liblog2(Args args)
{
    return args[0].as!double.log2.dynamic;
}

Dynamic liblog10(Args args)
{
    return args[0].as!double.log10.dynamic;
}

Dynamic liblogb(Args args)
{
    return args[0].as!double.logb.dynamic;
}

Dynamic libilogb(Args args)
{
    return args[0].as!double.ilogb.dynamic;
}

Dynamic liblog1p(Args args)
{
    return args[0].as!double.log1p.dynamic;
}

Dynamic libscalbn(Args args)
{
    return args[0].as!double.scalbn(args[1].as!int).dynamic;
}

// round
Dynamic libceil(Args args)
{
    return args[0].as!double.ceil.dynamic;
}

Dynamic libfloor(Args args)
{
    return args[0].as!double.floor.dynamic;
}

Dynamic libround(Args args)
{
    return args[0].as!double.round.dynamic;
}

Dynamic liblround(Args args)
{
    return args[0].as!double.lround.dynamic;
}

Dynamic libtrunc(Args args)
{
    return args[0].as!double.trunc.dynamic;
}

Dynamic librint(Args args)
{
    return args[0].as!double.rint.dynamic;
}

Dynamic liblrint(Args args)
{
    return args[0].as!double.lrint.dynamic;
}

Dynamic libnearbyint(Args args)
{
    return args[0].as!double.nearbyint.dynamic;
}

Dynamic librndtol(Args args)
{
    return args[0].as!double.rndtol.dynamic;
}

Dynamic libquantize(Args args)
{
    return args[0].as!double.quantize(args[1].as!double).dynamic;
}

// trig
Dynamic libsin(Args args)
{
    return args[0].as!double.sin.dynamic;
}

Dynamic libcos(Args args)
{
    return args[0].as!double.cos.dynamic;
}

Dynamic libtan(Args args)
{
    return args[0].as!double.tan.dynamic;
}

Dynamic libsinh(Args args)
{
    return args[0].as!double.sinh.dynamic;
}

Dynamic libcosh(Args args)
{
    return args[0].as!double.cosh.dynamic;
}

Dynamic libtanh(Args args)
{
    return args[0].as!double.tanh.dynamic;
}

Dynamic libasin(Args args)
{
    return args[0].as!double.asin.dynamic;
}

Dynamic libacos(Args args)
{
    return args[0].as!double.acos.dynamic;
}

Dynamic libatan(Args args)
{
    return args[0].as!double.atan.dynamic;
}

Dynamic libatan2(Args args)
{
    return atan2(args[0].as!double, args[1].as!double).dynamic;
}

Dynamic libasinh(Args args)
{
    return args[0].as!double.asinh.dynamic;
}

Dynamic libacosh(Args args)
{
    return args[0].as!double.acosh.dynamic;
}

Dynamic libatanh(Args args)
{
    return args[0].as!double.atanh.dynamic;
}

Dynamic libsqrt(Args args)
{
    return args[0].as!double.sqrt.dynamic;
}

// classic
Dynamic libcbrt(Args args)
{
    return args[0].as!double.sqrt.dynamic;
}

Dynamic libmin(Args args)
{
    double ret = double.infinity;
    foreach (arg; args)
    {
        double cur = arg.as!double;
        if (cur < ret)
        {
            ret = cur;
        }
    }
    return ret.dynamic;
}

Dynamic libmax(Args args)
{
    double ret = -double.infinity;
    foreach (arg; args)
    {
        double cur = arg.as!double;
        if (cur > ret)
        {
            ret = cur;
        }
    }
    return ret.dynamic;
}

Dynamic libabs(Args args)
{
    return args[0].as!double.fabs.dynamic;
}

// random
Dynamic libseed(Args args)
{
    rnd = MinstdRand0(cast(uint) args[0].as!size_t);
    return Dynamic.nil;
}

Dynamic librandom(Args args)
{
    if (args.length == 0)
    {
        return uniform(0, 1).dynamic;
    }
    if (args.length == 1)
    {
        return uniform(0, args[0].as!double, rnd).dynamic;
    }
    if (args.length == 2)
    {
        return uniform(args[0].as!double, args[1].as!double, rnd).dynamic;
    }
    throw new Exception("too many arguments");
}
