/// Wasmer Engine API
///
/// An idiomatic D wrapper of the <a href="https://github.com/wasmerio/wasmer/tree/master/lib/c-api#readme">Wasmer Runtime</a> providing an implementation of the <a href="https://github.com/WebAssembly/wasm-c-api#readme">WebAssembly C API</a>.
///
/// See_Also: The official <a href="https://github.com/wasmerio/wasmer/tree/master/lib/c-api#readme">Wasmer Runtime C API</a> documentation.
///
/// Authors: Chance Snow
/// Copyright: Copyright © 2020-2021 Chance Snow. All rights reserved.
/// License: MIT License
module wasmer;

import std.conv : to;
import std.traits : isCallable, Parameters;

public import std.functional : toDelegate;

public import wasmer.bindings;
public import wasmer.bindings.funcs;

private extern(C) void finalizeHostInfo(T)(void* data) if (is(T == class)) {
  destroy(this.hostInfo!T);
}

/// Manages a native handle to a Wasmer structure.
abstract class Handle(T) if (is(T == struct)) {
  private T* handle_;
  /// Whether this handle was borrowed from the Wasmer runtime. Borrowed handles are not automatically freed in D-land.
  const bool borrowed;

  ///
  this(T* value, bool borrowed = false) {
    handle_ = value;
    this.borrowed = borrowed;
  }
  ~this() {
    handle_ = null;
  }

  /// Whether this managed handle to a Wasmer structure is valid.
  bool valid() @property const {
    return handle_ !is null;
  }

  ///
  T* handle() @property const {
    return cast(T*) handle_;
  }

  /// The last error message that was raised by the Wasmer Runtime.
  string lastError() @property const {
    const size = wasmer_last_error_length();
    auto buf = new char[size];
    wasmer_last_error_message(buf.ptr, size);
    return buf.idup;
  }
}

/// A wasmer engine used to instntiate a `Store`.
final class Engine : Handle!wasm_engine_t {
  /// Instantiate a new wasmer JIT engine with the default compiler.
  this() {
    super(wasm_engine_new());
  }
  private this(wasm_engine_t* engine) {
    super(engine);
  }
  ~this() {
    if (valid) wasm_engine_delete(handle);
  }

  /// Instantiate a new JITed wasmer engine.
  static Engine jit(wasmer_compiler_t compiler = wasmer_compiler_t.CRANELIFT) {
    auto config = wasm_config_new();
    wasm_config_set_engine(config, wasmer_engine_t.JIT);
    wasm_config_set_compiler(config, compiler);

    return new Engine(wasm_engine_new_with_config(config));
  }

  /// Instantiate a new native wasmer engine.
  static Engine native(wasmer_compiler_t compiler = wasmer_compiler_t.CRANELIFT) {
    auto config = wasm_config_new();
    wasm_config_set_engine(config, wasmer_engine_t.NATIVE);
    wasm_config_set_compiler(config, compiler);

    return new Engine(wasm_engine_new_with_config(config));
  }
}

unittest {
  assert(new Engine().valid);
  assert(Engine.jit().valid);
  assert(Engine.native().valid);
}

/// All runtime objects are tied to a specific store.
///
/// The store represents all global state that can be manipulated by WebAssembly programs. It consists of the runtime representation of all instances of functions, tables, memories, and globals that have been allocated during the life time of the abstract machine.
///
/// Multiple stores can be created, but their objects cannot interact. Every store and its objects must only be accessed in a single thread.
///
/// See_Also: <a href="https://webassembly.github.io/spec/core/exec/runtime.html#syntax-store" title="The WebAssembly Specification">Store - WebAssembly 1.1</a>
class Store : Handle!wasm_store_t {
  ///
  const Engine engine;

  ///
  this (Engine engine) {
    this.engine = engine;

    super(wasm_store_new(cast(wasm_engine_t*) engine.handle));
  }
  ~this() {
    if (valid) wasm_store_delete(handle);
  }
}

unittest {
  const store = new Store(new Engine());
  assert(store.valid);
  destroy(store);
}

/// Limits of the page size of a block of `Memory`. One page of memory is 64 kB.
alias Limits = wasm_limits_t;

