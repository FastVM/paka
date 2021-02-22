/// A D API for libgccjit, purely as final class wrapper functions.
/// Copyright (C) 2014-2015 Iain Buclaw.

/// This file is part of gccjitd.

/// This program is free software: you can redistribute it and/or modify
/// it under the terms of the GNU General Public License as published by
/// the Free Software Foundation, either version 3 of the License, or
/// (at your option) any later version.

/// This program is distributed in the hope that it will be useful,
/// but WITHOUT ANY WARRANTY; without even the implied warranty of
/// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
/// GNU General Public License for more details.

/// You should have received a copy of the GNU General Public License
/// along with this program.  If not, see <http://www.gnu.org/licenses/>.

module purr.jit.wrapper;

public import purr.jit.native;

import std.conv : to;
import std.string : toStringz;
import std.traits : isIntegral, isSigned;

/// Errors within the API become D exceptions of this class.
final class JITError : Exception
{
    @safe pure nothrow this(string msg, Throwable next = null)
    {
        super(msg, next);
    }

    @safe pure nothrow this(string msg, string file, size_t line, Throwable next = null)
    {
        super(msg, file, line, next);
    }
}

/// Class wrapper for gcc_jit_object.
/// All JITObject's are created within a JITContext, and are automatically
/// cleaned up when the context is released.

/// The class hierachy looks like this:
///  $(OL - JITObject
///      $(OL - JITLocation)
///      $(OL - JITType
///         $(OL - JITStruct))
///      $(OL - JITField)
///      $(OL - JITFunction)
///      $(OL - JITBlock)
///      $(OL - JITRValue
///          $(OL - JITLValue
///              $(OL - JITParam))))
class JITObject
{
    /// Return the context this JITObject is within.
    final JITContext getContext()
    {
        auto result = gcc_jit_object_get_context(this.m_inner_obj);
        return new JITContext(result);
    }

    /// Get a human-readable description of this object.
    override final string toString()
    {
        auto result = gcc_jit_object_get_debug_string(this.m_inner_obj);
        return to!string(result);
    }

protected:
    // Constructors and getObject are hidden from public.
    this()
    {
        this.m_inner_obj = null;
    }

    this(gcc_jit_object* obj)
    {
        if (!obj)
            throw new JITError("Unknown error, got bad object");
        this.m_inner_obj = obj;
    }

    final gcc_jit_object* getObject()
    {
        return this.m_inner_obj;
    }

private:
    // The actual gccjit object we interface with.
    gcc_jit_object* m_inner_obj;
}

/// Class wrapper for gcc_jit_location.
/// A JITLocation encapsulates a source code locations, so that you can associate
/// locations in your language with statements in the JIT-compiled code.
class JITLocation : JITObject
{
    ///
    this()
    {
        super();
    }

    ///
    this(gcc_jit_location* loc)
    {
        super(gcc_jit_location_as_object(loc));
    }

    /// Returns the internal gcc_jit_location object.
    final gcc_jit_location* getLocation()
    {
        // Manual downcast.
        return cast(gcc_jit_location*)(this.getObject());
    }
}

/// The top-level of the API is the JITContext class.

/// A JITContext instance encapsulates the state of a compilation.
/// It goes through two states.
/// Initial:
///     During which you can set up options on it, and add types,
///     functions and code, using the API below. Invoking compile
///     on it transitions it to the PostCompilation state.
/// PostCompilation:
///     When you can call JITContext.release to clean it up.
final class JITContext
{
    ///
    this(bool acquire = true)
    {
        if (acquire)
            this.m_inner_ctxt = gcc_jit_context_acquire();
        else
            this.m_inner_ctxt = null;
    }

    ///
    this(gcc_jit_context* context)
    {
        if (!context)
            throw new JITError("Unknown error, got bad context");
        this.m_inner_ctxt = context;
    }

    /// Acquire a JIT-compilation context.
    static JITContext acquire()
    {
        return new JITContext(gcc_jit_context_acquire());
    }

    /// Release the context.
    /// After this call, it's no longer valid to use this JITContext.
    void release()
    {
        gcc_jit_context_release(this.m_inner_ctxt);
        this.m_inner_ctxt = null;
    }

    /// Set a string option of the context; see JITStrOption for notes
    /// on the options and their meanings.
    /// Params:
    ///     opt   = Which option to set.
    ///     value = The new value.
    void setOption(JITStrOption opt, string value)
    {
        gcc_jit_context_set_str_option(this.m_inner_ctxt, opt, value.toStringz());
    }

    /// Set an integer option of the context; see JITIntOption for notes
    /// on the options and their meanings.
    /// Params:
    ///     opt   = Which option to set.
    ///     value = The new value.
    void setOption(JITIntOption opt, int value)
    {
        gcc_jit_context_set_int_option(this.m_inner_ctxt, opt, value);
    }

    /// Set a boolean option of the context; see JITBoolOption for notes
    /// on the options and their meanings.
    /// Params:
    ///     opt   = Which option to set.
    ///     value = The new value.
    void setOption(JITBoolOption opt, bool value)
    {
        gcc_jit_context_set_bool_option(this.m_inner_ctxt, opt, value);
    }

    /// Calls into GCC and runs the build.  It can only be called once on a
    /// given context.
    /// Returns:
    ///     A wrapper around a .so file.
    JITResult compile()
    {
        auto result = gcc_jit_context_compile(this.m_inner_ctxt);
        if (!result)
            throw new JITError(this.getFirstError());
        return new JITResult(result);
    }

    /// Returns:
    ///     The first error message that occurred when compiling the context.
    string getFirstError()
    {
        const char* err = gcc_jit_context_get_first_error(this.m_inner_ctxt);
        if (err)
            return to!string(err);
        return null;
    }

    /// Dump a C-like representation describing what's been set up on the
    /// context to file.
    /// Params:
    ///     path             = Location of file to write to.
    ///     update_locations = If true, then also write JITLocation information.
    void dump(string path, bool update_locations)
    {
        gcc_jit_context_dump_to_file(this.m_inner_ctxt, path.toStringz(), update_locations);
    }

    /// Returns the internal gcc_jit_context object.
    gcc_jit_context* getContext()
    {
        return this.m_inner_ctxt;
    }

