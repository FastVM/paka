/// Bindings to the <a href="https://github.com/wasmerio/wasmer/tree/master/lib/c-api#readme">Wasmer Runtime C API</a>.
///
/// See_Also:
/// $(UL
///   $(LI <a href="https://github.com/chances/wasmer-d/blob/26a3cb32c79508dc2b8b33e9d2d176a3d6debdf1/source/wasmer/bindings/package.d">`wasmer.bindings` Source Code</a>)
///   $(LI The official <a href="https://github.com/wasmerio/wasmer/tree/master/lib/c-api#readme">Wasmer Runtime C API</a> documentation.)
/// )
///
/// Authors: Chance Snow
/// Copyright: Copyright © 2020-2021 Chance Snow. All rights reserved.
/// License: MIT License
module wasmer.bindings;


        import core.stdc.config;
        import core.stdc.stdarg: va_list;
        static import core.simd;
        static import std.conv;

        struct Int128 { long lower; long upper; }
        struct UInt128 { ulong lower; ulong upper; }

        struct __locale_data { int dummy; }  // FIXME
        // #define __gnuc_va_list va_list

    // #define __is_empty(_Type) dpp.isEmpty!(_Type)
alias _Bool = bool;
struct dpp {
    static struct Opaque(int N) {
        void[N] bytes;
    }
    // Replacement for the gcc/clang intrinsic
    static bool isEmpty(T)() {
        return T.tupleof.length == 0;
    }
    static struct Move(T) {
        T* ptr;
    }
    // dmd bug causes a crash if T is passed by value.
    // Works fine with ldc.
    static auto move(T)(ref T value) {
        return Move!T(&value);
    }
    mixin template EnumD(string name, T, string prefix) if(is(T == enum)) {
        private static string _memberMixinStr(string member) {
            import std.conv: text;
            import std.array: replace;
            return text(`    `, member.replace(prefix, ""), ` = `, T.stringof, `.`, member, `,`);
        }
        private static string _enumMixinStr() {
            import std.array: join;
            string[] ret;
            ret ~= "enum " ~ name ~ "{";
            static foreach(member; __traits(allMembers, T)) {
                ret ~= _memberMixinStr(member);
            }
            ret ~= "}";
            return ret.join("\n");
        }
        mixin(_enumMixinStr());
    }
}