/// Size in bytes of one page of WebAssembly memory. One page of memory is 64 kB.
enum uint pageSize = 65_536;

/// A block of memory.
class Memory : Handle!wasm_memory_t {
  private wasm_memorytype_t* type;
  ///
  const Limits limits;

  ///
  this(Store store, Limits limits) {
    this.limits = limits;
    type = wasm_memorytype_new(&this.limits);
    super(wasm_memory_new(store.handle, type));
  }
  ~this() {
    if (valid) {
      wasm_memory_delete(handle);
      wasm_memorytype_delete(type);
    }
    type = null;
  }

  /// Whether this managed handle to a `wasm_memory_t` is valid.
  override bool valid() @property const {
    return type !is null && super.valid;
  }

  /// The current length in pages of this block of memory. One page of memory is 64 kB.
  uint pageLength() @property const {
    return wasm_memory_size(handle);
  }

  /// The current length in bytes of this block of memory.
  ulong length() @property const {
    return wasm_memory_data_size(handle);
  }

  ///
  void* ptr() @property const {
    return wasm_memory_data(handle);
  }

  /// A slice of all the data in this block of memory.
  ubyte[] data() @property const {
    return cast(ubyte[]) ptr[0..length];
  }

  /// Grows this block of memory by the given amount of pages.
  /// Returns: Whether this block of memory was successfully grown. Use the `Handle.lastError` property to get more details of the error, if any.
  bool grow(uint deltaPages) {
    return wasm_memory_grow(handle, deltaPages);
  }
}

unittest {
  auto store = new Store(new Engine());
  const maxNumPages = 5;
  auto memory = new Memory(store, Limits(maxNumPages - 1, maxNumPages));

  assert(memory.valid, "Error creating block of memory!");
  assert(memory.pageLength == 4);
  assert(memory.length == 4 * pageSize);
  assert(memory.grow(0));

  assert(memory.grow(1));
  assert(memory.pageLength == 5);
  assert(memory.length == 5 * pageSize);
  assert(!memory.grow(1));

  destroy(memory);
}

/// A WebAssembly module.
class Module : Handle!wasm_module_t {
  private Store _store;

  ///
  this(Store store, ubyte[] wasmBytes) {
    this._store = store;

    wasm_byte_vec_t bytes;
    wasm_byte_vec_new(&bytes, wasmBytes.length, cast(char*) wasmBytes.ptr);

    super(wasm_module_new(store.handle, &bytes));
    wasm_byte_vec_delete(&bytes);
  }
  private this(wasm_module_t* module_) {
    super(module_);
  }
  ~this() {
    if (valid) wasm_module_delete(handle);
  }

  /// Instantiate a module given a string in the WebAssembly <a href="https://webassembly.github.io/spec/core/text/index.html">Text Format</a>.
  static Module from(Store store, string source) {
    wasm_byte_vec_t wat;
    wasm_byte_vec_new(&wat, source.length, source.ptr);
    wasm_byte_vec_t wasmBytes;
    wat2wasm(&wat, &wasmBytes);
    return new Module(store, cast(ubyte[]) wasmBytes.data[0 .. wasmBytes.size]);
  }

  /// Deserializes a module given the bytes of a previously serialized module.
  /// Returns: `null` on error. Use the `Handle.lastError` property to get more details of the error, if any.
  static Module deserialize(Store store, ubyte[] data) {
    wasm_byte_vec_t dataVec = wasm_byte_vec_t(data.length, cast(char*) data.ptr);
    auto module_ = wasm_module_deserialize(store.handle, &dataVec);
    if (module_ == null) return null;
    return new Module(module_);
  }

  /// Validates the given bytes as being a valid WebAssembly module.
  static bool validate(Store store, ubyte[] data) {
    wasm_byte_vec_t dataVec = wasm_byte_vec_t(data.length, cast(char*) data.ptr);
    return wasm_module_validate(store.handle, &dataVec);
  }

  const(Store) store() @property const {
    return _store;
  }

  /// Creates a new `Instance` of this module from the given imports, if any.
  Instance instantiate(Extern[] imports = []) {
    assert(valid);
    return new Instance(_store, this, imports);
  }