    /// Build a JITType from one of the types in JITTypeKind.
    JITType getType(JITTypeKind kind)
    {
        auto result = gcc_jit_context_get_type(this.m_inner_ctxt, kind);
        return new JITType(result);
    }

    /// Build an integer type of a given size and signedness.
    JITType getIntType(int num_bytes, bool is_signed)
    {
        auto result = gcc_jit_context_get_int_type(this.m_inner_ctxt, num_bytes, is_signed);
        return new JITType(result);
    }

    /// A way to map a specific int type, using the compiler to
    /// get the details automatically e.g:
    ///     JITType type = getIntType!size_t();
    JITType getIntType(T)() if (isIntegral!T)
    {
        return this.getIntType(T.sizeof, isSigned!T);
    }

    /// Create a reference to a GCC builtin function.
    JITFunction getBuiltinFunction(string name)
    {
        auto result = gcc_jit_context_get_builtin_function(this.m_inner_ctxt, name.toStringz());
        return new JITFunction(result);
    }

    /// Create a new child context of the given JITContext, inheriting a copy
    /// of all option settings from the parent.
    /// The returned JITContext can reference objects created within the
    /// parent, but not vice-versa.  The lifetime of the child context must be
    /// bounded by that of the parent. You should release a child context
    /// before releasing the parent context.
    JITContext newChildContext()
    {
        auto result = gcc_jit_context_new_child_context(this.m_inner_ctxt);
        if (!result)
            throw new JITError("Unknown error creating child context");
        return new JITContext(result);
    }

    /// Make a JITLocation representing a source location,
    /// for use by the debugger.
    /// Note:
    ///     You need to enable JITBoolOption.DEBUGINFO on the context
    ///     for these locations to actually be usable by the debugger.
    JITLocation newLocation(string filename, int line, int column)
    {
        auto result = gcc_jit_context_new_location(this.m_inner_ctxt,
                filename.toStringz(), line, column);
        return new JITLocation(result);
    }

    /// Given type "T", build a new array type of "T[N]".
    JITType newArrayType(JITLocation loc, JITType type, int dims)
    {
        auto result = gcc_jit_context_new_array_type(this.m_inner_ctxt, loc
                ? loc.getLocation() : null, type.getType(), dims);
        return new JITType(result);
    }

    /// Ditto
    JITType newArrayType(JITType type, int dims)
    {
        return this.newArrayType(null, type, dims);
    }

    /// Ditto
    JITType newArrayType(JITLocation loc, JITTypeKind kind, int dims)
    {
        return this.newArrayType(loc, this.getType(kind), dims);
    }

    /// Ditto
    JITType newArrayType(JITTypeKind kind, int dims)
    {
        return this.newArrayType(null, this.getType(kind), dims);
    }

    /// Create a field, for use within a struct or union.
    JITField newField(JITLocation loc, JITType type, string name)
    {
        auto result = gcc_jit_context_new_field(this.m_inner_ctxt, loc
                ? loc.getLocation() : null, type.getType(), name.toStringz());
        return new JITField(result);
    }

    /// Ditto
    JITField newField(JITType type, string name)
    {
        return this.newField(null, type, name);
    }

    /// Ditto
    JITField newField(JITLocation loc, JITTypeKind kind, string name)
    {
        return this.newField(loc, this.getType(kind), name);
    }

    /// Ditto
    JITField newField(JITTypeKind kind, string name)
    {
        return this.newField(null, this.getType(kind), name);
    }

    /// Create a struct type from an array of fields.
    JITStruct newStructType(JITLocation loc, string name, JITField[] fields...)
    {
        // Convert to an array of inner pointers.
        gcc_jit_field*[] field_p = new gcc_jit_field*[fields.length];
        foreach (i, field; fields)
            field_p[i] = field.getField();

        // Treat the array as being of the underlying pointers, relying on
        // the wrapper type being such a pointer internally.
        auto result = gcc_jit_context_new_struct_type(this.m_inner_ctxt, loc
                ? loc.getLocation() : null, name.toStringz(), cast(int) fields.length, field_p.ptr);
        return new JITStruct(result);
    }

    /// Ditto
    JITStruct newStructType(string name, JITField[] fields...)
    {
        return this.newStructType(null, name, fields);
    }

    /// Create an opaque struct type.
    JITStruct newOpaqueStructType(JITLocation loc, string name)
    {
        auto result = gcc_jit_context_new_opaque_struct(this.m_inner_ctxt, loc
                ? loc.getLocation() : null, name.toStringz());
        return new JITStruct(result);
    }

    /// Ditto
    JITStruct newOpaqueStructType(string name)
    {
        return this.newOpaqueStructType(null, name);
    }

    /// Create a union type from an array of fields.
    JITType newUnionType(JITLocation loc, string name, JITField[] fields...)
    {
        // Convert to an array of inner pointers.
        gcc_jit_field*[] field_p = new gcc_jit_field*[fields.length];
        foreach (i, field; fields)
            field_p[i] = field.getField();

        // Treat the array as being of the underlying pointers, relying on
        // the wrapper type being such a pointer internally.
        auto result = gcc_jit_context_new_union_type(this.m_inner_ctxt, loc
                ? loc.getLocation() : null, name.toStringz(), cast(int) fields.length, field_p.ptr);
        return new JITType(result);
    }

    /// Ditto
    JITType newUnionType(string name, JITField[] fields...)
    {
        return this.newUnionType(null, name, fields);
    }

    /// Create a function type.
    JITType newFunctionType(JITLocation loc, JITType return_type,
            bool is_variadic, JITType[] param_types...)
    {
        // Convert to an array of inner pointers.
        gcc_jit_type*[] type_p = new gcc_jit_type*[param_types.length];
        foreach (i, type; param_types)
            type_p[i] = type.getType();

        // Treat the array as being of the underlying pointers, relying on
        // the wrapper type being such a pointer internally.
        auto result = gcc_jit_context_new_function_ptr_type(this.m_inner_ctxt, loc
                ? loc.getLocation() : null, return_type.getType(),
                cast(int) param_types.length, type_p.ptr, is_variadic);
        return new JITType(result);
    }

    /// Ditto
    JITType newFunctionType(JITType return_type, bool is_variadic, JITType[] param_types...)
    {
        return this.newFunctionType(null, return_type, is_variadic, param_types);
    }

