module lang.number;

import std.meta;
import std.traits;
import std.string;
import std.stdio;
import std.conv;
import core.memory;
import lang.data.mpfr;
import std.experimental.checkedint;

private BigNumber maxSmall = void;
private BigNumber minSmall = void;

extern (C) extern __gshared void* function(size_t s) __gmp_allocate_func;
extern (C) extern __gshared void* function(void* p, size_t s, size_t o) __gmp_reallocate_func;
extern (C) extern __gshared void function(void* p, size_t o) __gmp_free_func;

static this()
{
    __gmp_allocate_func = function(size_t s) { return GC.malloc(s); };
    __gmp_reallocate_func = function(void* p, size_t s, size_t o) {
        return GC.realloc(p, s);
    };
    __gmp_free_func = function(void* p, size_t o) {};
    maxSmall = int.max.asBig;
    minSmall = int.min.asBig;
}

alias SmallNumber = double;
alias BigNumber = const(MpfrBigNumber);

pragma(inline, true) BigNumber asBig(T...)(T v)
{
    return BigNumber(v);
}

bool fits(SmallNumber num)
{
    return int.min <= num && num <= uint.max;
}

struct MpfrBigNumber
{
    mpfr_t mpfr = void;
    alias mpfr this;

    @disable this();

    pragma(inline, true) bool fits() const
    {
        return minSmall <= this && this <= maxSmall;
    }

    pragma(inline, true) this(const(MpfrBigNumber) other)
    {
        mpfr_init2(mpfr, mpfr_get_prec(other.mpfr));
        mpfr_set(mpfr, other.mpfr, mpfr_rnd_t.MPFR_RNDN);
    }

    pragma(inline, true) this(SmallNumber other)
    {
        mpfr_init2(mpfr, 256);
        mpfr_set_d(mpfr, other, mpfr_rnd_t.MPFR_RNDN);
    }

    pragma(inline, true) static MpfrBigNumber empty()
    {
        MpfrBigNumber ret = void;
        mpfr_init2(ret.mpfr, 256);
        return ret;
    }

    pragma(inline, true) this(const string value)
    {
        mpfr_init_set_str(mpfr, value.toStringz, 10, mpfr_rnd_t.MPFR_RNDN);
    }

    pragma(inline, true) ~this()
    {
        destroy!false(mpfr);
    }

    private static template isNumericValue(T)
    {
        enum isNumericValue = std.traits.isNumeric!T || is(T == MpfrBigNumber);
    }

    private static string getTypeString(T)()
    {
        static if (isIntegral!T && isSigned!T)
        {
            return "_si";
        }
        else static if (isIntegral!T && !isSigned!T)
        {
            return "_ui";
        }
        else static if (is(T : double))
        {
            return "_d";
        }
        else static if (is(T == MpfrBigNumber))
        {
            return "";
        }
        else
        {
            static assert(false, "Unhandled type " ~ T.stringof);
        }
    }

    pragma(inline, true) @property void precision(mpfr_prec_t p)
    {
        mpfr_set_prec(mpfr, p);
    }

    pragma(inline, true) @property mpfr_prec_t precision() const
    {
        return mpfr_get_prec(mpfr);
    }


    pragma(inline, true) int opCmp(T)(const T value) const if (isNumericValue!T)
    {
        mixin("return mpfr_cmp" ~ getTypeString!T() ~ "(mpfr, value);");
    }

    pragma(inline, true) int opCmp(ref const(MpfrBigNumber) value)
    {
        return mpfr_cmp(mpfr, value);
    }

    pragma(inline, true) bool opEquals(T)(const T value) const 
            if (isNumericValue!T)
    {
        return opCmp(value) == 0;
    }

    pragma(inline, true) bool opEquals(ref const(MpfrBigNumber) value)
    {
        return this is value || opCmp(value) == 0;
    }