  /// Serializes this module, the result can be saved and later deserialized back into an executable module.
  /// Returns: `null` on error. Use the `Handle.lastError` property to get more details of the error, if any.
  ubyte[] serialize() {
    wasm_byte_vec_t dataVec;
    wasm_module_serialize(handle, &dataVec);
    if (dataVec.size == 0 || dataVec.data == null) return null;
    return cast(ubyte[]) dataVec.data[0..dataVec.size];
  }
}

version (unittest) {
  const string wat_sum_module =
    "(module\n" ~
    "  (type $sum_t (func (param i32 i32) (result i32)))\n" ~
    "  (func $sum_f (type $sum_t) (param $x i32) (param $y i32) (result i32)\n" ~
    "    local.get $x\n" ~
    "    local.get $y\n" ~
    "    i32.add)\n" ~
    "  (export \"sum\" (func $sum_f)))";
}

unittest {
  auto engine = new Engine();
  auto store = new Store(engine);
  auto module_ = Module.from(store, wat_sum_module);

  assert(module_.valid, "Error compiling module!");
  assert(module_.instantiate().valid, "Error instantiating module!");

  auto serializedModule = module_.serialize();
  assert(serializedModule !is null, "Error serializing module!");

  assert(Module.deserialize(store, serializedModule).valid, "Error deserializing module!");
}

/// An external value, which is the runtime representation of an entity that can be imported or exported.
///
/// It is an address denoting either a function instance, table instance, memory instance, or global instances in the shared `Store`.
///
/// See_Also: <a href="https://webassembly.github.io/spec/core/exec/runtime.html#external-values" title="The WebAssembly Specifcation">External Values - WebAssembly 1.1</a>
class Extern : Handle!wasm_extern_t {
  private const wasm_exporttype_t* _type;
  ///
  const string name;
  ///
  const wasm_externkind_enum kind;

  private this(wasm_extern_t* extern_, const wasm_exporttype_t* type, string name = "") {
    super(extern_);
    this._type = type;
    this.name = name;
    kind = wasm_extern_kind(extern_).to!wasm_externkind_enum;
  }
  ~this() {
    if (valid) wasm_extern_delete(handle);
  }

  ///
  const(wasm_exporttype_t*) type() @property const {
    return _type;
  }
}

/// A WebAssembly virtual machine instance.
class Instance : Handle!wasm_instance_t {
  private wasm_exporttype_vec_t exportTypes;

  ///
  this(Store store, Module module_, Extern[] imports = []) {
    import std.algorithm : map;
    import std.array : array;

    wasm_extern_vec_t importObject;
    auto importsVecElements = cast(wasm_extern_t**) imports.map!(import_ => import_.handle).array.ptr;
    wasm_extern_vec_new(&importObject, imports.length, importsVecElements);

    super(wasm_instance_new(
      cast(wasm_store_t*) store.handle, cast(wasm_module_t*) module_.handle, &importObject, null
    ));

    // Get exported types
    wasm_module_exports(cast(wasm_module_t*) module_.handle, &exportTypes);
  }
  ~this() {
    if (valid) wasm_instance_delete(handle);
  }

  Extern[] exports() @property const {
    wasm_extern_vec_t exportsVector;
    wasm_instance_exports(handle, &exportsVector);

    auto exports = new Extern[exportsVector.size];
    for (auto i = 0; i < exportsVector.size; i++) {
      const nameVec = wasm_exporttype_name(exportTypes.data[i]);
      const name = cast(string) nameVec.data[0..nameVec.size];

      exports[i] = new Extern(exportsVector.data[i], exportTypes.data[i], name.idup);
    }
    return exports;
  }

  ///
  T hostInfo(T)() @property const {
    return cast(T) wasm_instance_get_host_info(handle);
  }
  ///
  void hostInfo(T)(ref T value) @property {
    static if (is(T == class)) {
      wasm_instance_set_host_info_with_finalizer(handle, &value, &finalizeHostInfo!T);
    } else {
      wasm_instance_set_host_info(handle, &value);
    }
  }
}