    /// Ditto
    JITType newFunctionType(JITLocation loc, JITTypeKind return_kind,
            bool is_variadic, JITType[] param_types...)
    {
        return this.newFunctionType(loc, this.getType(return_kind), is_variadic, param_types);
    }

    /// Ditto
    JITType newFunctionType(JITTypeKind return_kind, bool is_variadic, JITType[] param_types...)
    {
        return this.newFunctionType(null, this.getType(return_kind), is_variadic, param_types);
    }

    /// Create a function parameter.
    JITParam newParam(JITLocation loc, JITType type, string name)
    {
        auto result = gcc_jit_context_new_param(this.m_inner_ctxt, loc
                ? loc.getLocation() : null, type.getType(), name.toStringz());
        return new JITParam(result);
    }

    /// Ditto
    JITParam newParam(JITType type, string name)
    {
        return this.newParam(null, type, name);
    }

    /// Ditto
    JITParam newParam(JITLocation loc, JITTypeKind kind, string name)
    {
        return this.newParam(loc, this.getType(kind), name);
    }

    /// Ditto
    JITParam newParam(JITTypeKind kind, string name)
    {
        return this.newParam(null, this.getType(kind), name);
    }

    /// Create a function.
    JITFunction newFunction(JITLocation loc, JITFunctionKind kind,
            JITType return_type, string name, bool is_variadic, JITParam[] params...)
    {
        // Convert to an array of inner pointers.
        gcc_jit_param*[] param_p = new gcc_jit_param*[params.length];
        foreach (i, param; params)
            param_p[i] = param.getParam();

        // Treat the array as being of the underlying pointers, relying on
        // the wrapper type being such a pointer internally.
        auto result = gcc_jit_context_new_function(this.m_inner_ctxt, loc
                ? loc.getLocation() : null, kind, return_type.getType(),
                name.toStringz(), cast(int) params.length, param_p.ptr, is_variadic);
        return new JITFunction(result);
    }

    /// Ditto
    JITFunction newFunction(JITFunctionKind kind, JITType return_type,
            string name, bool is_variadic, JITParam[] params...)
    {
        return this.newFunction(null, kind, return_type, name, is_variadic, params);
    }

    /// Ditto
    JITFunction newFunction(JITLocation loc, JITFunctionKind kind,
            JITTypeKind return_kind, string name, bool is_variadic, JITParam[] params...)
    {
        return this.newFunction(loc, kind, this.getType(return_kind), name, is_variadic, params);
    }

    /// Ditto
    JITFunction newFunction(JITFunctionKind kind, JITTypeKind return_kind,
            string name, bool is_variadic, JITParam[] params...)
    {
        return this.newFunction(null, kind, this.getType(return_kind), name, is_variadic, params);
    }

    ///
    JITLValue newGlobal(JITLocation loc, JITGlobalKind global_kind, JITType type, string name)
    {
        auto result = gcc_jit_context_new_global(this.m_inner_ctxt, loc
                ? loc.getLocation() : null, global_kind, type.getType(), name.toStringz());
        return new JITLValue(result);
    }

    /// Ditto
    JITLValue newGlobal(JITGlobalKind global_kind, JITType type, string name)
    {
        return this.newGlobal(null, global_kind, type, name);
    }

    /// Ditto
    JITLValue newGlobal(JITLocation loc, JITGlobalKind global_kind, JITTypeKind kind, string name)
    {
        return this.newGlobal(loc, global_kind, this.getType(kind), name);
    }

    /// Ditto
    JITLValue newGlobal(JITGlobalKind global_kind, JITTypeKind kind, string name)
    {
        return this.newGlobal(null, global_kind, this.getType(kind), name);
    }

    /// Given a JITType, which must be a numeric type, get an integer constant
    /// as a JITRValue of that type.
    JITRValue newRValue(JITType type, int value)
    {
        auto result = gcc_jit_context_new_rvalue_from_int(this.m_inner_ctxt, type.getType(), value);
        return new JITRValue(result);
    }

    /// Ditto
    JITRValue newRValue(JITTypeKind kind, int value)
    {
        return newRValue(this.getType(kind), value);
    }

    /// Given a JITType, which must be a floating point type, get a floating
    /// point constant as a JITRValue of that type.
    JITRValue newRValue(JITType type, double value)
    {
        auto result = gcc_jit_context_new_rvalue_from_double(this.m_inner_ctxt,
                type.getType(), value);
        return new JITRValue(result);
    }

    /// Ditto
    JITRValue newRValue(JITTypeKind kind, double value)
    {
        return newRValue(this.getType(kind), value);
    }

    /// Given a JITType, which must be a pointer type, and an address, get a
    /// JITRValue representing that address as a pointer of that type.
    JITRValue newRValue(JITType type, void* value)
    {
        auto result = gcc_jit_context_new_rvalue_from_ptr(this.m_inner_ctxt, type.getType(), value);
        return new JITRValue(result);
    }

    /// Ditto
    JITRValue newRValue(JITTypeKind kind, void* value)
    {
        return newRValue(this.getType(kind), value);
    }

    /// Make a JITRValue for the given string literal value.
    /// Params:
    ///     value = The string literal.
    JITRValue newRValue(string value)
    {
        auto result = gcc_jit_context_new_string_literal(this.m_inner_ctxt, value.toStringz());
        return new JITRValue(result);
    }

    /// Given a JITType, which must be a numeric type, get the constant 0 as a
    /// JITRValue of that type.
    JITRValue zero(JITType type)
    {
        auto result = gcc_jit_context_zero(this.m_inner_ctxt, type.getType());
        return new JITRValue(result);
    }

    /// Ditto
    JITRValue zero(JITTypeKind kind)
    {
        return this.zero(this.getType(kind));
    }

    /// Given a JITType, which must be a numeric type, get the constant 1 as a
    /// JITRValue of that type.
    JITRValue one(JITType type)
    {
        auto result = gcc_jit_context_one(this.m_inner_ctxt, type.getType());
        return new JITRValue(result);
    }

    /// Ditto
    JITRValue one(JITTypeKind kind)
    {
        return this.one(this.getType(kind));
    }

    /// Given a JITType, which must be a pointer type, get a JITRValue
    /// representing the NULL pointer of that type.
    JITRValue nil(JITType type)
    {
        auto result = gcc_jit_context_null(this.m_inner_ctxt, type.getType());
        return new JITRValue(result);
    }

