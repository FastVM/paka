module purr.wasm.gen;

import wasmer;
import purr.io;

extern(C)
void[0] ffi_type_longdouble;

static this()
{
    const string wat_sum_module =
  "(module\n" ~
  "  (type $sum_t (func (param i32 i32) (result i32)))\n" ~
  "  (func $sum_f (type $sum_t) (param $x i32) (param $y i32) (result i32)\n" ~
  "    local.get $x\n" ~
  "    local.get $y\n" ~
  "    i32.add)\n" ~
  "  (export \"sum\" (func $sum_f)))";

    auto engine = new Engine();
    auto store = new Store(engine);
    auto module_ = Module.from(store, wat_sum_module);
    assert(engine.valid && store.valid && module_.valid, "Could not load module!");

    auto instance = new Instance(store, module_);
    assert(instance.valid, "Could not instantiate module!");

    assert(instance.exports[0].name == "sum");
    auto sumFunc = Function.from(instance.exports[0]);
    assert(sumFunc.valid, "Could not load exported 'sum' function!");

    Value[] results;
    assert(sumFunc.call([new Value(3), new Value(4)], results), "Error calling the `sum` function!");
    assert(results.length == 1 && results[0].value.of.i32 == 7);
    writeln(results[0].value.of.i32);
}