unittest {
  auto engine = new Engine();
  auto store = new Store(engine);
  auto module_ = Module.from(store, wat_sum_module);
  auto instance = new Instance(store, module_);

  assert(module_.valid, "Error compiling module!");
  assert(instance.valid, "Error instantiating module!");
  assert(instance.exports.length == 1, "Error accessing exports!");
  assert(instance.exports[0].kind == wasm_externkind_enum.WASM_EXTERN_FUNC);
  assert(instance.exports[0].name == "sum");

  destroy(instance);
  destroy(module_);
  destroy(store);
  destroy(engine);
}

/// A WebAssembly value, wrapping an int, long, float, or double.
class Value : Handle!wasm_val_t {
  ///
  const wasm_valkind_enum kind;

  ///
  this(wasm_valkind_enum kind) {
    this.kind = kind;
    super(new wasm_val_t(kind));
  }
  ///
  this(int value) {
    this.kind = wasm_valkind_enum.WASM_I32;
    super(new wasm_val_t);
    handle.of.i32 = value;
  }
  ///
  this(long value) {
    this.kind = wasm_valkind_enum.WASM_I64;
    super(new wasm_val_t);
    handle.of.i64 = value;
  }
  ///
  this(float value) {
    this.kind = wasm_valkind_enum.WASM_F32;
    super(new wasm_val_t);
    handle.of.f32 = value;
  }
  ///
  this(double value) {
    this.kind = wasm_valkind_enum.WASM_F64;
    super(new wasm_val_t);
    handle.of.f64 = value;
  }
  private this(wasm_val_t value) {
    super(new wasm_val_t(value.kind, value.of));
    this.kind = value.kind.to!wasm_valkind_enum;
  }
  private this(wasm_val_t* value) {
    super(new wasm_val_t, true);
    this.kind = value.kind.to!wasm_valkind_enum;
  }
  ~this() {
    if (valid && borrowed) wasm_val_delete(handle);
  }

  ///
  static Value from(wasm_val_t value) {
    return new Value(value);
  }
  ///
  static Value from(wasm_val_t* value) {
    return new Value(value);
  }

  ///
  auto value() @property const {
    return handle;
  }
}

/// A function to be called from WASM code.
extern(C) alias Callback = wasm_trap_t* function(const wasm_val_vec_t* arguments, wasm_val_vec_t* results);
/// A function to be called from WASM code. Includes an environment variable.
extern(C) alias CallbackWithEnv = wasm_trap_t* function(
  void* env, const wasm_val_vec_t* arguments, wasm_val_vec_t* results
);

/// A delegate to be called from WASM code.
alias CallbackWithDelegate = void delegate(Module module_, Value[] arguments, Value[] results);

private enum bool isInt32(T) = __traits(isSame, T, bool) || __traits(isSame, T, int) || __traits(isSame, T, uint);
private enum bool isInt64(T) = __traits(isSame, T, long) || __traits(isSame, T, ulong);
private enum bool isFloat32(T) = __traits(isSame, T, float);
private enum bool isFloat64(T) = __traits(isSame, T, double);