    /// Ditto
    JITRValue nil(JITTypeKind kind)
    {
        return this.nil(this.getType(kind));
    }

    /// Generic unary operations.

    /// Make a JITRValue for the given unary operation.
    /// Params:
    ///     loc  = The source location, if any.
    ///     op   = Which unary operation.
    ///     type = The type of the result.
    ///     a    = The input expression.
    JITRValue newUnaryOp(JITLocation loc, JITUnaryOp op, JITType type, JITRValue a)
    {
        auto result = gcc_jit_context_new_unary_op(this.m_inner_ctxt, loc
                ? loc.getLocation() : null, op, type.getType(), a.getRValue());
        return new JITRValue(result);
    }

    /// Ditto
    JITRValue newUnaryOp(JITUnaryOp op, JITType type, JITRValue a)
    {
        return this.newUnaryOp(null, op, type, a);
    }

    /// Generic binary operations.

    /// Make a JITRValue for the given binary operation.
    /// Params:
    ///     loc  = The source location, if any.
    ///     op   = Which binary operation.
    ///     type = The type of the result.
    ///     a    = The first input expression.
    ///     b    = The second input expression.
    JITRValue newBinaryOp(JITLocation loc, JITBinaryOp op, JITType type, JITRValue a, JITRValue b)
    {
        auto result = gcc_jit_context_new_binary_op(this.m_inner_ctxt, loc
                ? loc.getLocation() : null, op, type.getType(), a.getRValue(), b.getRValue());
        return new JITRValue(result);
    }

    /// Ditto
    JITRValue newBinaryOp(JITBinaryOp op, JITType type, JITRValue a, JITRValue b)
    {
        return this.newBinaryOp(null, op, type, a, b);
    }

    /// Generic comparisons.

    /// Make a JITRValue of boolean type for the given comparison.
    /// Params:
    ///     loc  = The source location, if any.
    ///     op   = Which comparison.
    ///     a    = The first input expression.
    ///     b    = The second input expression.
    JITRValue newComparison(JITLocation loc, JITComparison op, JITRValue a, JITRValue b)
    {
        auto result = gcc_jit_context_new_comparison(this.m_inner_ctxt, loc
                ? loc.getLocation() : null, op, a.getRValue(), b.getRValue());
        return new JITRValue(result);
    }

    /// Ditto
    JITRValue newComparison(JITComparison op, JITRValue a, JITRValue b)
    {
        return this.newComparison(null, op, a, b);
    }

    /// The most general way of creating a function call.
    JITRValue newCall(JITLocation loc, JITFunction func, JITRValue[] args...)
    {
        // Convert to an array of inner pointers.
        gcc_jit_rvalue*[] arg_p = new gcc_jit_rvalue*[args.length];
        foreach (i, arg; args)
            arg_p[i] = arg.getRValue();

        // Treat the array as being of the underlying pointers, relying on
        // the wrapper type being such a pointer internally.
        auto result = gcc_jit_context_new_call(this.m_inner_ctxt, loc
                ? loc.getLocation() : null, func.getFunction(), cast(int) args.length, arg_p.ptr);
        return new JITRValue(result);
    }

    /// Ditto
    JITRValue newCall(JITFunction func, JITRValue[] args...)
    {
        return this.newCall(null, func, args);
    }

    /// Calling a function through a pointer.
    JITRValue newCall(JITLocation loc, JITRValue ptr, JITRValue[] args...)
    {
        // Convert to an array of inner pointers.
        gcc_jit_rvalue*[] arg_p = new gcc_jit_rvalue*[args.length];
        foreach (i, arg; args)
            arg_p[i] = arg.getRValue();

        // Treat the array as being of the underlying pointers, relying on
        // the wrapper type being such a pointer internally.
        auto result = gcc_jit_context_new_call_through_ptr(this.m_inner_ctxt, loc
                ? loc.getLocation() : null, ptr.getRValue(), cast(int) args.length, arg_p.ptr);
        return new JITRValue(result);
    }

    /// Ditto
    JITRValue newCall(JITRValue ptr, JITRValue[] args...)
    {
        return this.newCall(null, ptr, args);
    }

    /// Type-coercion.
    /// Currently only a limited set of conversions are possible.
    /// int <=> float and int <=> bool.
    JITRValue newCast(JITLocation loc, JITRValue expr, JITType type)
    {
        auto result = gcc_jit_context_new_cast(this.m_inner_ctxt, loc
                ? loc.getLocation() : null, expr.getRValue(), type.getType());
        return new JITRValue(result);
    }

    /// Ditto
    JITRValue newCast(JITRValue expr, JITType type)
    {
        return this.newCast(null, expr, type);
    }

    /// Ditto
    JITRValue newCast(JITLocation loc, JITRValue expr, JITTypeKind kind)
    {
        return this.newCast(loc, expr, this.getType(kind));
    }

    /// Ditto
    JITRValue newCast(JITRValue expr, JITTypeKind kind)
    {
        return this.newCast(null, expr, this.getType(kind));
    }

    /// Accessing an array or pointer through an index.
    /// Params:
    ///     loc   = The source location, if any.
    ///     ptr   = The pointer or array.
    ///     index = The index within the array.
    JITLValue newArrayAccess(JITLocation loc, JITRValue ptr, JITRValue index)
    {
        auto result = gcc_jit_context_new_array_access(this.m_inner_ctxt, loc
                ? loc.getLocation() : null, ptr.getRValue(), index.getRValue());
        return new JITLValue(result);
    }

    /// Ditto
    JITLValue newArrayAccess(JITRValue ptr, JITRValue index)
    {
        return this.newArrayAccess(null, ptr, index);
    }

private:
    gcc_jit_context* m_inner_ctxt;
}

/// Class wrapper for gcc_jit_field
class JITField : JITObject
{
    ///
    this()
    {
        super();
    }

    ///
    this(gcc_jit_field* field)
    {
        super(gcc_jit_field_as_object(field));
    }

    /// Returns the internal gcc_jit_field object.
    final gcc_jit_field* getField()
    {
        // Manual downcast.
        return cast(gcc_jit_field*)(this.getObject());
    }
}

/// Types can be created in several ways:
/// $(UL
///     $(LI Fundamental types can be accessed using JITContext.getType())
///     $(LI Derived types can be accessed by calling methods on an existing type.)
///     $(LI By creating structures via JITStruct.)
/// )