extern(C)
{
    alias wchar_t = int;
    alias size_t = c_ulong;
    alias ptrdiff_t = c_long;
    struct max_align_t
    {
        long __clang_max_align_nonce1;
        real __clang_max_align_nonce2;
    }
    alias fsfilcnt_t = c_ulong;
    alias fsblkcnt_t = c_ulong;
    alias blkcnt_t = c_long;
    alias blksize_t = c_long;
    alias register_t = c_long;
    alias u_int64_t = c_ulong;
    alias u_int32_t = uint;
    alias u_int16_t = ushort;
    alias u_int8_t = ubyte;
    alias key_t = int;
    alias caddr_t = char*;
    alias daddr_t = int;
    alias ssize_t = c_long;
    alias id_t = uint;
    alias pid_t = int;
    alias off_t = c_long;
    alias uid_t = uint;
    alias nlink_t = c_ulong;
    alias mode_t = uint;
    alias gid_t = uint;
    alias dev_t = c_ulong;
    alias ino_t = c_ulong;
    alias loff_t = c_long;
    alias fsid_t = __fsid_t;
    alias u_quad_t = c_ulong;
    alias quad_t = c_long;
    alias u_long = c_ulong;
    alias u_int = uint;
    alias u_short = ushort;
    alias u_char = ubyte;
    c_ulong gnu_dev_makedev(uint, uint) @nogc nothrow;
    uint gnu_dev_minor(c_ulong) @nogc nothrow;
    uint gnu_dev_major(c_ulong) @nogc nothrow;
    int pselect(int, fd_set*, fd_set*, fd_set*, const(timespec)*, const(__sigset_t)*) @nogc nothrow;
    int select(int, fd_set*, fd_set*, fd_set*, timeval*) @nogc nothrow;
    alias fd_mask = c_long;
    struct fd_set
    {
        c_long[16] __fds_bits;
    }
    alias __fd_mask = c_long;
    alias suseconds_t = c_long;
    enum _Anonymous_0
    {
        P_ALL = 0,
        P_PID = 1,
        P_PGID = 2,
    }
    enum P_ALL = _Anonymous_0.P_ALL;
    enum P_PID = _Anonymous_0.P_PID;
    enum P_PGID = _Anonymous_0.P_PGID;
    alias idtype_t = _Anonymous_0;
    static c_ulong __uint64_identity(c_ulong) @nogc nothrow;
    static uint __uint32_identity(uint) @nogc nothrow;
    static ushort __uint16_identity(ushort) @nogc nothrow;
    alias timer_t = void*;
    alias time_t = c_long;
    struct timeval
    {
        c_long tv_sec;
        c_long tv_usec;
    }
    struct timespec
    {
        c_long tv_sec;
        c_long tv_nsec;
    }
    alias sigset_t = __sigset_t;
    alias locale_t = __locale_struct*;
    alias clockid_t = int;
    alias clock_t = c_long;
    struct __sigset_t
    {
        c_ulong[16] __val;
    }
    alias __locale_t = __locale_struct*;
    struct __locale_struct
    {
        __locale_data*[13] __locales;
        const(ushort)* __ctype_b;
        const(int)* __ctype_tolower;
        const(int)* __ctype_toupper;
        const(char)*[13] __names;
    }
    alias __sig_atomic_t = int;
    alias __socklen_t = uint;
    alias __intptr_t = c_long;
    alias __caddr_t = char*;
    alias __loff_t = c_long;
    alias __syscall_ulong_t = c_ulong;
    alias __syscall_slong_t = c_long;
    alias __ssize_t = c_long;
    alias __fsword_t = c_long;
    alias __fsfilcnt64_t = c_ulong;
    alias __fsfilcnt_t = c_ulong;
    alias __fsblkcnt64_t = c_ulong;
    alias __fsblkcnt_t = c_ulong;
    alias __blkcnt64_t = c_long;
    alias __blkcnt_t = c_long;
    alias __blksize_t = c_long;
    alias __timer_t = void*;
    alias __clockid_t = int;
    alias __key_t = int;
    alias __daddr_t = int;
    alias __suseconds_t = c_long;
    alias __useconds_t = uint;
    alias __time_t = c_long;
    alias __id_t = uint;
    alias __rlim64_t = c_ulong;
    void assertions() @nogc nothrow;
    alias byte_t = char;
    alias float32_t = float;
    alias float64_t = double;
    alias __rlim_t = c_ulong;
    alias wasm_byte_t = char;
    struct wasm_byte_vec_t
    {
        c_ulong size;
        char* data;
    }
    void wasm_byte_vec_delete(wasm_byte_vec_t*) @nogc nothrow;
    void wasm_byte_vec_copy(wasm_byte_vec_t*, const(wasm_byte_vec_t)*) @nogc nothrow;
    void wasm_byte_vec_new(wasm_byte_vec_t*, c_ulong, const(char)*) @nogc nothrow;
    void wasm_byte_vec_new_uninitialized(wasm_byte_vec_t*, c_ulong) @nogc nothrow;
    void wasm_byte_vec_new_empty(wasm_byte_vec_t*) @nogc nothrow;
    alias wasm_name_t = wasm_byte_vec_t;
    alias __clock_t = c_long;
    struct wasm_config_t;
    void wasm_config_delete(wasm_config_t*) @nogc nothrow;
    wasm_config_t* wasm_config_new() @nogc nothrow;
    void wasm_engine_delete(wasm_engine_t*) @nogc nothrow;
    struct wasm_engine_t;
    wasm_engine_t* wasm_engine_new() @nogc nothrow;
    wasm_engine_t* wasm_engine_new_with_config(wasm_config_t*) @nogc nothrow;
    struct wasm_store_t;
    void wasm_store_delete(wasm_store_t*) @nogc nothrow;
    wasm_store_t* wasm_store_new(wasm_engine_t*) @nogc nothrow;
    alias wasm_mutability_t = ubyte;
    enum wasm_mutability_enum : ubyte
    {
        WASM_CONST = 0,
        WASM_VAR = 1,
    }
    enum WASM_CONST = wasm_mutability_enum.WASM_CONST;
    enum WASM_VAR = wasm_mutability_enum.WASM_VAR;
    struct wasm_limits_t
    {
        uint min;
        uint max;
    }
    extern __gshared const(uint) wasm_limits_max_default;
    struct __fsid_t
    {
        int[2] __val;
    }
    wasm_valtype_t* wasm_valtype_copy(wasm_valtype_t*) @nogc nothrow;
    void wasm_valtype_vec_delete(wasm_valtype_vec_t*) @nogc nothrow;
    void wasm_valtype_vec_copy(wasm_valtype_vec_t*, const(wasm_valtype_vec_t)*) @nogc nothrow;
    void wasm_valtype_vec_new(wasm_valtype_vec_t*, c_ulong, wasm_valtype_t**) @nogc nothrow;
    void wasm_valtype_vec_new_uninitialized(wasm_valtype_vec_t*, c_ulong) @nogc nothrow;
    void wasm_valtype_vec_new_empty(wasm_valtype_vec_t*) @nogc nothrow;
    struct wasm_valtype_vec_t
    {
        c_ulong size;
        wasm_valtype_t** data;
    }
    void wasm_valtype_delete(wasm_valtype_t*) @nogc nothrow;
    struct wasm_valtype_t;
    alias wasm_valkind_t = ubyte;
    enum wasm_valkind_enum : ubyte
    {
        WASM_I32 = 0,
        WASM_I64 = 1,
        WASM_F32 = 2,
        WASM_F64 = 3,
        WASM_ANYREF = 128,
        WASM_FUNCREF = 129,
    }
    enum WASM_I32 = wasm_valkind_enum.WASM_I32;
    enum WASM_I64 = wasm_valkind_enum.WASM_I64;
    enum WASM_F32 = wasm_valkind_enum.WASM_F32;
    enum WASM_F64 = wasm_valkind_enum.WASM_F64;
    enum WASM_ANYREF = wasm_valkind_enum.WASM_ANYREF;
    enum WASM_FUNCREF = wasm_valkind_enum.WASM_FUNCREF;
    wasm_valtype_t* wasm_valtype_new(ubyte) @nogc nothrow;
    ubyte wasm_valtype_kind(const(wasm_valtype_t)*) @nogc nothrow;
    static bool wasm_valkind_is_num(ubyte) @nogc nothrow;
    static bool wasm_valkind_is_ref(ubyte) @nogc nothrow;
    static bool wasm_valtype_is_num(const(wasm_valtype_t)*) @nogc nothrow;
    static bool wasm_valtype_is_ref(const(wasm_valtype_t)*) @nogc nothrow;
    struct wasm_functype_t;
    void wasm_functype_delete(wasm_functype_t*) @nogc nothrow;
    struct wasm_functype_vec_t
    {
        c_ulong size;
        wasm_functype_t** data;
    }
    void wasm_functype_vec_new_empty(wasm_functype_vec_t*) @nogc nothrow;
    void wasm_functype_vec_new_uninitialized(wasm_functype_vec_t*, c_ulong) @nogc nothrow;
    void wasm_functype_vec_copy(wasm_functype_vec_t*, const(wasm_functype_vec_t)*) @nogc nothrow;
    void wasm_functype_vec_delete(wasm_functype_vec_t*) @nogc nothrow;
    wasm_functype_t* wasm_functype_copy(wasm_functype_t*) @nogc nothrow;
    void wasm_functype_vec_new(wasm_functype_vec_t*, c_ulong, wasm_functype_t**) @nogc nothrow;
    wasm_functype_t* wasm_functype_new(wasm_valtype_vec_t*, wasm_valtype_vec_t*) @nogc nothrow;
    const(wasm_valtype_vec_t)* wasm_functype_params(const(wasm_functype_t)*) @nogc nothrow;
    const(wasm_valtype_vec_t)* wasm_functype_results(const(wasm_functype_t)*) @nogc nothrow;
    struct wasm_globaltype_t;
    void wasm_globaltype_delete(wasm_globaltype_t*) @nogc nothrow;
    struct wasm_globaltype_vec_t
    {
        c_ulong size;
        wasm_globaltype_t** data;
    }
    void wasm_globaltype_vec_new_empty(wasm_globaltype_vec_t*) @nogc nothrow;
    void wasm_globaltype_vec_new_uninitialized(wasm_globaltype_vec_t*, c_ulong) @nogc nothrow;
    void wasm_globaltype_vec_new(wasm_globaltype_vec_t*, c_ulong, wasm_globaltype_t**) @nogc nothrow;
    void wasm_globaltype_vec_copy(wasm_globaltype_vec_t*, const(wasm_globaltype_vec_t)*) @nogc nothrow;
    void wasm_globaltype_vec_delete(wasm_globaltype_vec_t*) @nogc nothrow;
    wasm_globaltype_t* wasm_globaltype_copy(wasm_globaltype_t*) @nogc nothrow;
    wasm_globaltype_t* wasm_globaltype_new(wasm_valtype_t*, ubyte) @nogc nothrow;
    const(wasm_valtype_t)* wasm_globaltype_content(const(wasm_globaltype_t)*) @nogc nothrow;
    ubyte wasm_globaltype_mutability(const(wasm_globaltype_t)*) @nogc nothrow;
    wasm_tabletype_t* wasm_tabletype_copy(wasm_tabletype_t*) @nogc nothrow;
    void wasm_tabletype_vec_delete(wasm_tabletype_vec_t*) @nogc nothrow;
    void wasm_tabletype_vec_copy(wasm_tabletype_vec_t*, const(wasm_tabletype_vec_t)*) @nogc nothrow;
    void wasm_tabletype_vec_new(wasm_tabletype_vec_t*, c_ulong, wasm_tabletype_t**) @nogc nothrow;
    void wasm_tabletype_vec_new_uninitialized(wasm_tabletype_vec_t*, c_ulong) @nogc nothrow;
    void wasm_tabletype_vec_new_empty(wasm_tabletype_vec_t*) @nogc nothrow;
    struct wasm_tabletype_vec_t
    {
        c_ulong size;
        wasm_tabletype_t** data;
    }
    void wasm_tabletype_delete(wasm_tabletype_t*) @nogc nothrow;
    struct wasm_tabletype_t;
    wasm_tabletype_t* wasm_tabletype_new(wasm_valtype_t*, const(wasm_limits_t)*) @nogc nothrow;
    const(wasm_valtype_t)* wasm_tabletype_element(const(wasm_tabletype_t)*) @nogc nothrow;
    const(wasm_limits_t)* wasm_tabletype_limits(const(wasm_tabletype_t)*) @nogc nothrow;
    struct wasm_memorytype_t;
    struct wasm_memorytype_vec_t
    {
        c_ulong size;
        wasm_memorytype_t** data;
    }
    void wasm_memorytype_delete(wasm_memorytype_t*) @nogc nothrow;
    wasm_memorytype_t* wasm_memorytype_copy(wasm_memorytype_t*) @nogc nothrow;
    void wasm_memorytype_vec_delete(wasm_memorytype_vec_t*) @nogc nothrow;
    void wasm_memorytype_vec_copy(wasm_memorytype_vec_t*, const(wasm_memorytype_vec_t)*) @nogc nothrow;
    void wasm_memorytype_vec_new(wasm_memorytype_vec_t*, c_ulong, wasm_memorytype_t**) @nogc nothrow;
    void wasm_memorytype_vec_new_uninitialized(wasm_memorytype_vec_t*, c_ulong) @nogc nothrow;
    void wasm_memorytype_vec_new_empty(wasm_memorytype_vec_t*) @nogc nothrow;
    wasm_memorytype_t* wasm_memorytype_new(const(wasm_limits_t)*) @nogc nothrow;
    const(wasm_limits_t)* wasm_memorytype_limits(const(wasm_memorytype_t)*) @nogc nothrow;
    void wasm_externtype_vec_new_uninitialized(wasm_externtype_vec_t*, c_ulong) @nogc nothrow;
    void wasm_externtype_vec_new(wasm_externtype_vec_t*, c_ulong, wasm_externtype_t**) @nogc nothrow;
    void wasm_externtype_vec_copy(wasm_externtype_vec_t*, const(wasm_externtype_vec_t)*) @nogc nothrow;
    void wasm_externtype_vec_delete(wasm_externtype_vec_t*) @nogc nothrow;
    wasm_externtype_t* wasm_externtype_copy(wasm_externtype_t*) @nogc nothrow;
    struct wasm_externtype_vec_t
    {
        c_ulong size;
        wasm_externtype_t** data;
    }
    void wasm_externtype_delete(wasm_externtype_t*) @nogc nothrow;
    struct wasm_externtype_t;
    void wasm_externtype_vec_new_empty(wasm_externtype_vec_t*) @nogc nothrow;
    alias wasm_externkind_t = ubyte;
    enum wasm_externkind_enum : ubyte
    {
        WASM_EXTERN_FUNC = 0,
        WASM_EXTERN_GLOBAL = 1,
        WASM_EXTERN_TABLE = 2,
        WASM_EXTERN_MEMORY = 3,
    }
    enum WASM_EXTERN_FUNC = wasm_externkind_enum.WASM_EXTERN_FUNC;
    enum WASM_EXTERN_GLOBAL = wasm_externkind_enum.WASM_EXTERN_GLOBAL;
    enum WASM_EXTERN_TABLE = wasm_externkind_enum.WASM_EXTERN_TABLE;
    enum WASM_EXTERN_MEMORY = wasm_externkind_enum.WASM_EXTERN_MEMORY;
    ubyte wasm_externtype_kind(const(wasm_externtype_t)*) @nogc nothrow;
    wasm_externtype_t* wasm_functype_as_externtype(wasm_functype_t*) @nogc nothrow;
    wasm_externtype_t* wasm_globaltype_as_externtype(wasm_globaltype_t*) @nogc nothrow;
    wasm_externtype_t* wasm_tabletype_as_externtype(wasm_tabletype_t*) @nogc nothrow;
    wasm_externtype_t* wasm_memorytype_as_externtype(wasm_memorytype_t*) @nogc nothrow;
    wasm_functype_t* wasm_externtype_as_functype(wasm_externtype_t*) @nogc nothrow;
    wasm_globaltype_t* wasm_externtype_as_globaltype(wasm_externtype_t*) @nogc nothrow;
    wasm_tabletype_t* wasm_externtype_as_tabletype(wasm_externtype_t*) @nogc nothrow;
    wasm_memorytype_t* wasm_externtype_as_memorytype(wasm_externtype_t*) @nogc nothrow;
    const(wasm_externtype_t)* wasm_functype_as_externtype_const(const(wasm_functype_t)*) @nogc nothrow;
    const(wasm_externtype_t)* wasm_globaltype_as_externtype_const(const(wasm_globaltype_t)*) @nogc nothrow;
    const(wasm_externtype_t)* wasm_tabletype_as_externtype_const(const(wasm_tabletype_t)*) @nogc nothrow;
    const(wasm_externtype_t)* wasm_memorytype_as_externtype_const(const(wasm_memorytype_t)*) @nogc nothrow;
    const(wasm_functype_t)* wasm_externtype_as_functype_const(const(wasm_externtype_t)*) @nogc nothrow;
    const(wasm_globaltype_t)* wasm_externtype_as_globaltype_const(const(wasm_externtype_t)*) @nogc nothrow;
    const(wasm_tabletype_t)* wasm_externtype_as_tabletype_const(const(wasm_externtype_t)*) @nogc nothrow;
    const(wasm_memorytype_t)* wasm_externtype_as_memorytype_const(const(wasm_externtype_t)*) @nogc nothrow;
    void wasm_importtype_delete(wasm_importtype_t*) @nogc nothrow;
    struct wasm_importtype_vec_t
    {
        c_ulong size;
        wasm_importtype_t** data;
    }
    void wasm_importtype_vec_new_empty(wasm_importtype_vec_t*) @nogc nothrow;
    wasm_importtype_t* wasm_importtype_copy(wasm_importtype_t*) @nogc nothrow;
    void wasm_importtype_vec_delete(wasm_importtype_vec_t*) @nogc nothrow;
    void wasm_importtype_vec_copy(wasm_importtype_vec_t*, const(wasm_importtype_vec_t)*) @nogc nothrow;
    void wasm_importtype_vec_new(wasm_importtype_vec_t*, c_ulong, wasm_importtype_t**) @nogc nothrow;
    void wasm_importtype_vec_new_uninitialized(wasm_importtype_vec_t*, c_ulong) @nogc nothrow;
    struct wasm_importtype_t;
    wasm_importtype_t* wasm_importtype_new(wasm_byte_vec_t*, wasm_byte_vec_t*, wasm_externtype_t*) @nogc nothrow;
    const(wasm_byte_vec_t)* wasm_importtype_module(const(wasm_importtype_t)*) @nogc nothrow;
    const(wasm_byte_vec_t)* wasm_importtype_name(const(wasm_importtype_t)*) @nogc nothrow;
    const(wasm_externtype_t)* wasm_importtype_type(const(wasm_importtype_t)*) @nogc nothrow;
    wasm_exporttype_t* wasm_exporttype_copy(wasm_exporttype_t*) @nogc nothrow;
    void wasm_exporttype_vec_delete(wasm_exporttype_vec_t*) @nogc nothrow;
    void wasm_exporttype_vec_copy(wasm_exporttype_vec_t*, const(wasm_exporttype_vec_t)*) @nogc nothrow;
    void wasm_exporttype_vec_new(wasm_exporttype_vec_t*, c_ulong, wasm_exporttype_t**) @nogc nothrow;
    struct wasm_exporttype_t;
    void wasm_exporttype_delete(wasm_exporttype_t*) @nogc nothrow;
    struct wasm_exporttype_vec_t
    {
        c_ulong size;
        wasm_exporttype_t** data;
    }
    void wasm_exporttype_vec_new_empty(wasm_exporttype_vec_t*) @nogc nothrow;
    void wasm_exporttype_vec_new_uninitialized(wasm_exporttype_vec_t*, c_ulong) @nogc nothrow;
    wasm_exporttype_t* wasm_exporttype_new(wasm_byte_vec_t*, wasm_externtype_t*) @nogc nothrow;
    const(wasm_byte_vec_t)* wasm_exporttype_name(const(wasm_exporttype_t)*) @nogc nothrow;
    const(wasm_externtype_t)* wasm_exporttype_type(const(wasm_exporttype_t)*) @nogc nothrow;
    struct wasm_ref_t;
    struct wasm_val_t
    {
        ubyte kind;
        static union _Anonymous_1
        {
            int i32;
            c_long i64;
            float f32;
            double f64;
            wasm_ref_t* ref_;
        }
        _Anonymous_1 of;
    }
    void wasm_val_delete(wasm_val_t*) @nogc nothrow;
    void wasm_val_copy(wasm_val_t*, const(wasm_val_t)*) @nogc nothrow;
    void wasm_val_vec_delete(wasm_val_vec_t*) @nogc nothrow;
    void wasm_val_vec_copy(wasm_val_vec_t*, const(wasm_val_vec_t)*) @nogc nothrow;
    void wasm_val_vec_new(wasm_val_vec_t*, c_ulong, const(wasm_val_t)*) @nogc nothrow;
    void wasm_val_vec_new_uninitialized(wasm_val_vec_t*, c_ulong) @nogc nothrow;
    void wasm_val_vec_new_empty(wasm_val_vec_t*) @nogc nothrow;
    struct wasm_val_vec_t
    {
        c_ulong size;
        wasm_val_t* data;
    }
    alias __pid_t = int;
    void wasm_ref_delete(wasm_ref_t*) @nogc nothrow;
    wasm_ref_t* wasm_ref_copy(const(wasm_ref_t)*) @nogc nothrow;
    bool wasm_ref_same(const(wasm_ref_t)*, const(wasm_ref_t)*) @nogc nothrow;
    void* wasm_ref_get_host_info(const(wasm_ref_t)*) @nogc nothrow;
    void wasm_ref_set_host_info(wasm_ref_t*, void*) @nogc nothrow;
    void wasm_ref_set_host_info_with_finalizer(wasm_ref_t*, void*, void function(void*)) @nogc nothrow;
    struct wasm_frame_t;
    void wasm_frame_delete(wasm_frame_t*) @nogc nothrow;
    struct wasm_frame_vec_t
    {
        c_ulong size;
        wasm_frame_t** data;
    }
    void wasm_frame_vec_new_empty(wasm_frame_vec_t*) @nogc nothrow;
    void wasm_frame_vec_new_uninitialized(wasm_frame_vec_t*, c_ulong) @nogc nothrow;
    void wasm_frame_vec_new(wasm_frame_vec_t*, c_ulong, wasm_frame_t**) @nogc nothrow;
    void wasm_frame_vec_copy(wasm_frame_vec_t*, const(wasm_frame_vec_t)*) @nogc nothrow;
    void wasm_frame_vec_delete(wasm_frame_vec_t*) @nogc nothrow;
    wasm_frame_t* wasm_frame_copy(const(wasm_frame_t)*) @nogc nothrow;
    struct wasm_instance_t;
    wasm_instance_t* wasm_frame_instance(const(wasm_frame_t)*) @nogc nothrow;
    uint wasm_frame_func_index(const(wasm_frame_t)*) @nogc nothrow;
    c_ulong wasm_frame_func_offset(const(wasm_frame_t)*) @nogc nothrow;
    c_ulong wasm_frame_module_offset(const(wasm_frame_t)*) @nogc nothrow;
    alias wasm_message_t = wasm_byte_vec_t;
    const(wasm_trap_t)* wasm_ref_as_trap_const(const(wasm_ref_t)*) @nogc nothrow;
    const(wasm_ref_t)* wasm_trap_as_ref_const(const(wasm_trap_t)*) @nogc nothrow;
    wasm_trap_t* wasm_ref_as_trap(wasm_ref_t*) @nogc nothrow;
    wasm_ref_t* wasm_trap_as_ref(wasm_trap_t*) @nogc nothrow;
    void wasm_trap_set_host_info_with_finalizer(wasm_trap_t*, void*, void function(void*)) @nogc nothrow;
    void wasm_trap_set_host_info(wasm_trap_t*, void*) @nogc nothrow;
    void* wasm_trap_get_host_info(const(wasm_trap_t)*) @nogc nothrow;
    bool wasm_trap_same(const(wasm_trap_t)*, const(wasm_trap_t)*) @nogc nothrow;
    wasm_trap_t* wasm_trap_copy(const(wasm_trap_t)*) @nogc nothrow;
    void wasm_trap_delete(wasm_trap_t*) @nogc nothrow;
    struct wasm_trap_t;
    wasm_trap_t* wasm_trap_new(wasm_store_t*, const(wasm_byte_vec_t)*) @nogc nothrow;
    void wasm_trap_message(const(wasm_trap_t)*, wasm_byte_vec_t*) @nogc nothrow;
    wasm_frame_t* wasm_trap_origin(const(wasm_trap_t)*) @nogc nothrow;
    void wasm_trap_trace(const(wasm_trap_t)*, wasm_frame_vec_t*) @nogc nothrow;
    struct wasm_foreign_t;
    void wasm_foreign_delete(wasm_foreign_t*) @nogc nothrow;
    wasm_foreign_t* wasm_foreign_copy(const(wasm_foreign_t)*) @nogc nothrow;
    bool wasm_foreign_same(const(wasm_foreign_t)*, const(wasm_foreign_t)*) @nogc nothrow;
    void* wasm_foreign_get_host_info(const(wasm_foreign_t)*) @nogc nothrow;
    void wasm_foreign_set_host_info(wasm_foreign_t*, void*) @nogc nothrow;
    void wasm_foreign_set_host_info_with_finalizer(wasm_foreign_t*, void*, void function(void*)) @nogc nothrow;
    wasm_ref_t* wasm_foreign_as_ref(wasm_foreign_t*) @nogc nothrow;
    wasm_foreign_t* wasm_ref_as_foreign(wasm_ref_t*) @nogc nothrow;
    const(wasm_ref_t)* wasm_foreign_as_ref_const(const(wasm_foreign_t)*) @nogc nothrow;
    const(wasm_foreign_t)* wasm_ref_as_foreign_const(const(wasm_ref_t)*) @nogc nothrow;
    wasm_foreign_t* wasm_foreign_new(wasm_store_t*) @nogc nothrow;
    wasm_module_t* wasm_module_obtain(wasm_store_t*, const(wasm_shared_module_t)*) @nogc nothrow;
    struct wasm_module_t;
    void wasm_shared_module_delete(wasm_shared_module_t*) @nogc nothrow;
    struct wasm_shared_module_t;
    const(wasm_module_t)* wasm_ref_as_module_const(const(wasm_ref_t)*) @nogc nothrow;
    const(wasm_ref_t)* wasm_module_as_ref_const(const(wasm_module_t)*) @nogc nothrow;
    wasm_module_t* wasm_ref_as_module(wasm_ref_t*) @nogc nothrow;
    wasm_ref_t* wasm_module_as_ref(wasm_module_t*) @nogc nothrow;
    void wasm_module_set_host_info_with_finalizer(wasm_module_t*, void*, void function(void*)) @nogc nothrow;
    void wasm_module_set_host_info(wasm_module_t*, void*) @nogc nothrow;
    void* wasm_module_get_host_info(const(wasm_module_t)*) @nogc nothrow;
    bool wasm_module_same(const(wasm_module_t)*, const(wasm_module_t)*) @nogc nothrow;
    wasm_module_t* wasm_module_copy(const(wasm_module_t)*) @nogc nothrow;
    void wasm_module_delete(wasm_module_t*) @nogc nothrow;
    wasm_shared_module_t* wasm_module_share(const(wasm_module_t)*) @nogc nothrow;
    wasm_module_t* wasm_module_new(wasm_store_t*, const(wasm_byte_vec_t)*) @nogc nothrow;
    bool wasm_module_validate(wasm_store_t*, const(wasm_byte_vec_t)*) @nogc nothrow;
    void wasm_module_imports(const(wasm_module_t)*, wasm_importtype_vec_t*) @nogc nothrow;
    void wasm_module_exports(const(wasm_module_t)*, wasm_exporttype_vec_t*) @nogc nothrow;
    void wasm_module_serialize(const(wasm_module_t)*, wasm_byte_vec_t*) @nogc nothrow;
    wasm_module_t* wasm_module_deserialize(wasm_store_t*, const(wasm_byte_vec_t)*) @nogc nothrow;
    struct wasm_func_t;
    const(wasm_func_t)* wasm_ref_as_func_const(const(wasm_ref_t)*) @nogc nothrow;
    void wasm_func_delete(wasm_func_t*) @nogc nothrow;
    const(wasm_ref_t)* wasm_func_as_ref_const(const(wasm_func_t)*) @nogc nothrow;
    wasm_func_t* wasm_func_copy(const(wasm_func_t)*) @nogc nothrow;
    bool wasm_func_same(const(wasm_func_t)*, const(wasm_func_t)*) @nogc nothrow;
    void* wasm_func_get_host_info(const(wasm_func_t)*) @nogc nothrow;
    void wasm_func_set_host_info(wasm_func_t*, void*) @nogc nothrow;
    void wasm_func_set_host_info_with_finalizer(wasm_func_t*, void*, void function(void*)) @nogc nothrow;
    wasm_ref_t* wasm_func_as_ref(wasm_func_t*) @nogc nothrow;
    wasm_func_t* wasm_ref_as_func(wasm_ref_t*) @nogc nothrow;
    alias wasm_func_callback_t = wasm_trap_t* function(const(wasm_val_vec_t)*, wasm_val_vec_t*);
    alias wasm_func_callback_with_env_t = wasm_trap_t* function(void*, const(wasm_val_vec_t)*, wasm_val_vec_t*);
    wasm_func_t* wasm_func_new(wasm_store_t*, const(wasm_functype_t)*, wasm_trap_t* function(const(wasm_val_vec_t)*, wasm_val_vec_t*)) @nogc nothrow;
    wasm_func_t* wasm_func_new_with_env(wasm_store_t*, const(wasm_functype_t)*, wasm_trap_t* function(void*, const(wasm_val_vec_t)*, wasm_val_vec_t*), void*, void function(void*)) @nogc nothrow;
    wasm_functype_t* wasm_func_type(const(wasm_func_t)*) @nogc nothrow;
    c_ulong wasm_func_param_arity(const(wasm_func_t)*) @nogc nothrow;
    c_ulong wasm_func_result_arity(const(wasm_func_t)*) @nogc nothrow;
    wasm_trap_t* wasm_func_call(const(wasm_func_t)*, const(wasm_val_vec_t)*, wasm_val_vec_t*) @nogc nothrow;
    struct wasm_global_t;
    void wasm_global_delete(wasm_global_t*) @nogc nothrow;
    wasm_global_t* wasm_global_copy(const(wasm_global_t)*) @nogc nothrow;
    bool wasm_global_same(const(wasm_global_t)*, const(wasm_global_t)*) @nogc nothrow;
    void* wasm_global_get_host_info(const(wasm_global_t)*) @nogc nothrow;
    void wasm_global_set_host_info(wasm_global_t*, void*) @nogc nothrow;
    void wasm_global_set_host_info_with_finalizer(wasm_global_t*, void*, void function(void*)) @nogc nothrow;
    wasm_ref_t* wasm_global_as_ref(wasm_global_t*) @nogc nothrow;
    wasm_global_t* wasm_ref_as_global(wasm_ref_t*) @nogc nothrow;
    const(wasm_ref_t)* wasm_global_as_ref_const(const(wasm_global_t)*) @nogc nothrow;
    const(wasm_global_t)* wasm_ref_as_global_const(const(wasm_ref_t)*) @nogc nothrow;
    wasm_global_t* wasm_global_new(wasm_store_t*, const(wasm_globaltype_t)*, const(wasm_val_t)*) @nogc nothrow;
    wasm_globaltype_t* wasm_global_type(const(wasm_global_t)*) @nogc nothrow;
    void wasm_global_get(const(wasm_global_t)*, wasm_val_t*) @nogc nothrow;
    void wasm_global_set(wasm_global_t*, const(wasm_val_t)*) @nogc nothrow;
    struct wasm_table_t;
    void wasm_table_set_host_info(wasm_table_t*, void*) @nogc nothrow;
    void wasm_table_set_host_info_with_finalizer(wasm_table_t*, void*, void function(void*)) @nogc nothrow;
    wasm_ref_t* wasm_table_as_ref(wasm_table_t*) @nogc nothrow;
    wasm_table_t* wasm_ref_as_table(wasm_ref_t*) @nogc nothrow;
    const(wasm_ref_t)* wasm_table_as_ref_const(const(wasm_table_t)*) @nogc nothrow;
    const(wasm_table_t)* wasm_ref_as_table_const(const(wasm_ref_t)*) @nogc nothrow;
    void* wasm_table_get_host_info(const(wasm_table_t)*) @nogc nothrow;
    bool wasm_table_same(const(wasm_table_t)*, const(wasm_table_t)*) @nogc nothrow;
    wasm_table_t* wasm_table_copy(const(wasm_table_t)*) @nogc nothrow;
    void wasm_table_delete(wasm_table_t*) @nogc nothrow;
    alias wasm_table_size_t = uint;
    wasm_table_t* wasm_table_new(wasm_store_t*, const(wasm_tabletype_t)*, wasm_ref_t*) @nogc nothrow;
    wasm_tabletype_t* wasm_table_type(const(wasm_table_t)*) @nogc nothrow;
    wasm_ref_t* wasm_table_get(const(wasm_table_t)*, uint) @nogc nothrow;
    bool wasm_table_set(wasm_table_t*, uint, wasm_ref_t*) @nogc nothrow;
    uint wasm_table_size(const(wasm_table_t)*) @nogc nothrow;
    bool wasm_table_grow(wasm_table_t*, uint, wasm_ref_t*) @nogc nothrow;
    const(wasm_memory_t)* wasm_ref_as_memory_const(const(wasm_ref_t)*) @nogc nothrow;
    const(wasm_ref_t)* wasm_memory_as_ref_const(const(wasm_memory_t)*) @nogc nothrow;
    wasm_memory_t* wasm_ref_as_memory(wasm_ref_t*) @nogc nothrow;
    wasm_ref_t* wasm_memory_as_ref(wasm_memory_t*) @nogc nothrow;
    void wasm_memory_set_host_info_with_finalizer(wasm_memory_t*, void*, void function(void*)) @nogc nothrow;
    void wasm_memory_set_host_info(wasm_memory_t*, void*) @nogc nothrow;
    void* wasm_memory_get_host_info(const(wasm_memory_t)*) @nogc nothrow;
    bool wasm_memory_same(const(wasm_memory_t)*, const(wasm_memory_t)*) @nogc nothrow;
    wasm_memory_t* wasm_memory_copy(const(wasm_memory_t)*) @nogc nothrow;
    void wasm_memory_delete(wasm_memory_t*) @nogc nothrow;
    struct wasm_memory_t;
    alias wasm_memory_pages_t = uint;
    extern __gshared const(c_ulong) MEMORY_PAGE_SIZE;
    wasm_memory_t* wasm_memory_new(wasm_store_t*, const(wasm_memorytype_t)*) @nogc nothrow;
    wasm_memorytype_t* wasm_memory_type(const(wasm_memory_t)*) @nogc nothrow;
    char* wasm_memory_data(wasm_memory_t*) @nogc nothrow;
    c_ulong wasm_memory_data_size(const(wasm_memory_t)*) @nogc nothrow;
    uint wasm_memory_size(const(wasm_memory_t)*) @nogc nothrow;
    bool wasm_memory_grow(wasm_memory_t*, uint) @nogc nothrow;
    struct wasm_extern_t;
    void wasm_extern_delete(wasm_extern_t*) @nogc nothrow;
    wasm_extern_t* wasm_extern_copy(const(wasm_extern_t)*) @nogc nothrow;
    bool wasm_extern_same(const(wasm_extern_t)*, const(wasm_extern_t)*) @nogc nothrow;
    void* wasm_extern_get_host_info(const(wasm_extern_t)*) @nogc nothrow;
    void wasm_extern_set_host_info(wasm_extern_t*, void*) @nogc nothrow;
    void wasm_extern_set_host_info_with_finalizer(wasm_extern_t*, void*, void function(void*)) @nogc nothrow;
    wasm_ref_t* wasm_extern_as_ref(wasm_extern_t*) @nogc nothrow;
    wasm_extern_t* wasm_ref_as_extern(wasm_ref_t*) @nogc nothrow;
    const(wasm_ref_t)* wasm_extern_as_ref_const(const(wasm_extern_t)*) @nogc nothrow;
    const(wasm_extern_t)* wasm_ref_as_extern_const(const(wasm_ref_t)*) @nogc nothrow;
    void wasm_extern_vec_new_empty(wasm_extern_vec_t*) @nogc nothrow;
    void wasm_extern_vec_delete(wasm_extern_vec_t*) @nogc nothrow;
    void wasm_extern_vec_copy(wasm_extern_vec_t*, const(wasm_extern_vec_t)*) @nogc nothrow;
    void wasm_extern_vec_new(wasm_extern_vec_t*, c_ulong, wasm_extern_t**) @nogc nothrow;
    void wasm_extern_vec_new_uninitialized(wasm_extern_vec_t*, c_ulong) @nogc nothrow;
    struct wasm_extern_vec_t
    {
        c_ulong size;
        wasm_extern_t** data;
    }
    ubyte wasm_extern_kind(const(wasm_extern_t)*) @nogc nothrow;
    wasm_externtype_t* wasm_extern_type(const(wasm_extern_t)*) @nogc nothrow;
    wasm_extern_t* wasm_func_as_extern(wasm_func_t*) @nogc nothrow;
    wasm_extern_t* wasm_global_as_extern(wasm_global_t*) @nogc nothrow;
    wasm_extern_t* wasm_table_as_extern(wasm_table_t*) @nogc nothrow;
    wasm_extern_t* wasm_memory_as_extern(wasm_memory_t*) @nogc nothrow;
    wasm_func_t* wasm_extern_as_func(wasm_extern_t*) @nogc nothrow;
    wasm_global_t* wasm_extern_as_global(wasm_extern_t*) @nogc nothrow;
    wasm_table_t* wasm_extern_as_table(wasm_extern_t*) @nogc nothrow;
    wasm_memory_t* wasm_extern_as_memory(wasm_extern_t*) @nogc nothrow;
    const(wasm_extern_t)* wasm_func_as_extern_const(const(wasm_func_t)*) @nogc nothrow;
    const(wasm_extern_t)* wasm_global_as_extern_const(const(wasm_global_t)*) @nogc nothrow;
    const(wasm_extern_t)* wasm_table_as_extern_const(const(wasm_table_t)*) @nogc nothrow;
    const(wasm_extern_t)* wasm_memory_as_extern_const(const(wasm_memory_t)*) @nogc nothrow;
    const(wasm_func_t)* wasm_extern_as_func_const(const(wasm_extern_t)*) @nogc nothrow;
    const(wasm_global_t)* wasm_extern_as_global_const(const(wasm_extern_t)*) @nogc nothrow;
    const(wasm_table_t)* wasm_extern_as_table_const(const(wasm_extern_t)*) @nogc nothrow;
    const(wasm_memory_t)* wasm_extern_as_memory_const(const(wasm_extern_t)*) @nogc nothrow;
    void wasm_instance_delete(wasm_instance_t*) @nogc nothrow;
    wasm_instance_t* wasm_instance_copy(const(wasm_instance_t)*) @nogc nothrow;
    bool wasm_instance_same(const(wasm_instance_t)*, const(wasm_instance_t)*) @nogc nothrow;
    void* wasm_instance_get_host_info(const(wasm_instance_t)*) @nogc nothrow;
    void wasm_instance_set_host_info(wasm_instance_t*, void*) @nogc nothrow;
    void wasm_instance_set_host_info_with_finalizer(wasm_instance_t*, void*, void function(void*)) @nogc nothrow;
    wasm_ref_t* wasm_instance_as_ref(wasm_instance_t*) @nogc nothrow;
    wasm_instance_t* wasm_ref_as_instance(wasm_ref_t*) @nogc nothrow;
    const(wasm_ref_t)* wasm_instance_as_ref_const(const(wasm_instance_t)*) @nogc nothrow;
    const(wasm_instance_t)* wasm_ref_as_instance_const(const(wasm_ref_t)*) @nogc nothrow;
    wasm_instance_t* wasm_instance_new(wasm_store_t*, const(wasm_module_t)*, const(wasm_extern_vec_t)*, wasm_trap_t**) @nogc nothrow;
    void wasm_instance_exports(const(wasm_instance_t)*, wasm_extern_vec_t*) @nogc nothrow;
    alias __off64_t = c_long;
    alias __off_t = c_long;
    alias __nlink_t = c_ulong;
    alias __mode_t = uint;
    alias __ino64_t = c_ulong;
    alias __ino_t = c_ulong;
    alias wasmer_compiler_t = _Anonymous_2;
    enum _Anonymous_2
    {
        CRANELIFT = 0,
        LLVM = 1,
        SINGLEPASS = 2,
    }
    enum CRANELIFT = _Anonymous_2.CRANELIFT;
    enum LLVM = _Anonymous_2.LLVM;
    enum SINGLEPASS = _Anonymous_2.SINGLEPASS;
    alias wasmer_engine_t = _Anonymous_3;
    enum _Anonymous_3
    {
        JIT = 0,
        NATIVE = 1,
        OBJECT_FILE = 2,
    }
    enum JIT = _Anonymous_3.JIT;
    enum NATIVE = _Anonymous_3.NATIVE;
    enum OBJECT_FILE = _Anonymous_3.OBJECT_FILE;
    struct wasi_config_t {
      bool inherit_stdout;
      bool inherit_stderr;
      bool inherit_stdin;
    }
    struct wasi_env_t;
    enum wasi_version_t : uint32_t {
      Latest = 0,
      Snapshot0 = 1,
      Snapshot1 = 2,
      InvalidVersion = uint32_t.max,
    }
    void wasi_config_arg(wasi_config_t*, const(char)*) @nogc nothrow;
    void wasi_config_env(wasi_config_t*, const(char)*, const(char)*) @nogc nothrow;
    void wasi_config_inherit_stderr(wasi_config_t*) @nogc nothrow;
    void wasi_config_inherit_stdin(wasi_config_t*) @nogc nothrow;
    void wasi_config_inherit_stdout(wasi_config_t*) @nogc nothrow;
    bool wasi_config_mapdir(wasi_config_t*, const(char)*, const(char)*) @nogc nothrow;
    wasi_config_t* wasi_config_new(const(char)*) @nogc nothrow;
    bool wasi_config_preopen_dir(wasi_config_t*, const(char)*) @nogc nothrow;
    void wasi_env_delete(wasi_env_t*) @nogc nothrow;
    wasi_env_t* wasi_env_new(wasi_config_t*) @nogc nothrow;
    c_long wasi_env_read_stderr(wasi_env_t*, char*, c_ulong) @nogc nothrow;
    c_long wasi_env_read_stdout(wasi_env_t*, char*, c_ulong) @nogc nothrow;
    bool wasi_env_set_instance(wasi_env_t*, const(wasm_instance_t)*) @nogc nothrow;
    void wasi_env_set_memory(wasi_env_t*, const(wasm_memory_t)*) @nogc nothrow;
    bool wasi_get_imports(const(wasm_store_t)*, const(wasm_module_t)*, const(wasi_env_t)*, wasm_extern_vec_t*) @nogc nothrow;
    wasm_func_t* wasi_get_start_function(wasm_instance_t*) @nogc nothrow;
    wasi_version_t wasi_get_wasi_version(const(wasm_module_t)*) @nogc nothrow;
    void wasm_config_set_compiler(wasm_config_t*, wasmer_compiler_t) @nogc nothrow;
    void wasm_config_set_engine(wasm_config_t*, wasmer_engine_t) @nogc nothrow;
    void wasm_module_name(const(wasm_module_t)*, wasm_byte_vec_t*) @nogc nothrow;
    bool wasm_module_set_name(wasm_module_t*, const(wasm_byte_vec_t)*) @nogc nothrow;
    int wasmer_last_error_length() @nogc nothrow;
    int wasmer_last_error_message(char*, int) @nogc nothrow;
    const(char)* wasmer_version() @nogc nothrow;
    ubyte wasmer_version_major() @nogc nothrow;
    ubyte wasmer_version_minor() @nogc nothrow;
    ubyte wasmer_version_patch() @nogc nothrow;
    const(char)* wasmer_version_pre() @nogc nothrow;
    void wat2wasm(const(wasm_byte_vec_t)*, wasm_byte_vec_t*) @nogc nothrow;
    alias __gid_t = uint;
    void* alloca(c_ulong) @nogc nothrow;
    alias __uid_t = uint;
    void __assert_fail(const(char)*, const(char)*, uint, const(char)*) @nogc nothrow;
    void __assert_perror_fail(int, const(char)*, uint, const(char)*) @nogc nothrow;
    void __assert(const(char)*, const(char)*, int) @nogc nothrow;
    alias __dev_t = c_ulong;
    alias __uintmax_t = c_ulong;
    alias __intmax_t = c_long;
    alias __u_quad_t = c_ulong;
    alias __quad_t = c_long;
    alias __uint64_t = c_ulong;
    alias __int64_t = c_long;
    alias __uint32_t = uint;
    alias __int32_t = int;
    alias __uint16_t = ushort;
    alias __int16_t = short;
    alias __uint8_t = ubyte;
    alias __int8_t = byte;
    alias __u_long = c_ulong;
    alias __u_int = uint;
    alias __u_short = ushort;
    alias __u_char = ubyte;
    struct __pthread_cond_s
    {
        static union _Anonymous_4
        {
            ulong __wseq;
            static struct _Anonymous_5
            {
                uint __low;
                uint __high;
            }
            _Anonymous_5 __wseq32;
        }
        _Anonymous_4 _anonymous_6;
        auto __wseq() @property @nogc pure nothrow { return _anonymous_6.__wseq; }
        void __wseq(_T_)(auto ref _T_ val) @property @nogc pure nothrow { _anonymous_6.__wseq = val; }
        auto __wseq32() @property @nogc pure nothrow { return _anonymous_6.__wseq32; }
        void __wseq32(_T_)(auto ref _T_ val) @property @nogc pure nothrow { _anonymous_6.__wseq32 = val; }
        static union _Anonymous_7
        {
            ulong __g1_start;
            static struct _Anonymous_8
            {
                uint __low;
                uint __high;
            }
            _Anonymous_8 __g1_start32;
        }
        _Anonymous_7 _anonymous_9;
        auto __g1_start() @property @nogc pure nothrow { return _anonymous_9.__g1_start; }
        void __g1_start(_T_)(auto ref _T_ val) @property @nogc pure nothrow { _anonymous_9.__g1_start = val; }
        auto __g1_start32() @property @nogc pure nothrow { return _anonymous_9.__g1_start32; }
        void __g1_start32(_T_)(auto ref _T_ val) @property @nogc pure nothrow { _anonymous_9.__g1_start32 = val; }
        uint[2] __g_refs;
        uint[2] __g_size;
        uint __g1_orig_size;
        uint __wrefs;
        uint[2] __g_signals;
    }
    struct __pthread_mutex_s
    {
        int __lock;
        uint __count;
        int __owner;
        uint __nusers;
        int __kind;
        short __spins;
        short __elision;
        __pthread_internal_list __list;
    }
    struct __pthread_internal_list
    {
        __pthread_internal_list* __prev;
        __pthread_internal_list* __next;
    }
    alias __pthread_list_t = __pthread_internal_list;
    alias uint64_t = ulong;
    alias uint32_t = uint;
    alias uint16_t = ushort;
    alias uint8_t = ubyte;
    alias int64_t = c_long;
    alias int32_t = int;
    alias int16_t = short;
    alias int8_t = byte;
    union pthread_barrierattr_t
    {
        char[4] __size;
        int __align;
    }
    alias int_least8_t = byte;
    alias int_least16_t = short;
    alias int_least32_t = int;
    alias int_least64_t = c_long;
    alias uint_least8_t = ubyte;
    alias uint_least16_t = ushort;
    alias uint_least32_t = uint;
    alias uint_least64_t = c_ulong;
    alias int_fast8_t = byte;
    alias int_fast16_t = c_long;
    alias int_fast32_t = c_long;
    alias int_fast64_t = c_long;
    alias uint_fast8_t = ubyte;
    alias uint_fast16_t = c_ulong;
    alias uint_fast32_t = c_ulong;
    alias uint_fast64_t = c_ulong;
    alias intptr_t = c_long;
    alias uintptr_t = c_ulong;
    alias intmax_t = c_long;
    alias uintmax_t = c_ulong;
    union pthread_barrier_t
    {
        char[32] __size;
        c_long __align;
    }
    alias pthread_spinlock_t = int;
    union pthread_rwlockattr_t
    {
        char[8] __size;
        c_long __align;
    }
    union pthread_rwlock_t
    {
        __pthread_rwlock_arch_t __data;
        char[56] __size;
        c_long __align;
    }
    union pthread_cond_t
    {
        __pthread_cond_s __data;
        char[48] __size;
        long __align;
    }
    union pthread_mutex_t
    {
        __pthread_mutex_s __data;
        char[40] __size;
        c_long __align;
    }
    union pthread_attr_t
    {
        char[56] __size;
        c_long __align;
    }
    alias pthread_once_t = int;
    alias pthread_key_t = uint;
    union pthread_condattr_t
    {
        char[4] __size;
        int __align;
    }
    union pthread_mutexattr_t
    {
        char[4] __size;
        int __align;
    }
    alias pthread_t = c_ulong;
    struct __pthread_rwlock_arch_t
    {
        uint __readers;
        uint __writers;
        uint __wrphase_futex;
        uint __writers_futex;
        uint __pad3;
        uint __pad4;
        int __cur_writer;
        int __shared;
        byte __rwelision;
        ubyte[7] __pad1;
        c_ulong __pad2;
        uint __flags;
    }
    alias _Float64x = real;
    alias _Float32x = double;
    alias _Float64 = double;
    alias _Float32 = float;
    struct div_t
    {
        int quot;
        int rem;
    }
    struct ldiv_t
    {
        c_long quot;
        c_long rem;
    }
    struct lldiv_t
    {
        long quot;
        long rem;
    }
    c_ulong __ctype_get_mb_cur_max() @nogc nothrow;
    double atof(const(char)*) @nogc nothrow;
    int atoi(const(char)*) @nogc nothrow;
    c_long atol(const(char)*) @nogc nothrow;
    long atoll(const(char)*) @nogc nothrow;
    double strtod(const(char)*, char**) @nogc nothrow;
    float strtof(const(char)*, char**) @nogc nothrow;
    real strtold(const(char)*, char**) @nogc nothrow;
    c_long strtol(const(char)*, char**, int) @nogc nothrow;
    c_ulong strtoul(const(char)*, char**, int) @nogc nothrow;
    long strtoq(const(char)*, char**, int) @nogc nothrow;
    ulong strtouq(const(char)*, char**, int) @nogc nothrow;
    long strtoll(const(char)*, char**, int) @nogc nothrow;
    ulong strtoull(const(char)*, char**, int) @nogc nothrow;
    char* l64a(c_long) @nogc nothrow;
    c_long a64l(const(char)*) @nogc nothrow;
    c_long random() @nogc nothrow;
    void srandom(uint) @nogc nothrow;
    char* initstate(uint, char*, c_ulong) @nogc nothrow;
    char* setstate(char*) @nogc nothrow;
    struct random_data
    {
        int* fptr;
        int* rptr;
        int* state;
        int rand_type;
        int rand_deg;
        int rand_sep;
        int* end_ptr;
    }
    int random_r(random_data*, int*) @nogc nothrow;
    int srandom_r(uint, random_data*) @nogc nothrow;
    int initstate_r(uint, char*, c_ulong, random_data*) @nogc nothrow;
    int setstate_r(char*, random_data*) @nogc nothrow;
    int rand() @nogc nothrow;
    void srand(uint) @nogc nothrow;
    int rand_r(uint*) @nogc nothrow;
    double drand48() @nogc nothrow;
    double erand48(ushort*) @nogc nothrow;
    c_long lrand48() @nogc nothrow;
    c_long nrand48(ushort*) @nogc nothrow;
    c_long mrand48() @nogc nothrow;
    c_long jrand48(ushort*) @nogc nothrow;
    void srand48(c_long) @nogc nothrow;
    ushort* seed48(ushort*) @nogc nothrow;
    void lcong48(ushort*) @nogc nothrow;
    struct drand48_data
    {
        ushort[3] __x;
        ushort[3] __old_x;
        ushort __c;
        ushort __init;
        ulong __a;
    }
    int drand48_r(drand48_data*, double*) @nogc nothrow;
    int erand48_r(ushort*, drand48_data*, double*) @nogc nothrow;
    int lrand48_r(drand48_data*, c_long*) @nogc nothrow;
    int nrand48_r(ushort*, drand48_data*, c_long*) @nogc nothrow;
    int mrand48_r(drand48_data*, c_long*) @nogc nothrow;
    int jrand48_r(ushort*, drand48_data*, c_long*) @nogc nothrow;
    int srand48_r(c_long, drand48_data*) @nogc nothrow;
    int seed48_r(ushort*, drand48_data*) @nogc nothrow;
    int lcong48_r(ushort*, drand48_data*) @nogc nothrow;
    void* malloc(c_ulong) @nogc nothrow;
    void* calloc(c_ulong, c_ulong) @nogc nothrow;
    void* realloc(void*, c_ulong) @nogc nothrow;
    void free(void*) @nogc nothrow;
    void* valloc(c_ulong) @nogc nothrow;
    int posix_memalign(void**, c_ulong, c_ulong) @nogc nothrow;
    void* aligned_alloc(c_ulong, c_ulong) @nogc nothrow;
    void abort() @nogc nothrow;
    int atexit(void function()) @nogc nothrow;
    int at_quick_exit(void function()) @nogc nothrow;
    int on_exit(void function(int, void*), void*) @nogc nothrow;
    void exit(int) @nogc nothrow;
    void quick_exit(int) @nogc nothrow;
    void _Exit(int) @nogc nothrow;
    char* getenv(const(char)*) @nogc nothrow;
    int putenv(char*) @nogc nothrow;
    int setenv(const(char)*, const(char)*, int) @nogc nothrow;
    int unsetenv(const(char)*) @nogc nothrow;
    int clearenv() @nogc nothrow;
    char* mktemp(char*) @nogc nothrow;
    int mkstemp(char*) @nogc nothrow;
    int mkstemps(char*, int) @nogc nothrow;
    char* mkdtemp(char*) @nogc nothrow;
    int system(const(char)*) @nogc nothrow;
    char* realpath(const(char)*, char*) @nogc nothrow;
    alias __compar_fn_t = int function(const(void)*, const(void)*);
    void* bsearch(const(void)*, const(void)*, c_ulong, c_ulong, int function(const(void)*, const(void)*)) @nogc nothrow;
    void qsort(void*, c_ulong, c_ulong, int function(const(void)*, const(void)*)) @nogc nothrow;
    int abs(int) @nogc nothrow;
    c_long labs(c_long) @nogc nothrow;
    long llabs(long) @nogc nothrow;
    div_t div(int, int) @nogc nothrow;
    ldiv_t ldiv(c_long, c_long) @nogc nothrow;
    lldiv_t lldiv(long, long) @nogc nothrow;
    char* ecvt(double, int, int*, int*) @nogc nothrow;
    char* fcvt(double, int, int*, int*) @nogc nothrow;
    char* gcvt(double, int, char*) @nogc nothrow;
    char* qecvt(real, int, int*, int*) @nogc nothrow;
    char* qfcvt(real, int, int*, int*) @nogc nothrow;
    char* qgcvt(real, int, char*) @nogc nothrow;
    int ecvt_r(double, int, int*, int*, char*, c_ulong) @nogc nothrow;
    int fcvt_r(double, int, int*, int*, char*, c_ulong) @nogc nothrow;
    int qecvt_r(real, int, int*, int*, char*, c_ulong) @nogc nothrow;
    int qfcvt_r(real, int, int*, int*, char*, c_ulong) @nogc nothrow;
    int mblen(const(char)*, c_ulong) @nogc nothrow;
    int mbtowc(int*, const(char)*, c_ulong) @nogc nothrow;
    int wctomb(char*, int) @nogc nothrow;
    c_ulong mbstowcs(int*, const(char)*, c_ulong) @nogc nothrow;
    c_ulong wcstombs(char*, const(int)*, c_ulong) @nogc nothrow;
    int rpmatch(const(char)*) @nogc nothrow;
    int getsubopt(char**, char**, char**) @nogc nothrow;
    int getloadavg(double*, int) @nogc nothrow;
    void* memcpy(void*, const(void)*, c_ulong) @nogc nothrow;
    void* memmove(void*, const(void)*, c_ulong) @nogc nothrow;
    void* memccpy(void*, const(void)*, int, c_ulong) @nogc nothrow;
    void* memset(void*, int, c_ulong) @nogc nothrow;
    int memcmp(const(void)*, const(void)*, c_ulong) @nogc nothrow;
    void* memchr(const(void)*, int, c_ulong) @nogc nothrow;
    char* strcpy(char*, const(char)*) @nogc nothrow;
    char* strncpy(char*, const(char)*, c_ulong) @nogc nothrow;
    char* strcat(char*, const(char)*) @nogc nothrow;
    char* strncat(char*, const(char)*, c_ulong) @nogc nothrow;
    int strcmp(const(char)*, const(char)*) @nogc nothrow;
    int strncmp(const(char)*, const(char)*, c_ulong) @nogc nothrow;
    int strcoll(const(char)*, const(char)*) @nogc nothrow;
    c_ulong strxfrm(char*, const(char)*, c_ulong) @nogc nothrow;
    int strcoll_l(const(char)*, const(char)*, __locale_struct*) @nogc nothrow;
    c_ulong strxfrm_l(char*, const(char)*, c_ulong, __locale_struct*) @nogc nothrow;
    char* strdup(const(char)*) @nogc nothrow;
    char* strndup(const(char)*, c_ulong) @nogc nothrow;
    char* strchr(const(char)*, int) @nogc nothrow;
    char* strrchr(const(char)*, int) @nogc nothrow;
    c_ulong strcspn(const(char)*, const(char)*) @nogc nothrow;
    c_ulong strspn(const(char)*, const(char)*) @nogc nothrow;
    char* strpbrk(const(char)*, const(char)*) @nogc nothrow;
    char* strstr(const(char)*, const(char)*) @nogc nothrow;
    char* strtok(char*, const(char)*) @nogc nothrow;
    char* __strtok_r(char*, const(char)*, char**) @nogc nothrow;
    char* strtok_r(char*, const(char)*, char**) @nogc nothrow;
    c_ulong strlen(const(char)*) @nogc nothrow;
    c_ulong strnlen(const(char)*, c_ulong) @nogc nothrow;
    char* strerror(int) @nogc nothrow;
    int strerror_r(int, char*, c_ulong) @nogc nothrow;
    char* strerror_l(int, __locale_struct*) @nogc nothrow;
    void explicit_bzero(void*, c_ulong) @nogc nothrow;
    char* strsep(char**, const(char)*) @nogc nothrow;
    char* strsignal(int) @nogc nothrow;
    char* __stpcpy(char*, const(char)*) @nogc nothrow;
    char* stpcpy(char*, const(char)*) @nogc nothrow;
    char* __stpncpy(char*, const(char)*, c_ulong) @nogc nothrow;
    char* stpncpy(char*, const(char)*, c_ulong) @nogc nothrow;
    int bcmp(const(void)*, const(void)*, c_ulong) @nogc nothrow;
    void bcopy(const(void)*, void*, c_ulong) @nogc nothrow;
    void bzero(void*, c_ulong) @nogc nothrow;
    char* index(const(char)*, int) @nogc nothrow;
    char* rindex(const(char)*, int) @nogc nothrow;
    int ffs(int) @nogc nothrow;
    int ffsl(c_long) @nogc nothrow;
    int ffsll(long) @nogc nothrow;
    int strcasecmp(const(char)*, const(char)*) @nogc nothrow;
    int strncasecmp(const(char)*, const(char)*, c_ulong) @nogc nothrow;
    int strcasecmp_l(const(char)*, const(char)*, __locale_struct*) @nogc nothrow;
    int strncasecmp_l(const(char)*, const(char)*, c_ulong, __locale_struct*) @nogc nothrow;
}


