module purr.jit.other;

import std.stdio;
import purr.jit.native;
import purr.jit.wrapper;

extern(C)
{
    int gcc_jit_version_major();
    int gcc_jit_version_minor();
    int gcc_jit_version_patchlevel();
    gcc_jit_rvalue * gcc_jit_function_get_address(gcc_jit_function *fn, gcc_jit_location *loc);

    gcc_jit_rvalue* paka_gcc_jit_sizeof(gcc_jit_context* ctx, gcc_jit_type* t)
    {   
        void* NULL_PTR = null;

        gcc_jit_type* t_ptr_type = gcc_jit_type_get_pointer(t);
        gcc_jit_type* size_type = gcc_jit_context_get_type(ctx, GCC_JIT_TYPE_SIZE_T);
        gcc_jit_type* byte_type_ptr = gcc_jit_type_get_pointer(gcc_jit_context_get_int_type(ctx, 1, 0));

        gcc_jit_rvalue* one = gcc_jit_context_new_rvalue_from_int(ctx, size_type, 1);

        gcc_jit_rvalue* ptr_0 = gcc_jit_context_new_rvalue_from_ptr(ctx, t_ptr_type, cast(void*) &NULL_PTR);
        gcc_jit_rvalue* ptr_1 = gcc_jit_lvalue_get_address(gcc_jit_context_new_array_access(ctx, null, ptr_0, one), null);

        ptr_0 = gcc_jit_context_new_cast(ctx, null, ptr_0, byte_type_ptr);
        ptr_1 = gcc_jit_context_new_cast(ctx, null, ptr_1, byte_type_ptr);

        return gcc_jit_context_new_binary_op(ctx, null, GCC_JIT_BINARY_OP_MINUS, size_type, ptr_1, ptr_0);
    }
}

// Get Function Pointer from function
JITRValue getAddress(JITFunction func, JITLocation loc)
{
    auto result = gcc_jit_function_get_address(func.getFunction(), loc ? loc.getLocation() : null);
    return new JITRValue(result);
}

// Ditto
JITRValue getAddress(JITFunction func)
{
    return func.getAddress(null);
}

JITRValue getSizeOf(JITContext ctx, JITType type)
{
    return new JITRValue(paka_gcc_jit_sizeof(ctx.getContext, type.getType));
}