class JITType : JITObject
{
    ///
    this()
    {
        super();
    }

    ///
    this(gcc_jit_type* type)
    {
        super(gcc_jit_type_as_object(type));
    }

    /// Returns the internal gcc_jit_type object.
    final gcc_jit_type* getType()
    {
        // Manual downcast.
        return cast(gcc_jit_type*)(this.getObject());
    }

    /// Given type T, get type T*.
    final JITType pointerOf()
    {
        auto result = gcc_jit_type_get_pointer(this.getType());
        return new JITType(result);
    }

    /// Given type T, get type const T.
    final JITType constOf()
    {
        auto result = gcc_jit_type_get_const(this.getType());
        return new JITType(result);
    }

    /// Given type T, get type volatile T.
    final JITType volatileOf()
    {
        auto result = gcc_jit_type_get_volatile(this.getType());
        return new JITType(result);
    }
}

/// You can model C struct types by creating JITStruct and JITField
/// instances, in either order:
/// $(UL
///     $(LI By creating the fields, then the structure.)
///     $(LI By creating the structure, then populating it with fields,
///          typically to allow modelling self-referential structs.)
/// )
class JITStruct : JITType
{
    ///
    this()
    {
        super(null);
    }

    ///
    this(gcc_jit_struct* agg)
    {
        super(gcc_jit_struct_as_type(agg));
    }

    /// Returns the internal gcc_jit_struct object.
    final gcc_jit_struct* getStruct()
    {
        // Manual downcast.
        return cast(gcc_jit_struct*)(this.getObject());
    }

    /// Populate the fields of a formerly-opaque struct type.
    /// This can only be called once on a given struct type.
    final void setFields(JITLocation loc, JITField[] fields...)
    {
        // Convert to an array of inner pointers.
        gcc_jit_field*[] field_p = new gcc_jit_field*[fields.length];
        foreach (i, field; fields)
            field_p[i] = field.getField();

        // Treat the array as being of the underlying pointers, relying on
        // the wrapper type being such a pointer internally.
        gcc_jit_struct_set_fields(this.getStruct(), loc
                ? loc.getLocation() : null, cast(int) fields.length, field_p.ptr);
    }

    /// Ditto
    final void setFields(JITField[] fields...)
    {
        this.setFields(null, fields);
    }
}

/// Class wrapper for gcc_jit_function
class JITFunction : JITObject
{
    ///
    this()
    {
        super();
    }

    ///
    this(gcc_jit_function* func)
    {
        if (!func)
            throw new JITError("Unknown error, got bad function");
        super(gcc_jit_function_as_object(func));
    }

    /// Returns the internal gcc_jit_function object.
    final gcc_jit_function* getFunction()
    {
        // Manual downcast.
        return cast(gcc_jit_function*)(this.getObject());
    }

    /// Dump function to dot file.
    final void dump(string path)
    {
        gcc_jit_function_dump_to_dot(this.getFunction(), path.toStringz());
    }

    /// Get a specific param of a function by index.
    final JITParam getParam(int index)
    {
        auto result = gcc_jit_function_get_param(this.getFunction(), index);
        return new JITParam(result);
    }

    /// Create a new JITBlock.
    /// The name can be null, or you can give it a meaningful name, which may
    /// show up in dumps of the internal representation, and in error messages.
    final JITBlock newBlock()
    {
        auto result = gcc_jit_function_new_block(this.getFunction(), null);
        return new JITBlock(result);
    }

    /// Ditto
    final JITBlock newBlock(string name)
    {
        auto result = gcc_jit_function_new_block(this.getFunction(), name.toStringz());
        return new JITBlock(result);
    }

    /// Create a new local variable.
    final JITLValue newLocal(JITLocation loc, JITType type, string name)
    {
        auto result = gcc_jit_function_new_local(this.getFunction(), loc
                ? loc.getLocation() : null, type.getType(), name.toStringz());
        return new JITLValue(result);
    }

    /// Ditto
    final JITLValue newLocal(JITType type, string name)
    {
        return this.newLocal(null, type, name);
    }
}

/// Class wrapper for gcc_jit_block
class JITBlock : JITObject
{
    ///
    this()
    {
        super();
    }

    ///
    this(gcc_jit_block* block)
    {
        super(gcc_jit_block_as_object(block));
    }

    /// Returns the internal gcc_jit_block object.
    final gcc_jit_block* getBlock()
    {
        // Manual downcast.
        return cast(gcc_jit_block*)(this.getObject());
    }

    /// Returns the JITFunction this JITBlock is within.
    final JITFunction getFunction()
    {
        auto result = gcc_jit_block_get_function(this.getBlock());
        return new JITFunction(result);
    }

    /// Add evaluation of an rvalue, discarding the result.
    final void addEval(JITLocation loc, JITRValue rvalue)
    {
        gcc_jit_block_add_eval(this.getBlock(), loc ? loc.getLocation() : null, rvalue.getRValue());
    }

    /// Ditto
    final void addEval(JITRValue rvalue)
    {
        return this.addEval(null, rvalue);
    }

    /// Add evaluation of an rvalue, assigning the result to the given lvalue.
    /// This is equivalent to "lvalue = rvalue".
    final void addAssignment(JITLocation loc, JITLValue lvalue, JITRValue rvalue)
    {
        gcc_jit_block_add_assignment(this.getBlock(), loc
                ? loc.getLocation() : null, lvalue.getLValue(), rvalue.getRValue());
    }

    /// Ditto
    final void addAssignment(JITLValue lvalue, JITRValue rvalue)
    {
        return this.addAssignment(null, lvalue, rvalue);
    }

    /// Add evaluation of an rvalue, using the result to modify an lvalue.
    /// This is equivalent to "lvalue op= rvalue".
    final void addAssignmentOp(JITLocation loc, JITLValue lvalue, JITBinaryOp op, JITRValue rvalue)
    {
        gcc_jit_block_add_assignment_op(this.getBlock(), loc
                ? loc.getLocation() : null, lvalue.getLValue(), op, rvalue.getRValue());
    }

    /// Ditto
    final void addAssignmentOp(JITLValue lvalue, JITBinaryOp op, JITRValue rvalue)
    {
        return this.addAssignmentOp(null, lvalue, op, rvalue);
    }