/// Get the `wasm_functype_t` of a D function that satisfies `isCallableAsFunction`.
wasm_functype_t* functype(Func)(Func _) if (isCallableAsFunction!Func) {
  import std.meta : staticIndexOf;
  import std.traits : ReturnType, Unqual;

  alias Tail(Args...) = Args[1 .. $];
  alias Params = Tail!(Parameters!Func);

  wasm_valtype_vec_t params, results;

  // Params types
  static if (Params.length == 0)
    wasm_valtype_vec_new_empty(&params);
  else {
    wasm_valtype_t*[Params.length] ps;
    static foreach (Param; Params) {
      static if (isInt32!(Unqual!Param))
        ps[staticIndexOf!(Param, Params)] = wasm_valtype_new_i32();
      static if (isInt64!(Unqual!Param))
        ps[staticIndexOf!(Param, Params)] = wasm_valtype_new_i64();
      static if (isFloat32!(Unqual!Param))
        ps[staticIndexOf!(Param, Params)] = wasm_valtype_new_f32();
      static if (isFloat64!(Unqual!Param))
        ps[staticIndexOf!(Param, Params)] = wasm_valtype_new_f64();
    }
    wasm_valtype_vec_new(&params, (Params.length).to!ulong, ps.ptr);
  }

  // Result types
  static if (__traits(isSame, ReturnType!Func, Value)) {
    wasm_valtype_t*[1] rs = [wasm_valtype_new_anyref()];
    wasm_valtype_vec_new(&results, 1.to!ulong, rs.ptr);
  } else static if (isInt32!(ReturnType!Func)) {
    wasm_valtype_t*[1] rs = [wasm_valtype_new_i32()];
    wasm_valtype_vec_new(&results, 1.to!ulong, rs.ptr);
  } else static if (isInt64!(ReturnType!Func)) {
    wasm_valtype_t*[1] rs = [wasm_valtype_new_i64()];
    wasm_valtype_vec_new(&results, 1.to!ulong, rs.ptr);
  } else static if (isFloat32!(ReturnType!Func)) {
    wasm_valtype_t*[1] rs = [wasm_valtype_new_f32()];
    wasm_valtype_vec_new(&results, 1.to!ulong, rs.ptr);
  } else static if (isFloat64!(ReturnType!Func)) {
    wasm_valtype_t*[1] rs = [wasm_valtype_new_f64()];
    wasm_valtype_vec_new(&results, 1.to!ulong, rs.ptr);
  } else static if (__traits(isSame, ReturnType!Func, void))
    wasm_valtype_vec_new_empty(&results);
  else static assert(0, "Unsupported function return type!");

  return wasm_functype_new(&params, &results);
}

private struct CallbackContext {
  Module module_;
  CallbackWithDelegate callback;
}

private extern(C) wasm_trap_t* callbackWithDelegate(
  void* env, const wasm_val_vec_t* arguments, wasm_val_vec_t* results
) {
  import std.algorithm : map;
  import std.array : array;
  import std.string : toStringz;

  assert(env);
  auto context = cast(CallbackContext*) env;

  try {
    // Forward arguments to the managed callback
    Value[] argumentsManaged = arguments.data[0..arguments.size].map!(arg => Value.from(arg)).array;
    auto resultsManaged = new Value[results.size];

    context.callback(context.module_, argumentsManaged, resultsManaged);

    // Pass results back to the runtime
    for (auto i = 0; i < resultsManaged.length; i += 1) {
      results.data[i] = *resultsManaged[i].value;
    }
  } catch (Exception ex) {
    wasm_name_t message;
    wasm_name_new_from_string_nt(&message, toStringz(ex.msg));
    wasm_trap_t* trap = wasm_trap_new(context.module_.store.handle, &message);
    wasm_name_delete(&message);
    return trap;
  }
  return null;
}

/// Detect whether `T` is an `Module`.
enum bool isModule(T) = __traits(isSame, T, Module);

/// Detect whether `T` is an `Instance`.
enum bool isInstance(T) = __traits(isSame, T, Instance);

/// Detect whether `T` is callable as a `Function`.
///
/// See_Also:
/// $(UL
///   $(LI `Function`)
///   $(LI `CallbackWithDelegate`)
///   $(LI <a href="https://dlang.org/library/std/traits/is_callable.html" title="The D Language Website">`isCallable`</a>)
///   $(LI <a href="https://dlang.org/spec/type.html#basic-data-types" title="The D Language Website">Basic Data Types</a>)
///   $(LI <a href="https://dlang.org/spec/function.html#param-storage" title="The D Language Website">Parameter Storage Classes</a>)
/// )
template isCallableAsFunction(T...) if (T.length == 1 && isCallable!T) {
  import std.meta : allSatisfy, templateOr;
  import std.traits : isBoolean, isIntegral, isFloatingPoint;

  alias TParams = Parameters!T;
  static assert(TParams.length > 0, "The delegate must at least have one argument of type `Module`");
  static if (TParams.length == 1 && !isModule!(TParams[0])) {
    static assert(0, "The first parameter in the method must be of type `Module`");
  }
  enum bool isCallableAsFunction = allSatisfy!(templateOr!(
    isBoolean,
    isIntegral,
    isFloatingPoint,
    isModule
  ), TParams);
}

