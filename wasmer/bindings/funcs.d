/// Convenience functions
///
/// See_Also:
/// $(UL
///   $(LI <a href="https://github.com/chances/wasmer-d/blob/26a3cb32c79508dc2b8b33e9d2d176a3d6debdf1/source/wasmer/bindings/funcs.d">`wasmer.bindings.funcs` Source Code</a>)
///   $(LI <a href="https://github.com/wasmerio/wasmer/blob/b11a3831f75971874bc567ec611f4f4c9e2acdf5/lib/c-api/tests/wasm-c-api/include/wasm.h#L527">wasm.h</a>)
/// )
///
/// Authors: Chance Snow
/// Copyright: Copyright © 2020-2021 Chance Snow. All rights reserved.
/// License: MIT License
module wasmer.bindings.funcs;

import core.stdc.string : strlen;
import std.conv : to;

import wasmer.bindings;

pragma(inline, true):

// Byte vectors

alias wasm_name_new = wasm_byte_vec_new;
alias wasm_name_new_empty = wasm_byte_vec_new_empty;
alias wasm_name_new_new_uninitialized = wasm_byte_vec_new_uninitialized;
alias wasm_name_copy = wasm_byte_vec_copy;
alias wasm_name_delete = wasm_byte_vec_delete;

static void wasm_name_new_from_string(wasm_name_t* name, const char* s) {
  wasm_name_new(name, strlen(s), s);
}

static void wasm_name_new_from_string_nt(wasm_name_t* name, const char* s) {
  wasm_name_new(name, strlen(s) + 1, s);
}

alias wasm_name_delete = wasm_byte_vec_delete;

// Value Type construction short-hands

static wasm_valtype_t* wasm_valtype_new_i32() {
  return wasm_valtype_new(WASM_I32);
}
static wasm_valtype_t* wasm_valtype_new_i64() {
  return wasm_valtype_new(WASM_I64);
}
static wasm_valtype_t* wasm_valtype_new_f32() {
  return wasm_valtype_new(WASM_F32);
}
static wasm_valtype_t* wasm_valtype_new_f64() {
  return wasm_valtype_new(WASM_F64);
}

static wasm_valtype_t* wasm_valtype_new_anyref() {
  return wasm_valtype_new(WASM_ANYREF);
}
static wasm_valtype_t* wasm_valtype_new_funcref() {
  return wasm_valtype_new(WASM_FUNCREF);
}

// Function Types construction short-hands

static wasm_functype_t* wasm_functype_new_0_0() {
  wasm_valtype_vec_t params, results;
  wasm_valtype_vec_new_empty(&params);
  wasm_valtype_vec_new_empty(&results);
  return wasm_functype_new(&params, &results);
}

static wasm_functype_t* wasm_functype_new_1_0(
    wasm_valtype_t* p
) {
  wasm_valtype_t*[1] ps = [p];
  wasm_valtype_vec_t params, results;
  wasm_valtype_vec_new(&params, 1.to!ulong, ps.ptr);
  wasm_valtype_vec_new_empty(&results);
  return wasm_functype_new(&params, &results);
}

static wasm_functype_t* wasm_functype_new_2_0(
    wasm_valtype_t* p1, wasm_valtype_t* p2
) {
  wasm_valtype_t*[2] ps = [p1, p2];
  wasm_valtype_vec_t params, results;
  wasm_valtype_vec_new(&params, 2.to!ulong, ps.ptr);
  wasm_valtype_vec_new_empty(&results);
  return wasm_functype_new(&params, &results);
}

static wasm_functype_t* wasm_functype_new_3_0(
    wasm_valtype_t* p1, wasm_valtype_t* p2, wasm_valtype_t* p3
) {
  wasm_valtype_t*[3] ps = [p1, p2, p3];
  wasm_valtype_vec_t params, results;
  wasm_valtype_vec_new(&params, 3.to!ulong, ps.ptr);
  wasm_valtype_vec_new_empty(&results);
  return wasm_functype_new(&params, &results);
}

static wasm_functype_t* wasm_functype_new_0_1(
    wasm_valtype_t* r
) {
  wasm_valtype_t*[1] rs = [r];
  wasm_valtype_vec_t params, results;
  wasm_valtype_vec_new_empty(&params);
  wasm_valtype_vec_new(&results, 1.to!ulong, rs.ptr);
  return wasm_functype_new(&params, &results);
}