    /// A way to add a function call to the body of a function being
    /// defined, with various number of args.
    final JITRValue addCall(JITLocation loc, JITFunction func, JITRValue[] args...)
    {
        JITRValue rv = this.getContext().newCall(loc, func, args);
        this.addEval(loc, rv);
        return rv;
    }

    /// Ditto
    final JITRValue addCall(JITFunction func, JITRValue[] args...)
    {
        return this.addCall(null, func, args);
    }

    /// Add a no-op textual comment to the internal representation of the code.
    /// It will be optimized away, but visible in the dumps seens via
    /// JITBoolOption.DUMP_INITIAL_TREE and JITBoolOption.DUMP_INITIAL_GIMPLE.
    final void addComment(JITLocation loc, string text)
    {
        gcc_jit_block_add_comment(this.getBlock(), loc ? loc.getLocation() : null, text.toStringz());
    }

    /// Ditto
    final void addComment(string text)
    {
        return this.addComment(null, text);
    }

    /// Terminate a block by adding evaluation of an rvalue, branching on the
    /// result to the appropriate successor block.
    final void endWithConditional(JITLocation loc, JITRValue val,
            JITBlock on_true, JITBlock on_false)
    {
        gcc_jit_block_end_with_conditional(this.getBlock(), loc ? loc.getLocation() : null,
                val.getRValue(), on_true.getBlock(), on_false.getBlock());
    }

    /// Ditto
    final void endWithConditional(JITRValue val, JITBlock on_true, JITBlock on_false)
    {
        return this.endWithConditional(null, val, on_true, on_false);
    }

    /// Terminate a block by adding a jump to the given target block.
    /// This is equivalent to "goto target".
    final void endWithJump(JITLocation loc, JITBlock target)
    {
        gcc_jit_block_end_with_jump(this.getBlock(), loc
                ? loc.getLocation() : null, target.getBlock());
    }

    /// Ditto
    final void endWithJump(JITBlock target)
    {
        return this.endWithJump(null, target);
    }

    /// Terminate a block by adding evaluation of an rvalue, returning the value.
    /// This is equivalent to "return rvalue".
    final void endWithReturn(JITLocation loc, JITRValue rvalue)
    {
        gcc_jit_block_end_with_return(this.getBlock(), loc
                ? loc.getLocation() : null, rvalue.getRValue());
    }

    /// Ditto
    final void endWithReturn(JITRValue rvalue)
    {
        return this.endWithReturn(null, rvalue);
    }

    /// Terminate a block by adding a valueless return, for use within a
    /// function with "void" return type.
    /// This is equivalent to "return".
    final void endWithReturn(JITLocation loc = null)
    {
        gcc_jit_block_end_with_void_return(this.getBlock(), loc ? loc.getLocation() : null);
    }
}

/// Class wrapper for gcc_jit_rvalue
class JITRValue : JITObject
{
    ///
    this()
    {
        super();
    }

    ///
    this(gcc_jit_rvalue* rvalue)
    {
        if (!rvalue)
            throw new JITError("Unknown error, got bad rvalue");
        super(gcc_jit_rvalue_as_object(rvalue));
    }

    /// Returns the internal gcc_jit_rvalue object.
    final gcc_jit_rvalue* getRValue()
    {
        // Manual downcast.
        return cast(gcc_jit_rvalue*)(this.getObject());
    }

    /// Returns the JITType of the rvalue.
    final JITType getType()
    {
        auto result = gcc_jit_rvalue_get_type(this.getRValue());
        return new JITType(result);
    }

    /// Accessing a field of an rvalue of struct type.
    /// This is equivalent to "(value).field".
    JITRValue accessField(JITLocation loc, JITField field)
    {
        auto result = gcc_jit_rvalue_access_field(this.getRValue(), loc
                ? loc.getLocation() : null, field.getField());
        return new JITRValue(result);
    }

    /// Ditto
    JITRValue accessField(JITField field)
    {
        return this.accessField(null, field);
    }

    /// Accessing a field of an rvalue of pointer type.
    /// This is equivalent to "(*value).field".
    final JITLValue dereferenceField(JITLocation loc, JITField field)
    {
        auto result = gcc_jit_rvalue_dereference_field(this.getRValue(), loc
                ? loc.getLocation() : null, field.getField());
        return new JITLValue(result);
    }

    /// Ditto
    final JITLValue dereferenceField(JITField field)
    {
        return this.dereferenceField(null, field);
    }

    /// Dereferencing an rvalue of pointer type.
    /// This is equivalent to "*(value)".
    final JITLValue dereference(JITLocation loc = null)
    {
        auto result = gcc_jit_rvalue_dereference(this.getRValue(), loc ? loc.getLocation() : null);
        return new JITLValue(result);
    }

    /// Convert an rvalue to the given JITType.  See JITContext.newCast for
    /// limitations.
    final JITRValue castTo(JITLocation loc, JITType type)
    {
        return this.getContext().newCast(loc, this, type);
    }

    /// Ditto
    final JITRValue castTo(JITType type)
    {
        return this.castTo(null, type);
    }

    /// Ditto
    final JITRValue castTo(JITLocation loc, JITTypeKind kind)
    {
        return this.castTo(loc, this.getContext().getType(kind));
    }

    /// Ditto
    final JITRValue castTo(JITTypeKind kind)
    {
        return this.castTo(null, this.getContext().getType(kind));
    }
}

/// Class wrapper for gcc_jit_lvalue
class JITLValue : JITRValue
{
    ///
    this()
    {
        super();
    }

    ///
    this(gcc_jit_lvalue* lvalue)
    {
        if (!lvalue)
            throw new JITError("Unknown error, got bad lvalue");
        super(gcc_jit_lvalue_as_rvalue(lvalue));
    }

    /// Returns the internal gcc_jit_lvalue object.
    final gcc_jit_lvalue* getLValue()
    {
        // Manual downcast.
        return cast(gcc_jit_lvalue*)(this.getObject());
    }

    /// Accessing a field of an lvalue of struct type.
    /// This is equivalent to "(value).field = ...".
    override JITLValue accessField(JITLocation loc, JITField field)
    {
        auto result = gcc_jit_lvalue_access_field(this.getLValue(), loc
                ? loc.getLocation() : null, field.getField());
        return new JITLValue(result);
    }

    /// Ditto
    override JITLValue accessField(JITField field)
    {
        return this.accessField(null, field);
    }