@safe unittest {
  interface I { void run(Module) const; }
  struct S { static void opCall(Module, bool, int) {} }
  class C { void opCall(double, float, Engine) {} }
  auto c = new C;

  static assert( isCallableAsFunction!(I.run));
  static assert( isCallableAsFunction!(S));
  static assert( isCallableAsFunction!((Module _) {}));
  static assert( isCallableAsFunction!((Module _, int __, double ___) {}));
  static assert(!isCallableAsFunction!c);
  static assert(!isCallableAsFunction!(c.opCall));
}

/// A WebAssembly function reference.
class Function : Handle!wasm_func_t {
  /// Instantiate a D function to be called from WASM code.
  this(Store store, wasm_functype_t* type, Callback callback) {
    super(wasm_func_new(store.handle, type, callback));
  }
  /// ditto
  this(Store store, wasm_functype_t* type, CallbackWithEnv callback, void* env) {
    super(wasm_func_new_with_env(store.handle, type, callback, env, null));
  }
  /// Instantiate a D delegate to be called from WASM code.
  this(Store store, Module module_, wasm_functype_t* type, CallbackWithDelegate callback) {
    this(store, type, &callbackWithDelegate, new CallbackContext(module_, callback));
  }
  /// Instantiate a D function that satisfies `isCallableAsFunction` to be called from WASM code.
  this(Func)(Store store, Module module_, Func callback) if (isCallableAsFunction!Func) {
    this(
      store, callback.functype, &callbackWithDelegate, new CallbackContext(module_,
      (Module module_, Value[] arguments, Value[] results) => {
        import std.meta : staticIndexOf, staticMap;
        import std.traits : ParameterIdentifierTuple, ReturnType, Unqual;
        import std.typecons : Tuple;

        alias FuncParams = Parameters!Func;
        alias FuncParamNames = ParameterIdentifierTuple!Func;
        alias Tail(Args...) = Args[1 .. $];

        // Parameter helper templates
        enum int indexOf(T) = staticIndexOf!(T, FuncParams);
        enum string paramName(T) = FuncParamNames[indexOf!T];

        template diagnosticNameOf(T) {
          static if (paramName!T != "")
            enum string name = " '" ~ paramName!T ~ "'";
          else
            enum string name = "";
          enum string diagnosticNameOf = "parameter " ~ text(indexOf!T + 1) ~ name ~
            " of type `" ~ fullyQualifiedName!(Unqual!T) ~ "`";
        }

        Tuple!(staticMap!(Unqual, FuncParams)) params;

        static foreach (Param; FuncParams) {
          static if (isModule!(Unqual!Param)) {
            params[indexOf!Param] = module_;
          } else static if (isInt32!(Unqual!Param)) {
            assert(arguments[indexOf!Param - 1].kind == wasm_valkind_enum.WASM_I32);
            params[indexOf!Param] = arguments[indexOf!Param - 1].value.of.i32.to!(Unqual!Param);
          } else static if (isInt64!(Unqual!Param)) {
            assert(arguments[indexOf!Param - 1].kind == wasm_valkind_enum.WASM_I64);
            params[indexOf!Param] = arguments[indexOf!Param - 1].value.of.i64.to!(Unqual!Param);
          } else static if (isFloat32!(Unqual!Param)) {
            assert(arguments[indexOf!Param - 1].kind == wasm_valkind_enum.WASM_F32);
            params[indexOf!Param] = arguments[indexOf!Param - 1].value.of.f32;
          } else static if (isFloat64!(Unqual!Param)) {
            assert(arguments[indexOf!Param - 1].kind == wasm_valkind_enum.WASM_F64);
            params[indexOf!Param] = arguments[indexOf!Param - 1].value.of.f64;
          } else {
            static assert(0, "Could not apply " ~ diagnosticNameOf!Param ~ " to callback delegate");
          }
        }

        enum isNumericReturn = !__traits(isSame, ReturnType!Func, Value) &&
          (
            isInt32!(ReturnType!Func) || isInt64!(ReturnType!Func) ||
            isFloat32!(ReturnType!Func) || isFloat64!(ReturnType!Func)
          );

        static if (__traits(isSame, ReturnType!Func, void)) {
          assert(results.length == 0);
          callback(params.expand);
        } else static if (isNumericReturn) {
          assert(results.length == 1);
          results[0] = new Value(callback(params.expand));
        } else static if (__traits(isSame, ReturnType!Func, Value)) {
          assert(results.length == 1);
          results[0] = callback(params.expand);
        } else static if (__traits(isSame, ReturnType!Func, Value[])) {
          auto cbResults = callback(params.expand);
          assert(
            cbResults.length >= results.length,
            "Could not apply return values of callback delegate, expected " ~ text(results.length) ~
              " results, but received " ~ text(cbResults.length)
          );
          results[0..cbResults.length] = cbResults;
        } else
          static assert(0, "Could not apply return value(s) of callback delegate");
      }())
    );
  }
  private this(wasm_func_t* func) {
    super(func);
  }