static wasm_functype_t* wasm_functype_new_1_1(
    wasm_valtype_t* p, wasm_valtype_t* r
) {
  wasm_valtype_t*[1] ps = [p];
  wasm_valtype_t*[1] rs = [r];
  wasm_valtype_vec_t params, results;
  wasm_valtype_vec_new(&params, 1.to!ulong, ps.ptr);
  wasm_valtype_vec_new(&results, 1.to!ulong, rs.ptr);
  return wasm_functype_new(&params, &results);
}

static wasm_functype_t* wasm_functype_new_2_1(
    wasm_valtype_t* p1, wasm_valtype_t* p2, wasm_valtype_t* r
) {
  wasm_valtype_t*[2] ps = [p1, p2];
  wasm_valtype_t*[1] rs = [r];
  wasm_valtype_vec_t params, results;
  wasm_valtype_vec_new(&params, 2.to!ulong, ps.ptr);
  wasm_valtype_vec_new(&results, 1.to!ulong, rs.ptr);
  return wasm_functype_new(&params, &results);
}

static wasm_functype_t* wasm_functype_new_3_1(
    wasm_valtype_t* p1, wasm_valtype_t* p2, wasm_valtype_t* p3,
    wasm_valtype_t* r
) {
  wasm_valtype_t*[3] ps = [p1, p2, p3];
  wasm_valtype_t*[1] rs = [r];
  wasm_valtype_vec_t params, results;
  wasm_valtype_vec_new(&params, 3.to!ulong, ps.ptr);
  wasm_valtype_vec_new(&results, 1.to!ulong, rs.ptr);
  return wasm_functype_new(&params, &results);
}

static wasm_functype_t* wasm_functype_new_0_2(
    wasm_valtype_t* r1, wasm_valtype_t* r2
) {
  wasm_valtype_t*[2] rs = [r1, r2];
  wasm_valtype_vec_t params, results;
  wasm_valtype_vec_new_empty(&params);
  wasm_valtype_vec_new(&results, 2.to!ulong, rs.ptr);
  return wasm_functype_new(&params, &results);
}

static wasm_functype_t* wasm_functype_new_1_2(
    wasm_valtype_t* p, wasm_valtype_t* r1, wasm_valtype_t* r2
) {
  wasm_valtype_t*[1] ps = [p];
  wasm_valtype_t*[2] rs = [r1, r2];
  wasm_valtype_vec_t params, results;
  wasm_valtype_vec_new(&params, 1.to!ulong, ps.ptr);
  wasm_valtype_vec_new(&results, 2.to!ulong, rs.ptr);
  return wasm_functype_new(&params, &results);
}

static wasm_functype_t* wasm_functype_new_2_2(
    wasm_valtype_t* p1, wasm_valtype_t* p2,
    wasm_valtype_t* r1, wasm_valtype_t* r2
) {
  wasm_valtype_t*[2] ps = [p1, p2];
  wasm_valtype_t*[2] rs = [r1, r2];
  wasm_valtype_vec_t params, results;
  wasm_valtype_vec_new(&params, 2.to!ulong, ps.ptr);
  wasm_valtype_vec_new(&results, 2.to!ulong, rs.ptr);
  return wasm_functype_new(&params, &results);
}

static wasm_functype_t* wasm_functype_new_3_2(
    wasm_valtype_t* p1, wasm_valtype_t* p2, wasm_valtype_t* p3,
    wasm_valtype_t* r1, wasm_valtype_t* r2
) {
  wasm_valtype_t*[3] ps = [p1, p2, p3];
  wasm_valtype_t*[2] rs = [r1, r2];
  wasm_valtype_vec_t params, results;
  wasm_valtype_vec_new(&params, 3.to!ulong, ps.ptr);
  wasm_valtype_vec_new(&results, 2.to!ulong, rs.ptr);
  return wasm_functype_new(&params, &results);
}

// Value construction short-hands

static void wasm_val_init_ptr(wasm_val_t* out_, void* p) {
  import core.stdc.config : c_long;

  out_.kind = WASM_I64;
  out_.of.i64 = cast(c_long) p;
}

static void* wasm_val_ptr(const wasm_val_t* val) {
  return cast(void*) &val.of.i64;
}