    /// Taking the address of an lvalue.
    /// This is equivalent to "&(value)".
    final JITRValue getAddress(JITLocation loc = null)
    {
        auto result = gcc_jit_lvalue_get_address(this.getLValue(), loc ? loc.getLocation() : null);
        return new JITRValue(result);
    }
}

/// Class wrapper for gcc_jit_param
class JITParam : JITLValue
{
    ///
    this()
    {
        super();
    }

    ///
    this(gcc_jit_param* param)
    {
        if (!param)
            throw new JITError("Unknown error, got bad param");
        super(gcc_jit_param_as_lvalue(param));
    }

    /// Returns the internal gcc_jit_param object.
    final gcc_jit_param* getParam()
    {
        // Manual downcast.
        return cast(gcc_jit_param*)(this.getObject());
    }
}

/// Class wrapper for gcc_jit_result
final class JITResult
{
    ///
    this()
    {
        this.m_inner_result = null;
    }

    ///
    this(gcc_jit_result* result)
    {
        if (!result)
            throw new JITError("Unknown error, got bad result");
        this.m_inner_result = result;
    }

    /// Returns the internal gcc_jit_result object.
    gcc_jit_result* getResult()
    {
        return this.m_inner_result;
    }

    /// Locate a given function within the built machine code.
    /// This will need to be cast to a function pointer of the correct type
    /// before it can be called.
    void* getCode(string name)
    {
        return gcc_jit_result_get_code(this.getResult(), name.toStringz());
    }

    /// Locate a given global within the built machine code.
    /// It must have been created using JITGlobalKind.EXPORTED.
    /// This returns is a pointer to the global.
    void* getGlobal(string name)
    {
        return gcc_jit_result_get_global(this.getResult(), name.toStringz());
    }

    /// Once we're done with the code, this unloads the built .so file.
    /// After this call, it's no longer valid to use this JITResult.
    void release()
    {
        gcc_jit_result_release(this.getResult());
    }

private:
    gcc_jit_result* m_inner_result;
}

/// Kinds of function.
enum JITFunctionKind : gcc_jit_function_kind
{
    /// Function is defined by the client code and visible by name
    /// outside of the JIT.
    EXPORTED = GCC_JIT_FUNCTION_EXPORTED,
    /// Function is defined by the client code, but is invisible
    /// outside of the JIT.
    INTERNAL = GCC_JIT_FUNCTION_INTERNAL,
    /// Function is not defined by the client code; we're merely
    /// referring to it.
    IMPORTED = GCC_JIT_FUNCTION_IMPORTED,
    /// Function is only ever inlined into other functions, and is
    /// invisible outside of the JIT.
    ALWAYS_INLINE = GCC_JIT_FUNCTION_ALWAYS_INLINE,
}

/// Kinds of global.
enum JITGlobalKind : gcc_jit_global_kind
{
    /// Global is defined by the client code and visible by name
    /// outside of this JIT context.
    EXPORTED = GCC_JIT_GLOBAL_EXPORTED,
    /// Global is defined by the client code, but is invisible
    /// outside of this JIT context.  Analogous to a "static" global.
    INTERNAL = GCC_JIT_GLOBAL_INTERNAL,
    /// Global is not defined by the client code; we're merely
    /// referring to it.  Analogous to using an "extern" global.
    IMPORTED = GCC_JIT_GLOBAL_IMPORTED,
}

/// Standard types.
enum JITTypeKind : gcc_jit_types
{
    /// C's void type.
    VOID = GCC_JIT_TYPE_VOID,

    /// C's void* type.
    VOID_PTR = GCC_JIT_TYPE_VOID_PTR,

    /// C++'s bool type.
    BOOL = GCC_JIT_TYPE_BOOL,

    /// C's char type.
    CHAR = GCC_JIT_TYPE_CHAR,

    /// C's signed char type.
    SIGNED_CHAR
        = GCC_JIT_TYPE_SIGNED_CHAR,/// C's unsigned char type.
        UNSIGNED_CHAR = GCC_JIT_TYPE_UNSIGNED_CHAR,

        /// C's short type.
        SHORT = GCC_JIT_TYPE_SHORT,/// C's unsigned short type.
        UNSIGNED_SHORT = GCC_JIT_TYPE_UNSIGNED_SHORT,

        /// C's int type.
        INT = GCC_JIT_TYPE_INT,/// C's unsigned int type.
        UNSIGNED_INT = GCC_JIT_TYPE_UNSIGNED_INT,

        /// C's long type.
        LONG = GCC_JIT_TYPE_LONG,/// C's unsigned long type.
        UNSIGNED_LONG = GCC_JIT_TYPE_UNSIGNED_LONG,

        /// C99's long long type.
        LONG_LONG = GCC_JIT_TYPE_LONG_LONG,

        /// C99's unsigned long long type.
        UNSIGNED_LONG_LONG = GCC_JIT_TYPE_UNSIGNED_LONG_LONG,/// Single precision floating point type.
        FLOAT = GCC_JIT_TYPE_FLOAT,

        /// Double precision floating point type.
        DOUBLE = GCC_JIT_TYPE_DOUBLE,/// Largest supported floating point type.
        LONG_DOUBLE = GCC_JIT_TYPE_LONG_DOUBLE,

        /// C's const char* type.
        CONST_CHAR_PTR = GCC_JIT_TYPE_CONST_CHAR_PTR,/// C's size_t type.
        SIZE_T = GCC_JIT_TYPE_SIZE_T,

        /// C's FILE* type.
        FILE_PTR = GCC_JIT_TYPE_FILE_PTR,/// Single precision complex float type.
        COMPLEX_FLOAT = GCC_JIT_TYPE_COMPLEX_FLOAT,

        /// Double precision complex float type.
        COMPLEX_DOUBLE = GCC_JIT_TYPE_COMPLEX_DOUBLE,

        /// Largest supported complex float type.
        COMPLEX_LONG_DOUBLE = GCC_JIT_TYPE_COMPLEX_LONG_DOUBLE,
}