  ///
  static Function from(const Extern extern_) {
    return new Function(wasm_extern_as_func(cast(wasm_extern_t*) extern_.handle));
  }

  ///
  wasm_functype_t* type() @property const {
    return wasm_func_type(handle);
  }

  ///
  Extern asExtern(string name = "") @property const {
    import std.string : toStringz;

    if (name.length == 0) return new Extern(
      wasm_func_as_extern(handle),
      wasm_exporttype_new(null, wasm_functype_as_externtype(type))
    );

    wasm_name_t nameVec;
    wasm_name_new_from_string_nt(&nameVec, toStringz(name));
    return new Extern(wasm_func_as_extern(handle), wasm_exporttype_new(&nameVec, wasm_functype_as_externtype(type)));
  }

  /// Params:
  /// results=Zero or more <a href="https://github.com/WebAssembly/multi-value/blob/master/proposals/multi-value/Overview.md">return values</a>
  /// Returns: Whether the function ran to completion without hitting a trap.
  bool call(out Value[] results) {
    return call([], results);
  }
  /// Params:
  /// arguments=
  /// results=Zero or more <a href="https://github.com/WebAssembly/multi-value/blob/master/proposals/multi-value/Overview.md">return values</a>
  /// Returns: Whether the function ran to completion without hitting a trap.
  bool call(Value[] arguments, out Value[] results) {
    wasm_val_vec_t args;
    wasm_val_vec_new_uninitialized(&args, arguments.length);
    for (auto i = 0; i < arguments.length; i += 1) {
      args.data[i] = *arguments[i].value;
    }

    wasm_val_vec_t resultsVec;
    wasm_val_vec_new_uninitialized(&resultsVec, wasm_functype_results(type).size);
    auto trap = wasm_func_call(handle, &args, &resultsVec);

    wasm_val_vec_delete(&args);
    if (trap !is null) throw new Exception(new Trap(trap).message);
    results = new Value[resultsVec.size];
    for (auto i = 0; i < resultsVec.size; i += 1) {
      results[i] = Value.from(resultsVec.data[i]);
    }
    wasm_val_vec_delete(&resultsVec);

    return true;
  }
}

version (unittest) {
  const string wat_callback_module =
"(module" ~
"  (func $print (import \"\" \"print\") (param i32) (result i32))" ~
"  (func $closure (import \"\" \"closure\") (result i32))" ~
"  (func (export \"run\") (param $x i32) (param $y i32) (result i32)" ~
"    (i32.add" ~
"      (call $print (i32.add (local.get $x) (local.get $y)))" ~
"      (call $closure)" ~
"    )" ~
"  )" ~
")";

  package extern(C) wasm_trap_t* closure(void* env, const wasm_val_vec_t* args, wasm_val_vec_t* results) {
    int i = *(cast(int*) env);
    assert(i == 42);

    results.data[0].kind = WASM_I32;
    results.data[0].of.i32 = cast(int32_t) i;
    return null;
  }
}