    private static string getOperatorString(string op)()
    {
        switch (op)
        {
        default:
            assert(0);
        case "+":
            return "_add";
        case "-":
            return "_sub";
        case "*":
            return "_mul";
        case "/":
            return "_div";
        case "^^":
            return "_pow";
        }
    }

    private static string getShiftOperatorString(string op)()
    {
        final switch (op)
        {
        case "<<":
            return "_mul";
        case ">>":
            return "_div";
        }
    }

    private static string getShiftTypeString(T)()
    {
        static if (isIntegral!T && isSigned!T)
        {
            return "_2si";
        }
        else static if (isIntegral!T && !isSigned!T)
        {
            return "_2ui";
        }
        else
        {
            static assert(false, "Unhandled type " ~ T.stringof);
        }
    }

    private static string getFunctionSuffix(string op, T, bool isRight)()
    {
        static if (op == "<<" || op == ">>")
        {
            static assert(!isRight,
                    "Binary Right Shift not allowed, try using lower level mpfr_ui_pow.");
            return getShiftOperatorString!op() ~ getShiftTypeString!T();
        }
        else
        {
            return isRight ? getTypeString!T() ~ getOperatorString!op() : getOperatorString!op() ~ getTypeString!T();
        }
    }

    private static string getFunction(string op, T, bool isRight)()
    {
        return "mpfr" ~ getFunctionSuffix!(op, T, isRight);
    }

    pragma(inline, true) MpfrBigNumber opBinary(string op)(const(MpfrBigNumber) value)
            if (op == "%")
    {
        MpfrBigNumber output = MpfrBigNumber.empty;
        mpfr_fmod(output.mpfr, mpfr, value.mpfr, mpfr_rnd_t.MPFR_RNDN);
        return output;
    }

    pragma(inline, true) MpfrBigNumber opBinary(string op)(SmallNumber value)
    {
        return mixin("this" ~ op ~ "value.asBig");
    }

    pragma(inline, true) MpfrBigNumber opBinaryRight(string op)(SmallNumber value)
    {
        return mixin("value.asBig" ~ op ~ "this");
    }

    pragma(inline, true) MpfrBigNumber opBinary(string op, T)(const T value)
            if (isNumericValue!T && op == "%")
    {
        return this % value.asBig;
    }

    pragma(inline, true) MpfrBigNumber opBinary(string op, T)(const T value) const
            if (isNumericValue!T && op != "%")
    {
        MpfrBigNumber output = MpfrBigNumber.empty;
        mixin(getFunction!(op, T, false)() ~ "(output, mpfr, value, mpfr_rnd_t.MPFR_RNDN);");
        return output;
    }

    pragma(inline, true) MpfrBigNumber opBinaryRight(string op, T)(const T value) const
            if (isNumericValue!T && op != "%")
    {
        static if (op == "-" || op == "/" || op == "<<" || op == ">>")
        {
            MpfrBigNumber output = MpfrBigNumber.empty;
            mixin(getFunction!(op, T, true)() ~ "(output, value, mpfr, mpfr_rnd_t.MPFR_RNDN);");
            return output;
        }
        else
        {
            return opBinary!op(value);
        }
    }

    pragma(inline, true) MpfrBigNumber opUnary(string op)() const if (op == "-")
    {
        MpfrBigNumber output = MpfrBigNumber.empty;
        mpfr_neg(output, mpfr, mpfr_rnd_t.MPFR_RNDN);
        return output;
    }

    pragma(inline, true) MpfrBigNumber opUnary(string op)() if (op == "++")
    {
        mpfr_nextabove(this.mpfr);
        return this;
    }

    pragma(inline, true) MpfrBigNumber opUnary(string op)() if (op == "--")
    {
        mpfr_nextbelow(this.mpfr);
        return this;
    }

    pragma(inline, true) string toString() const
    {
        char[1024] buffer;
        const count = mpfr_snprintf(buffer.ptr, buffer.sizeof, "%Rg".ptr, &mpfr);
        return buffer[0 .. count].idup;
    }
}