/// Kinds of unary ops.
enum JITUnaryOp : gcc_jit_unary_op
{
    /// Negate an arithmetic value.
    /// This is equivalent to "-(value)".
    MINUS = GCC_JIT_UNARY_OP_MINUS,
    /// Bitwise negation of an integer value (one's complement).
    /// This is equivalent to "~(value)".
    BITWISE_NEGATE = GCC_JIT_UNARY_OP_BITWISE_NEGATE,
    /// Logical negation of an arithmetic or pointer value.
    /// This is equivalent to "!(value)".
    LOGICAL_NEGATE = GCC_JIT_UNARY_OP_LOGICAL_NEGATE,
}

/// Kinds of binary ops.
enum JITBinaryOp : gcc_jit_binary_op
{
    /// Addition of arithmetic values.
    /// This is equivalent to "(a) + (b)".
    PLUS = GCC_JIT_BINARY_OP_PLUS,
    /// Subtraction of arithmetic values.
    /// This is equivalent to "(a) - (b)".
    MINUS = GCC_JIT_BINARY_OP_MINUS,
    /// Multiplication of a pair of arithmetic values.
    /// This is equivalent to "(a) * (b)".
    MULT = GCC_JIT_BINARY_OP_MULT,
    /// Quotient of division of arithmetic values.
    /// This is equivalent to "(a) / (b)".
    DIVIDE = GCC_JIT_BINARY_OP_DIVIDE,
    /// Remainder of division of arithmetic values.
    /// This is equivalent to "(a) % (b)".
    MODULO = GCC_JIT_BINARY_OP_MODULO,
    /// Bitwise AND.
    /// This is equivalent to "(a) & (b)".
    BITWISE_AND = GCC_JIT_BINARY_OP_BITWISE_AND,
    /// Bitwise exclusive OR.
    /// This is equivalent to "(a) ^ (b)".
    BITWISE_XOR = GCC_JIT_BINARY_OP_BITWISE_XOR,
    /// Bitwise inclusive OR.
    /// This is equivalent to "(a) | (b)".
    BITWISE_OR = GCC_JIT_BINARY_OP_BITWISE_OR,
    /// Logical AND.
    /// This is equivalent to "(a) && (b)".
    LOGICAL_AND = GCC_JIT_BINARY_OP_LOGICAL_AND,
    /// Logical OR.
    /// This is equivalent to "(a) || (b)".
    LOGICAL_OR = GCC_JIT_BINARY_OP_LOGICAL_OR,
    /// Left shift.
    /// This is equivalent to "(a) << (b)".
    LSHIFT = GCC_JIT_BINARY_OP_LSHIFT,
    /// Right shift.
    /// This is equivalent to "(a) >> (b)".
    RSHIFT = GCC_JIT_BINARY_OP_RSHIFT,
}

/// Kinds of comparison.
enum JITComparison : gcc_jit_comparison
{
    /// This is equivalent to "(a) == (b)".
    EQ = GCC_JIT_COMPARISON_EQ,
    /// This is equivalent to "(a) != (b)".
    NE = GCC_JIT_COMPARISON_NE,
    /// This is equivalent to "(a) < (b)".
    LT = GCC_JIT_COMPARISON_LT,
    /// This is equivalent to "(a) <= (b)".
    LE = GCC_JIT_COMPARISON_LE,
    /// This is equivalent to "(a) > (b)".
    GT = GCC_JIT_COMPARISON_GT,
    /// This is equivalent to "(a) >= (b)".
    GE = GCC_JIT_COMPARISON_GE,
}

/// String options
enum JITStrOption : gcc_jit_str_option
{
    /// The name of the program, for use as a prefix when printing error
    /// messages to stderr. If None, or default, "libgccjit.so" is used.
    PROGNAME = GCC_JIT_STR_OPTION_PROGNAME,
}

/// Integer options
enum JITIntOption : gcc_jit_int_option
{
    /// How much to optimize the code.

    /// Valid values are 0-3, corresponding to GCC's command-line options
    /// -O0 through -O3.

    /// The default value is 0 (unoptimized).
    OPTIMIZATION_LEVEL = GCC_JIT_INT_OPTION_OPTIMIZATION_LEVEL,
}

/// Boolean options
enum JITBoolOption : gcc_jit_bool_option
{
    /// If true, JITContext.compile() will attempt to do the right thing
    /// so that if you attach a debugger to the process, it will be able
    /// to inspect variables and step through your code.

    /// Note that you can’t step through code unless you set up source
    /// location information for the code (by creating and passing in
    /// JITLocation instances).
    DEBUGINFO = GCC_JIT_BOOL_OPTION_DEBUGINFO,

    /// If true, JITContext.compile() will dump its initial "tree"
    /// representation of your code to stderr, before any optimizations.
    DUMP_INITIAL_TREE = GCC_JIT_BOOL_OPTION_DUMP_INITIAL_TREE,

    /// If true, JITContext.compile() will dump its initial "gimple"
    /// representation of your code to stderr, before any optimizations
    /// are performed. The dump resembles C code.
    DUMP_INITIAL_GIMPLE = GCC_JIT_BOOL_OPTION_DUMP_INITIAL_GIMPLE,

    /// If true, JITContext.compile() will dump the final generated code
    /// to stderr, in the form of assembly language.
    DUMP_GENERATED_CODE = GCC_JIT_BOOL_OPTION_DUMP_GENERATED_CODE,

    /// If true, JITContext.compile() will print information to stderr
    /// on the actions it is performing, followed by a profile showing
    /// the time taken and memory usage of each phase.
    DUMP_SUMMARY = GCC_JIT_BOOL_OPTION_DUMP_SUMMARY,

    /// If true, JITContext.compile() will dump copious amounts of
    /// information on what it’s doing to various files within a
    /// temporary directory. Use JITBoolOption.KEEP_INTERMEDIATES
    /// to see the results. The files are intended to be human-readable,
    /// but the exact files and their formats are subject to change.
    DUMP_EVERYTHING = GCC_JIT_BOOL_OPTION_DUMP_EVERYTHING,

    /// If true, libgccjit will aggressively run its garbage collector,
    /// to shake out bugs (greatly slowing down the compile). This is
    /// likely to only be of interest to developers of the library.
    SELFCHECK_GC = GCC_JIT_BOOL_OPTION_SELFCHECK_GC,

    /// If true, the JITContext will not clean up intermediate files
    /// written to the filesystem, and will display their location on
    /// stderr.
    KEEP_INTERMEDIATES = GCC_JIT_BOOL_OPTION_KEEP_INTERMEDIATES,
}