unittest {
  auto engine = new Engine();
  auto store = new Store(engine);
  auto module_ = Module.from(store, wat_callback_module);
  assert(module_.valid, "Error compiling module!");
  int i = 42;

  auto print = (Module module_, int value) => {
    assert(value == 7);
    return value;
  }();
  auto imports = [
    new Function(store, module_, print.toDelegate).asExtern,
    new Function(store, wasm_functype_new_0_1(wasm_valtype_new_i32()), &closure, &i).asExtern
  ];
  auto instance = module_.instantiate(imports);
  assert(instance.valid);
  auto runFunc = Function.from(instance.exports[0]);

  assert(instance.exports[0].name == "run" && runFunc.valid, "Failed to get the `run` function!");

  auto three = new Value(3);
  auto four = new Value(4);
  Value[] results;
  assert(runFunc.call([three, four], results), "Error calling the `run` function!");
  assert(results.length == 1);
  assert(results.length == 1 && results[0].value.of.i32 == 49);

  destroy(three);
  destroy(four);
  destroy(instance);
  destroy(module_);
}

/// Used to immediately terminate execution and signal abnormal behavior to the execution environment.
///
/// See_Also:
/// $(UL
///   $(LI <a href="https://webassembly.org/docs/security/#developers" title="The WebAssembly Website">Security - WebAssembly</a>)
///   $(LI <a href="https://webassembly.github.io/spec/core/exec/runtime.html#syntax-trap" title="The WebAssembly Specifcation">Administrative Instructions - WebAssembly 1.1</a>)
/// )
class Trap : Handle!wasm_trap_t {
  ///
  const string message;
  ///
  this(wasm_trap_t* trap) {
    import std.string : fromStringz;

    super(trap, true);
    wasm_name_t messageVec;
    wasm_trap_message(trap, &messageVec);
    this.message = messageVec.data.fromStringz.to!string;
  }
  ///
  this(Store store, string message = "") {
    import std.string : toStringz;

    super(wasm_trap_new(cast(wasm_store_t*) store.handle, null), );
    this.message = message;
    if (message.length) {
      wasm_byte_vec_t stringVec;
      wasm_byte_vec_new(&stringVec, message.length, message.toStringz);
      wasm_trap_message(handle, &stringVec);
      wasm_byte_vec_delete(&stringVec);
    }
  }
  ~this() {
    if (valid && !borrowed) wasm_trap_delete(handle);
  }

  ///
  T hostInfo(T)() @property const {
    return cast(T) wasm_trap_get_host_info(handle);
  }
  ///
  void hostInfo(T)(ref T value) @property {
    static if (is(T == class)) {
      wasm_trap_set_host_info_with_finalizer(handle, &value, &finalizeHostInfo!T);
    } else {
      wasm_trap_set_host_info(handle, &value);
    }
  }
}

version (unittest) {
  const string wat_trap_module =
    "(module" ~
    "  (func $callback (import \"\" \"callback\") (result i32))" ~
    "  (func (export \"callback\") (result i32) (call $callback))" ~
    "  (func (export \"unreachable\") (result i32) (unreachable) (i32.const 1))" ~
    ")";
}

unittest {
  import std.exception : assertThrown, collectExceptionMsg;

  auto engine = new Engine();
  auto store = new Store(engine);
  auto module_ = Module.from(store, wat_trap_module);
  assert(module_.valid, "Error compiling module!");

  auto fail = (Module module_, Value[] arguments, Value[] results) => {
    assert(arguments.length == 0);
    assert(results.length == 1);
    throw new Exception("callback abort");
  }();
  auto imports = [
    new Function(store, module_, wasm_functype_new_0_1(wasm_valtype_new_i32()), fail.toDelegate).asExtern
  ];
  auto instance = new Instance(store, module_, imports);
  assert(instance.valid && instance.exports.length == 2, "Error accessing exports!");
  auto callbackFunc = Function.from(instance.exports[0]);

  assert(instance.exports[0].name == "callback" && callbackFunc.valid, "Failed to get the `callback` function!");

  Value[] results;
  assert(
    collectExceptionMsg!Exception(callbackFunc.call(results)) == "callback abort",
    "Error calling exported function, expected trap!"
  );
  assert(results.length == 0);

  destroy(instance);
  destroy(module_);
}
