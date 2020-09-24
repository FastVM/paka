module lang.number;

import std.meta;
import std.traits;
import std.string;
import std.stdio;
import std.conv;
        import core.memory;
import mpfrd;
import deimos.mpfr;

// version = big_number;

version (big)
{
    struct Number
    {
        mpfr_t mpfr = void;
        alias mpfr this;

        @disable this();

        pragma(inline, true) this(this)
        {
            mpfr_t new_mpfr;
            mpfr_init2(new_mpfr, mpfr_get_prec(mpfr));
            mpfr_set(new_mpfr, mpfr, mpfr_rnd_t.MPFR_RNDN);
            mpfr = new_mpfr;
        }

        pragma(inline, true) static Number empty(mpfr_prec_t p = 32)
        {
            Number ret = void;
            mpfr_init2(ret.mpfr, p);
            return ret;
        }

        pragma(inline, true) this(T)(const T value, mpfr_prec_t p = 32)
                if (isNumericValue!T)
        {
            mpfr_init2(mpfr, p);
            this = value;
        }

        pragma(inline, true) this(const string value)
        {
            mpfr_init_set_str(mpfr, value.toStringz, 10, mpfr_rnd_t.MPFR_RNDN);
        }

        pragma(inline, true) ~this()
        {
            mpfr_clear(mpfr);
        }

        private static template isNumericValue(T)
        {
            enum isNumericValue = std.traits.isNumeric!T || is(T == Number);
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
            else static if (is(T == Number))
            {
                return "";
            }
            else
            {
                static assert(false, "Unhandled type " ~ T.stringof);
            }
        }

        ////////////////////////////////////////////////////////////////////////////
        // properties
        ////////////////////////////////////////////////////////////////////////////

        pragma(inline, true) @property void precision(mpfr_prec_t p)
        {
            mpfr_set_prec(mpfr, p);
        }

        pragma(inline, true) @property mpfr_prec_t precision() const
        {
            return mpfr_get_prec(mpfr);
        }

        ////////////////////////////////////////////////////////////////////////////
        // Comparisons
        ////////////////////////////////////////////////////////////////////////////

        pragma(inline, true) int opCmp(T)(const T value) const 
                if (isNumericValue!T)
        {
            mixin("return mpfr_cmp" ~ getTypeString!T() ~ "(mpfr, value);");
        }

        pragma(inline, true) int opCmp(ref const Number value)
        {
            return mpfr_cmp(mpfr, value);
        }

        pragma(inline, true) bool opEquals(T)(const T value) const 
                if (isNumericValue!T)
        {
            return opCmp(value) == 0;
        }

        pragma(inline, true) bool opEquals(ref const Number value)
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

        ////////////////////////////////////////////////////////////////////////////
        // Arithmetic
        ////////////////////////////////////////////////////////////////////////////

        pragma(inline, true) Number opBinary(string op)(Number value) if (op == "%")
        {
            Number output = Number.empty;
            mpfr_fmod(output.mpfr, mpfr, value.mpfr, mpfr_rnd_t.MPFR_RNDN);
            return output;
        }

        pragma(inline, true) Number opBinary(string op, T)(const T value)
                if (isNumericValue!T && op == "%")
        {
            return this % Number(value);
        }

        pragma(inline, true) Number opBinary(string op, T)(const T value) const 
                if (isNumericValue!T && op != "%")
        {
            Number output = Number.empty;
            mixin(getFunction!(op, T, false)() ~ "(output, mpfr, value, mpfr_rnd_t.MPFR_RNDN);");
            return output;
        }

        pragma(inline, true) Number opBinaryRight(string op, T)(const T value) const
                if (isNumericValue!T && op != "%")
        {
            static if (op == "-" || op == "/" || op == "<<" || op == ">>")
            {
                Number output = Number.empty;
                mixin(getFunction!(op, T, true)() ~ "(output, value, mpfr, mpfr_rnd_t.MPFR_RNDN);");
                return output;
            }
            else
            {
                return opBinary!op(value);
            }
        }

        pragma(inline, true) Number opUnary(string op)() const if (op == "-")
        {
            Number output = Number.empty;
            mpfr_neg(output, mpfr, mpfr_rnd_t.MPFR_RNDN);
            return output;
        }

        pragma(inline, true) Number opUnary(string op)() if (op == "++")
        {
            mpfr_nextabove(this.mpfr);
            return this;
        }

        pragma(inline, true) Number opUnary(string op)() if (op == "--")
        {
            mpfr_nextbelow(this.mpfr);
            return this;
        }

        ////////////////////////////////////////////////////////////////////////////
        // Mutation
        ////////////////////////////////////////////////////////////////////////////

        pragma(inline, true) ref Number opAssign(T)(const T value)
                if (isNumericValue!T)
        {
            mixin("mpfr_set" ~ getTypeString!T() ~ "(mpfr, value, mpfr_rnd_t.MPFR_RNDN);");
            return this;
        }

        pragma(inline, true) ref Number opAssign(ref const Number value)
        {
            mpfr_set(mpfr, value, mpfr_rnd_t.MPFR_RNDN);
            return this;
        }

        pragma(inline, true) ref Number opOpAssign(string op, T)(const T value)
                if (isNumericValue!T && op != "%")
        {
            static assert(!(op == "^^" && isFloatingPoint!T),
                    "No operator ^^= with floating point.");
            mixin(getFunction!(op, T, false)() ~ "(mpfr, mpfr, value, mpfr_rnd_t.MPFR_RNDN);");
            return this;
        }

        pragma(inline, true) ref Number opOpAssign(string op)(ref const Number value)
                if (op != "%")
        {
            if (value !is this)
            {
                mixin(getFunction!(op, T, false)() ~ "(mpfr, mpfr, value, mpfr_rnd_t.MPFR_RNDN);");
            }
            return this;
        }

        ////////////////////////////////////////////////////////////////////////////
        // String
        ////////////////////////////////////////////////////////////////////////////

        pragma(inline, true) string toString() const
        {
            char[1024] buffer;
            const count = mpfr_snprintf(buffer.ptr, buffer.sizeof, "%Rg".ptr, &mpfr);
            return buffer[0 .. count].idup;
        }
    }

    pragma(inline, true) Number as(T, A)(A s) if (is(T == Number))
    {
        return Number(s);
    }

    pragma(inline, true) T as(T)(Number n) if (std.traits.isNumeric!T)
    {
        return cast(T) mpfr_get_ui(n.mpfr, mpfr_rnd_t.MPFR_RNDN);
    }
}
else
{
    alias Number = double;
    Number as(T, A)(A s) if (is(T == Number) && !is(A == string))
    {
        return Number(s);
    }

    Number as(T, A)(A s) if (is(T == Number) && is(A == string))
    {
        return s.to!Number;
    }

    T as(T)(Number n) if (std.traits.isNumeric!T)
    {
        return cast(T) n;
    }
}
