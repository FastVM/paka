module purr.ast.walk;

import core.memory;
import std.conv : to;
import std.stdio;
import std.string;
import std.algorithm;
import std.ascii;
import purr.ast.ast;
import purr.srcloc;
import purr.err;
import purr.vm.bytecode;

__gshared bool dumpast = false;

class Reg {
    int repr;
    string sym;

    this(T)(T n, string s = null) {
        if (n < 0) {
            vmError("reg too low");
        }
        repr = cast(int) n;
        sym = s;
    }

    ubyte[4] reg() {
        return (cast(ubyte*)&repr)[0 .. 4];
    }

    override bool opEquals(Object other) {
        Reg oreg = cast(Reg) other;
        return oreg !is null && repr == oreg.repr;
    }

    override string toString() {
        if (sym.length == 0) {
            return "." ~ repr.to!string;
        } else {
            return sym;
        }
    }
}

final class Walker {
    Node[] nodes;
    double[string] constants;

    Node[][] captureValuess;
    Reg[][] currentCaptures;
    Reg[] captureRegs;
    double[string][] inNthCaptures;

    Reg[string][] localss;

    Reg[] regs;

    ubyte[] bytecode;

    Reg[] targets;

    int[string] funcs;
    int[][string] replaces;

    ref Reg[string] locals() {
        return localss[$ - 1];
    }

    ref Reg captureReg() {
        return captureRegs[$ - 1];
    }

    ref Reg[] currentCapture() {
        return currentCaptures[$ - 1];
    }

    ref Node[] captureValues() {
        return captureValuess[$ - 1];
    }

    void walkProgram(Node program) {
        localss.length++;
        captureValuess.length++;
        currentCaptures.length++;
        inNthCaptures.length++;
        scope (exit) {
            localss.length--;
            captureValuess.length--;
            currentCaptures.length--;
            inNthCaptures.length--;
        }
        if (dumpast) {
            writeln(program);
        }
        bytecode = null;
        walk(program);
        bytecode ~= Opcode.exit;
        foreach (name, locs; replaces) {
            int setto = funcs[name];
            foreach (n; locs) {
                bytecode[n .. n + 4] = ubytes(setto);
            }
        }
    }

    ubyte[1] ubytes(bool val) {
        return (cast(ubyte*)&val)[0 .. 1];
    }

    ubyte[4] ubytes(int val) {
        return (cast(ubyte*)&val)[0 .. 4];
    }

    ubyte[4] ubytes(double val) {
        assert(val % 1 == 0, "floats are broken, sadly");
        int inum = cast(int) val;
        return (cast(ubyte*)&inum)[0 .. 4];
    }

    Reg allocOut() {
        if (targets[$ - 1]!is null) {
            return targets[$ - 1];
        }
        return alloc();
    }

    Reg allocOutMaybe() {
        if (targets[$ - 1]!is null) {
            return targets[$ - 1];
        }
        return null;
    }

    Reg alloc(Node isFor = null) {
        Reg reg = new Reg(regs.length);
        regs ~= reg;
        return reg;
    }

    Reg walk(Node node, Reg target = null) {
        targets ~= target;
        nodes ~= node;
        scope (exit) {
            targets.length--;
            nodes.length--;
        }
        switch (node.id) {
        case NodeKind.call:
            return walkExact(cast(Form) node);
        case NodeKind.ident:
            return walkExact(cast(Ident) node);
        case NodeKind.value:
            return walkExact(cast(Value) node);
        default:
            assert(false);
        }
    }

    alias ifTrue = jumpOn!true;
    alias ifFalse = jumpOn!false;

    int[] jumpOn(bool doNotNegate)(Node node, int where = -1) {
        if (Form form = cast(Form) node) {
            if (form.form == "||") {
                int[] reta = jumpOn!doNotNegate(form.args[0], where);
                int[] retb = jumpOn!doNotNegate(form.args[1], where);
                return reta ~ retb;
            }
            if (form.form == "&&") {
                int[] passJumps = jumpOn!(!doNotNegate)(form.args[0], where);
                int[] ret = jumpOn!doNotNegate(form.args[1], where);
                int passTo = cast(int) bytecode.length;
                foreach (passJump; passJumps) {
                    bytecode[passJump .. passJump + 4] = ubytes(passTo);
                }
                return ret;
            }
            if (form.form == "==") {
                if (Value valueLeft = cast(Value) form.args[0]) {
                    assert(valueLeft.info == typeid(double));
                    Reg rhs = walk(form.args[1]);
                    static if (doNotNegate) {
                        bytecode ~= Opcode.jump_if_equal_num;
                    } else {
                        bytecode ~= Opcode.jump_if_not_equal_num;
                    }
                    int ret = cast(int) bytecode.length;
                    bytecode ~= ubytes(where);
                    bytecode ~= rhs.reg;
                    bytecode ~= ubytes(*cast(double*) valueLeft.value);
                    return [ret];
                } else if (Value valueRight = cast(Value) form.args[1]) {
                    assert(valueRight.info == typeid(double));
                    Reg lhs = walk(form.args[0]);
                    static if (doNotNegate) {
                        bytecode ~= Opcode.jump_if_equal_num;
                    } else {
                        bytecode ~= Opcode.jump_if_not_equal_num;
                    }
                    int ret = cast(int) bytecode.length;
                    bytecode ~= ubytes(where);
                    bytecode ~= lhs.reg;
                    bytecode ~= ubytes(*cast(double*) valueRight.value);
                    return [ret];
                } else {
                    Reg lhs = walk(form.args[0]);
                    Reg rhs = walk(form.args[1]);
                    static if (doNotNegate) {
                        bytecode ~= Opcode.jump_if_equal;
                    } else {
                        bytecode ~= Opcode.jump_if_not_equal;
                    }
                    int ret = cast(int) bytecode.length;
                    bytecode ~= ubytes(where);
                    bytecode ~= lhs.reg;
                    bytecode ~= rhs.reg;
                    return [ret];
                }
            }
            if (form.form == "!=") {
                if (Value valueLeft = cast(Value) form.args[0]) {
                    assert(valueLeft.info == typeid(double));
                    Reg rhs = walk(form.args[1]);
                    static if (doNotNegate) {
                        bytecode ~= Opcode.jump_if_not_equal_num;
                    } else {
                        bytecode ~= Opcode.jump_if_equal_num;
                    }
                    int ret = cast(int) bytecode.length;
                    bytecode ~= ubytes(where);
                    bytecode ~= rhs.reg;
                    bytecode ~= ubytes(*cast(double*) valueLeft.value);
                    return [ret];
                } else if (Value valueRight = cast(Value) form.args[1]) {
                    assert(valueRight.info == typeid(double));
                    Reg lhs = walk(form.args[0]);
                    static if (doNotNegate) {
                        bytecode ~= Opcode.jump_if_not_equal_num;
                    } else {
                        bytecode ~= Opcode.jump_if_equal_num;
                    }
                    int ret = cast(int) bytecode.length;
                    bytecode ~= ubytes(where);
                    bytecode ~= lhs.reg;
                    bytecode ~= ubytes(*cast(double*) valueRight.value);
                    return [ret];
                } else {
                    Reg lhs = walk(form.args[0]);
                    Reg rhs = walk(form.args[1]);
                    static if (doNotNegate) {
                        bytecode ~= Opcode.jump_if_not_equal;
                    } else {
                        bytecode ~= Opcode.jump_if_equal;
                    }
                    int ret = cast(int) bytecode.length;
                    bytecode ~= ubytes(where);
                    bytecode ~= lhs.reg;
                    bytecode ~= rhs.reg;
                    return [ret];
                }
            }
            if (form.form == "<") {
                if (Value valueLeft = cast(Value) form.args[0]) {
                    assert(valueLeft.info == typeid(double));
                    Reg rhs = walk(form.args[1]);
                    static if (doNotNegate) {
                        bytecode ~= Opcode.jump_if_greater_num;
                    } else {
                        bytecode ~= Opcode.jump_if_less_than_equal_num;
                    }
                    int ret = cast(int) bytecode.length;
                    bytecode ~= ubytes(where);
                    bytecode ~= rhs.reg;
                    bytecode ~= ubytes(*cast(double*) valueLeft.value);
                    return [ret];
                } else if (Value valueRight = cast(Value) form.args[1]) {
                    assert(valueRight.info == typeid(double));
                    Reg lhs = walk(form.args[0]);
                    static if (doNotNegate) {
                        bytecode ~= Opcode.jump_if_less_num;
                    } else {
                        bytecode ~= Opcode.jump_if_greater_than_equal_num;
                    }
                    int ret = cast(int) bytecode.length;
                    bytecode ~= ubytes(where);
                    bytecode ~= lhs.reg;
                    bytecode ~= ubytes(*cast(double*) valueRight.value);
                    return [ret];
                } else {
                    Reg lhs = walk(form.args[0]);
                    Reg rhs = walk(form.args[1]);
                    static if (doNotNegate) {
                        bytecode ~= Opcode.jump_if_less;
                    } else {
                        bytecode ~= Opcode.jump_if_greater_than_equal;
                    }
                    int ret = cast(int) bytecode.length;
                    bytecode ~= ubytes(where);
                    bytecode ~= lhs.reg;
                    bytecode ~= rhs.reg;
                    return [ret];
                }
            }
            if (form.form == ">") {
                if (Value valueLeft = cast(Value) form.args[0]) {
                    assert(valueLeft.info == typeid(double));
                    Reg rhs = walk(form.args[1]);
                    static if (doNotNegate) {
                        bytecode ~= Opcode.jump_if_less_num;
                    } else {
                        bytecode ~= Opcode.jump_if_greater_than_equal_num;
                    }
                    int ret = cast(int) bytecode.length;
                    bytecode ~= ubytes(where);
                    bytecode ~= rhs.reg;
                    bytecode ~= ubytes(*cast(double*) valueLeft.value);
                    return [ret];
                } else if (Value valueRight = cast(Value) form.args[1]) {
                    assert(valueRight.info == typeid(double));
                    Reg lhs = walk(form.args[0]);
                    static if (doNotNegate) {
                        bytecode ~= Opcode.jump_if_greater_num;
                    } else {
                        bytecode ~= Opcode.jump_if_less_than_equal_num;
                    }
                    int ret = cast(int) bytecode.length;
                    bytecode ~= ubytes(where);
                    bytecode ~= lhs.reg;
                    bytecode ~= ubytes(*cast(double*) valueRight.value);
                    return [ret];
                } else {
                    Reg lhs = walk(form.args[0]);
                    Reg rhs = walk(form.args[1]);
                    static if (doNotNegate) {
                        bytecode ~= Opcode.jump_if_greater;
                    } else {
                        bytecode ~= Opcode.jump_if_less_than_equal;
                    }
                    int ret = cast(int) bytecode.length;
                    bytecode ~= ubytes(where);
                    bytecode ~= lhs.reg;
                    bytecode ~= rhs.reg;
                    return [ret];
                }
            }
            if (form.form == "<=") {
                if (Value valueLeft = cast(Value) form.args[0]) {
                    assert(valueLeft.info == typeid(double));
                    Reg rhs = walk(form.args[1]);
                    static if (doNotNegate) {
                        bytecode ~= Opcode.jump_if_greater_than_equal_num;
                    } else {
                        bytecode ~= Opcode.jump_if_less_num;
                    }
                    int ret = cast(int) bytecode.length;
                    bytecode ~= ubytes(where);
                    bytecode ~= rhs.reg;
                    bytecode ~= ubytes(*cast(double*) valueLeft.value);
                    return [ret];
                } else if (Value valueRight = cast(Value) form.args[1]) {
                    assert(valueRight.info == typeid(double));
                    Reg lhs = walk(form.args[0]);
                    static if (doNotNegate) {
                        bytecode ~= Opcode.jump_if_less_than_equal_num;
                    } else {
                        bytecode ~= Opcode.jump_if_greater_num;
                    }
                    int ret = cast(int) bytecode.length;
                    bytecode ~= ubytes(where);
                    bytecode ~= lhs.reg;
                    bytecode ~= ubytes(*cast(double*) valueRight.value);
                    return [ret];
                } else {
                    Reg lhs = walk(form.args[0]);
                    Reg rhs = walk(form.args[1]);
                    static if (doNotNegate) {
                        bytecode ~= Opcode.jump_if_less_than_equal;
                    } else {
                        bytecode ~= Opcode.jump_if_greater;
                    }
                    int ret = cast(int) bytecode.length;
                    bytecode ~= ubytes(where);
                    bytecode ~= lhs.reg;
                    bytecode ~= rhs.reg;
                    return [ret];
                }
            }
            if (form.form == ">=") {
                if (Value valueLeft = cast(Value) form.args[0]) {
                    assert(valueLeft.info == typeid(double));
                    Reg rhs = walk(form.args[1]);
                    static if (doNotNegate) {
                        bytecode ~= Opcode.jump_if_less_than_equal_num;
                    } else {
                        bytecode ~= Opcode.jump_if_greater_num;
                    }
                    int ret = cast(int) bytecode.length;
                    bytecode ~= ubytes(where);
                    bytecode ~= rhs.reg;
                    bytecode ~= ubytes(*cast(double*) valueLeft.value);
                    return [ret];
                } else if (Value valueRight = cast(Value) form.args[1]) {
                    assert(valueRight.info == typeid(double));
                    Reg lhs = walk(form.args[0]);
                    static if (doNotNegate) {
                        bytecode ~= Opcode.jump_if_greater_than_equal_num;
                    } else {
                        bytecode ~= Opcode.jump_if_less_num;
                    }
                    int ret = cast(int) bytecode.length;
                    bytecode ~= ubytes(where);
                    bytecode ~= lhs.reg;
                    bytecode ~= ubytes(*cast(double*) valueRight.value);
                    return [ret];
                } else {
                    Reg lhs = walk(form.args[0]);
                    Reg rhs = walk(form.args[1]);
                    static if (doNotNegate) {
                        bytecode ~= Opcode.jump_if_greater_than_equal;
                    } else {
                        bytecode ~= Opcode.jump_if_less;
                    }
                    int ret = cast(int) bytecode.length;
                    bytecode ~= ubytes(where);
                    bytecode ~= lhs.reg;
                    bytecode ~= rhs.reg;
                    return [ret];
                }
            }
        }
        Reg cmp = walk(node);
        static if (doNotNegate) {
            bytecode ~= Opcode.jump_if_true;
        } else {
            bytecode ~= Opcode.jump_if_false;
        }
        int ret = cast(int) bytecode.length;
        bytecode ~= ubytes(where);
        bytecode ~= cmp.reg;
        return [ret];
    }

    Reg walkExact(Form form) {
        switch (form.form) {
        default:
            break;
        case "do":
            if (form.args.length == 0) {
                return null;
            } else {
                Reg ret = allocOutMaybe;
                foreach (elem; form.args[0 .. $ - 1]) {
                    walk(elem);
                }
                Reg last = walk(form.args[$ - 1], ret);
                if (ret !is null && last !is null && ret != last) {
                    vmError("reg alloc fail for: " ~ form.to!string);
                }
                return last;
            }
        case "array":
            Reg outreg = allocOut;
            Reg[] regs;
            foreach (arg; form.args) {
                Reg reg = walk(arg);
                regs ~= reg;
            }
            bytecode ~= Opcode.array;
            bytecode ~= outreg.reg;
            bytecode ~= ubytes(cast(int) regs.length);
            foreach (reg; regs) {
                bytecode ~= reg.reg;
            }
            return outreg;
        case "index":
            Reg outreg = allocOut;
            Reg objreg = walk(form.args[0]);
            Reg index = walk(form.args[1]);
            bytecode ~= Opcode.index;
            bytecode ~= outreg.reg;
            bytecode ~= objreg.reg;
            bytecode ~= index.reg;
            return outreg;
        case "length":
            Reg outreg = allocOut;
            Reg objreg = walk(form.args[0]);
            bytecode ~= Opcode.length;
            bytecode ~= outreg.reg;
            bytecode ~= objreg.reg;
            return outreg;
        case "var":
            if (Ident id = cast(Ident) form.args[0]) {
                bool isLambda = false;
                if (Form lambda = cast(Form) form.args[1]) {
                    if (lambda.form == "lambda") {
                        string name = id.repr;
                        funcs[id.repr] = cast(int)(bytecode.length + 9);
                        isLambda = true;
                    }
                }
                Reg target;
                Reg from;     
                target = alloc();
                from = walk(form.args[1], target);
                locals[id.repr] = target;
                if (target != from) {
                    bytecode ~= Opcode.store_reg;
                    bytecode ~= target.reg;
                    bytecode ~= from.reg;
                }
                Reg outreg = allocOutMaybe;
                if (outreg is null || outreg == target) {
                    return target;
                } else if (outreg == from) {
                    return from;
                } else {
                    bytecode ~= Opcode.store_reg;
                    bytecode ~= outreg.reg;
                    bytecode ~= from.reg;
                    return outreg;
                }
            } else {
                vmError("set to bad value");
                assert(false);
            }
        case "set":
            if (Ident id = cast(Ident) form.args[0]) {
                bool isLambda = false;
                if (Form lambda = cast(Form) form.args[1]) {
                    if (lambda.form == "lambda") {
                        string name = id.repr;
                        funcs[id.repr] = cast(int)(bytecode.length + 9);
                        isLambda = true;
                    }
                }
                Reg target;
                Reg from;     
                if (Reg* ret = id.repr in locals) {
                    target = *ret;
                    from = walk(form.args[1], target);
                } else {
                    vmError("set to unknown variable: " ~ id.repr);
                }
                if (target != from) {
                    bytecode ~= Opcode.store_reg;
                    bytecode ~= target.reg;
                    bytecode ~= from.reg;
                }
                Reg outreg = allocOutMaybe;
                if (outreg is null || outreg == target) {
                    return target;
                } else if (outreg == from) {
                    return from;
                } else {
                    bytecode ~= Opcode.store_reg;
                    bytecode ~= outreg.reg;
                    bytecode ~= from.reg;
                    return outreg;
                }
            } else {
                vmError("set to bad value");
                assert(false);
            }
        case "if":
            Reg outreg = allocOut;
            int[] jumpsFalseFrom = ifFalse(form.args[0]);
            walk(form.args[1], outreg);
            bytecode ~= Opcode.jump_always;
            int jumpOutFrom = cast(int) bytecode.length;
            bytecode ~= ubytes(-1);
            int jumpFalseTo = cast(int) bytecode.length;
            walk(form.args[2], outreg);
            int jumpOutTo = cast(int) bytecode.length;
            bytecode[jumpOutFrom .. jumpOutFrom + 4] = ubytes(jumpOutTo);
            foreach (jumpFalseFrom; jumpsFalseFrom) {
                bytecode[jumpFalseFrom .. jumpFalseFrom + 4] = ubytes(jumpFalseTo);
            }
            return outreg;
        case "unless":
            Reg outreg = allocOut;
            int[] jumpsFalseFrom = ifTrue(form.args[0]);
            walk(form.args[1], outreg);
            bytecode ~= Opcode.jump_always;
            int jumpOutFrom = cast(int) bytecode.length;
            bytecode ~= ubytes(-1);
            int jumpFalseTo = cast(int) bytecode.length;
            walk(form.args[2], outreg);
            int jumpOutTo = cast(int) bytecode.length;
            bytecode[jumpOutFrom .. jumpOutFrom + 4] = ubytes(jumpOutTo);
            foreach (jumpFalseFrom; jumpsFalseFrom) {
                bytecode[jumpFalseFrom .. jumpFalseFrom + 4] = ubytes(jumpFalseTo);
            }
            return outreg;
        case "while":
            bytecode ~= Opcode.jump_always;
            int jumpCondFrom = cast(int) bytecode.length;
            bytecode ~= ubytes(-1);
            int jumpRedoTo = cast(int) bytecode.length;
            walk(form.args[1]);
            int jumpCondTo = cast(int) bytecode.length;
            ifTrue(form.args[0], jumpRedoTo);
            bytecode[jumpCondFrom .. jumpCondFrom + 4] = ubytes(jumpCondTo);
            return null;
        case "until":
            bytecode ~= Opcode.jump_always;
            int jumpCondFrom = cast(int) bytecode.length;
            bytecode ~= ubytes(-1);
            int jumpRedoTo = cast(int) bytecode.length;
            walk(form.args[1]);
            int jumpCondTo = cast(int) bytecode.length;
            ifFalse(form.args[0], jumpRedoTo);
            bytecode[jumpCondFrom .. jumpCondFrom + 4] = ubytes(jumpCondTo);
            return null;
        case "+":
            if (Value valueLeft = cast(Value) form.args[0]) {
                Reg rhs = walk(form.args[1]);
                Reg res = allocOut;
                if (res == rhs) {
                    bytecode ~= Opcode.inc_num;
                    bytecode ~= res.reg;
                } else {
                    bytecode ~= Opcode.add_num;
                    bytecode ~= res.reg;
                    bytecode ~= rhs.reg;
                }
                assert(valueLeft.info == typeid(double));
                bytecode ~= ubytes(*cast(double*) valueLeft.value);
                return res;
            } else if (Value valueRight = cast(Value) form.args[1]) {
                Reg lhs = walk(form.args[0]);
                Reg res = allocOut;
                if (res == lhs) {
                    bytecode ~= Opcode.inc_num;
                    bytecode ~= res.reg;
                } else {
                    bytecode ~= Opcode.add_num;
                    bytecode ~= res.reg;
                    bytecode ~= lhs.reg;
                }
                assert(valueRight.info == typeid(double));
                bytecode ~= ubytes(*cast(double*) valueRight.value);
                return res;
            } else {
                Reg lhs = walk(form.args[0]);
                Reg rhs = walk(form.args[1]);
                Reg res = allocOut;
                if (lhs == res) {
                    bytecode ~= Opcode.inc;
                    bytecode ~= res.reg;
                    bytecode ~= rhs.reg;
                } else if (rhs == res) {
                    bytecode ~= Opcode.inc;
                    bytecode ~= res.reg;
                    bytecode ~= lhs.reg;
                } else {
                    bytecode ~= Opcode.add;
                    bytecode ~= res.reg;
                    bytecode ~= lhs.reg;
                    bytecode ~= rhs.reg;
                }
                return res;
            }
        case "-":
            if (Value valueRight = cast(Value) form.args[1]) {
                Reg lhs = walk(form.args[0]);
                Reg res = allocOut;
                if (lhs == res) {
                    bytecode ~= Opcode.dec_num;
                    bytecode ~= res.reg;
                } else {
                    bytecode ~= Opcode.sub_num;
                    bytecode ~= res.reg;
                    bytecode ~= lhs.reg;
                }
                assert(valueRight.info == typeid(double));
                bytecode ~= ubytes(*cast(double*) valueRight.value);
                return res;
            } else {
                Reg lhs = walk(form.args[0]);
                Reg rhs = walk(form.args[1]);
                Reg res = allocOut;
                if (lhs == res) {
                    bytecode ~= Opcode.dec;
                    bytecode ~= res.reg;
                    bytecode ~= rhs.reg;
                } else {
                    bytecode ~= Opcode.sub;
                    bytecode ~= res.reg;
                    bytecode ~= lhs.reg;
                    bytecode ~= rhs.reg;
                }
                return res;
            }
        case "*":
            if (Value valueLeft = cast(Value) form.args[0]) {
                Reg rhs = walk(form.args[1]);
                Reg res = allocOut;
                bytecode ~= Opcode.mul_num;
                bytecode ~= res.reg;
                bytecode ~= rhs.reg;
                assert(valueLeft.info == typeid(double));
                bytecode ~= ubytes(*cast(double*) valueLeft.value);
                return res;
            } else if (Value valueRight = cast(Value) form.args[1]) {
                Reg lhs = walk(form.args[0]);
                Reg res = allocOut;
                bytecode ~= Opcode.mul_num;
                bytecode ~= res.reg;
                bytecode ~= lhs.reg;
                assert(valueRight.info == typeid(double));
                bytecode ~= ubytes(*cast(double*) valueRight.value);
                return res;
            } else {
                Reg lhs = walk(form.args[0]);
                Reg rhs = walk(form.args[1]);
                Reg res = allocOut;
                bytecode ~= Opcode.mul;
                bytecode ~= res.reg;
                bytecode ~= lhs.reg;
                bytecode ~= rhs.reg;
                return res;
            }
        case "/":
            if (Value valueRight = cast(Value) form.args[1]) {
                Reg lhs = walk(form.args[0]);
                Reg res = allocOut;
                bytecode ~= Opcode.div_num;
                bytecode ~= res.reg;
                bytecode ~= lhs.reg;
                assert(valueRight.info == typeid(double));
                bytecode ~= ubytes(*cast(double*) valueRight.value);
                return res;
            } else {
                Reg lhs = walk(form.args[0]);
                Reg rhs = walk(form.args[1]);
                Reg res = allocOut;
                bytecode ~= Opcode.div;
                bytecode ~= res.reg;
                bytecode ~= lhs.reg;
                bytecode ~= rhs.reg;
                return res;
            }
        case "%":
            if (Value valueRight = cast(Value) form.args[1]) {
                Reg lhs = walk(form.args[0]);
                Reg res = allocOut;
                bytecode ~= Opcode.mod_num;
                bytecode ~= res.reg;
                bytecode ~= lhs.reg;
                assert(valueRight.info == typeid(double));
                bytecode ~= ubytes(*cast(double*) valueRight.value);
                return res;
            } else {
                Reg lhs = walk(form.args[0]);
                Reg rhs = walk(form.args[1]);
                Reg res = allocOut;
                bytecode ~= Opcode.mod;
                bytecode ~= res.reg;
                bytecode ~= lhs.reg;
                bytecode ~= rhs.reg;
                return res;
            }
        case "==":
            if (Value valueLeft = cast(Value) form.args[0]) {
                Reg rhs = walk(form.args[1]);
                Reg res = allocOut;
                bytecode ~= Opcode.equal_num;
                bytecode ~= res.reg;
                bytecode ~= rhs.reg;
                assert(valueLeft.info == typeid(double));
                bytecode ~= ubytes(*cast(double*) valueLeft.value);
                return res;
            } else if (Value valueRight = cast(Value) form.args[1]) {
                Reg lhs = walk(form.args[0]);
                Reg res = allocOut;
                bytecode ~= Opcode.equal_num;
                bytecode ~= res.reg;
                bytecode ~= lhs.reg;
                assert(valueRight.info == typeid(double));
                bytecode ~= ubytes(*cast(double*) valueRight.value);
                return res;
            } else {
                Reg lhs = walk(form.args[0]);
                Reg rhs = walk(form.args[1]);
                Reg res = allocOut;
                bytecode ~= Opcode.equal;
                bytecode ~= res.reg;
                bytecode ~= lhs.reg;
                bytecode ~= rhs.reg;
                return res;
            }
        case "!=":
            if (Value valueLeft = cast(Value) form.args[0]) {
                Reg rhs = walk(form.args[1]);
                Reg res = allocOut;
                bytecode ~= Opcode.not_equal_num;
                bytecode ~= res.reg;
                bytecode ~= rhs.reg;
                assert(valueLeft.info == typeid(double));
                bytecode ~= ubytes(*cast(double*) valueLeft.value);
                return res;
            } else if (Value valueRight = cast(Value) form.args[1]) {
                Reg lhs = walk(form.args[0]);
                Reg res = allocOut;
                bytecode ~= Opcode.not_equal_num;
                bytecode ~= res.reg;
                bytecode ~= lhs.reg;
                assert(valueRight.info == typeid(double));
                bytecode ~= ubytes(*cast(double*) valueRight.value);
                return res;
            } else {
                Reg lhs = walk(form.args[0]);
                Reg rhs = walk(form.args[1]);
                Reg res = allocOut;
                bytecode ~= Opcode.not_equal;
                bytecode ~= res.reg;
                bytecode ~= lhs.reg;
                bytecode ~= rhs.reg;
                return res;
            }
        case "<":
            if (Value valueLeft = cast(Value) form.args[0]) {
                Reg rhs = walk(form.args[1]);
                Reg res = allocOut;
                bytecode ~= Opcode.greater_num;
                bytecode ~= res.reg;
                bytecode ~= rhs.reg;
                assert(valueLeft.info == typeid(double));
                bytecode ~= ubytes(*cast(double*) valueLeft.value);
                return res;
            } else if (Value valueRight = cast(Value) form.args[1]) {
                Reg lhs = walk(form.args[0]);
                Reg res = allocOut;
                bytecode ~= Opcode.less_num;
                bytecode ~= res.reg;
                bytecode ~= lhs.reg;
                assert(valueRight.info == typeid(double));
                bytecode ~= ubytes(*cast(double*) valueRight.value);
                return res;
            } else {
                Reg lhs = walk(form.args[0]);
                Reg rhs = walk(form.args[1]);
                Reg res = allocOut;
                bytecode ~= Opcode.less;
                bytecode ~= res.reg;
                bytecode ~= lhs.reg;
                bytecode ~= rhs.reg;
                return res;
            }
        case ">":
            if (Value valueLeft = cast(Value) form.args[0]) {
                Reg rhs = walk(form.args[1]);
                Reg res = allocOut;
                bytecode ~= Opcode.less_num;
                bytecode ~= res.reg;
                bytecode ~= rhs.reg;
                assert(valueLeft.info == typeid(double));
                bytecode ~= ubytes(*cast(double*) valueLeft.value);
                return res;
            } else if (Value valueRight = cast(Value) form.args[1]) {
                Reg lhs = walk(form.args[0]);
                Reg res = allocOut;
                bytecode ~= Opcode.greater_num;
                bytecode ~= res.reg;
                bytecode ~= lhs.reg;
                assert(valueRight.info == typeid(double));
                bytecode ~= ubytes(*cast(double*) valueRight.value);
                return res;
            } else {
                Reg lhs = walk(form.args[0]);
                Reg rhs = walk(form.args[1]);
                Reg res = allocOut;
                bytecode ~= Opcode.greater;
                bytecode ~= res.reg;
                bytecode ~= lhs.reg;
                bytecode ~= rhs.reg;
                return res;
            }
        case "<=":
            if (Value valueLeft = cast(Value) form.args[0]) {
                Reg rhs = walk(form.args[1]);
                Reg res = allocOut;
                bytecode ~= Opcode.greater_than_equal_num;
                bytecode ~= res.reg;
                bytecode ~= rhs.reg;
                assert(valueLeft.info == typeid(double));
                bytecode ~= ubytes(*cast(double*) valueLeft.value);
                return res;
            } else if (Value valueRight = cast(Value) form.args[1]) {
                Reg lhs = walk(form.args[0]);
                Reg res = allocOut;
                bytecode ~= Opcode.less_than_equal_num;
                bytecode ~= res.reg;
                bytecode ~= lhs.reg;
                assert(valueRight.info == typeid(double));
                bytecode ~= ubytes(*cast(double*) valueRight.value);
                return res;
            } else {
                Reg lhs = walk(form.args[0]);
                Reg rhs = walk(form.args[1]);
                Reg res = allocOut;
                bytecode ~= Opcode.less_than_equal;
                bytecode ~= res.reg;
                bytecode ~= lhs.reg;
                bytecode ~= rhs.reg;
                return res;
            }
        case ">=":
            if (Value valueLeft = cast(Value) form.args[0]) {
                Reg rhs = walk(form.args[1]);
                Reg res = allocOut;
                bytecode ~= Opcode.less_than_equal_num;
                bytecode ~= res.reg;
                bytecode ~= rhs.reg;
                assert(valueLeft.info == typeid(double));
                bytecode ~= ubytes(*cast(double*) valueLeft.value);
                return res;
            } else if (Value valueRight = cast(Value) form.args[1]) {
                Reg lhs = walk(form.args[0]);
                Reg res = allocOut;
                bytecode ~= Opcode.greater_than_equal_num;
                bytecode ~= res.reg;
                bytecode ~= lhs.reg;
                assert(valueRight.info == typeid(double));
                bytecode ~= ubytes(*cast(double*) valueRight.value);
                return res;
            } else {
                Reg lhs = walk(form.args[0]);
                Reg rhs = walk(form.args[1]);
                Reg res = allocOut;
                bytecode ~= Opcode.greater_than_equal;
                bytecode ~= res.reg;
                bytecode ~= lhs.reg;
                bytecode ~= rhs.reg;
                return res;
            }
        case "lambda":
            Form argsForm = cast(Form) form.args[0];
            assert(argsForm !is null, "function must take args");
            assert(argsForm.form == "call" || argsForm.form == "args",
                    "malformed args type (must be 'args' or 'call')");
            string[] argnames;
            foreach (arg; argsForm.args) {
                Ident id = cast(Ident) arg;
                assert(id !is null, "malformed arg");
                argnames ~= id.repr;
            }
            Reg lambdaReg = allocOut;
            bytecode ~= Opcode.store_fun;
            bytecode ~= lambdaReg.reg;
            int refLength = cast(int) bytecode.length;
            bytecode ~= ubytes(-1);
            int refRegc = cast(int) bytecode.length;
            bytecode ~= ubytes(256);
            Reg[] oldRegs = regs;
            regs = null;
            localss.length++;
            foreach (index, arg; argnames) {
                locals[arg] = alloc();
            }
            captureRegs ~= alloc();
            scope (exit) {
                captureRegs.length--;
            }
            captureValuess.length++;
            currentCaptures.length++;
            inNthCaptures.length++;
            Reg retreg = walk(form.args[1]);
            if (retreg !is null) {
                bytecode ~= Opcode.ret;
                bytecode ~= retreg.reg;
            } else {
                bytecode ~= Opcode.ret;
                bytecode ~= alloc().reg;
            }
            bytecode[refRegc .. refRegc + 4] = ubytes(regs.length);
            regs = oldRegs;
            localss.length--;
            captureValuess.length--;
            currentCaptures.length--;
            inNthCaptures.length--;
            bytecode ~= Opcode.fun_done;
            bytecode[refLength .. refLength + 4] = ubytes(cast(int) bytecode.length);
            if (captureValues.length != 0) {
                Reg[] regs = [lambdaReg];
                foreach (arg; captureValues) {
                    Reg reg = walk(arg);
                    regs ~= reg;
                }
                bytecode ~= Opcode.array;
                bytecode ~= lambdaReg.reg;
                bytecode ~= ubytes(cast(int) regs.length);
                foreach (reg; regs) {
                    bytecode ~= reg.reg;
                }
            }
            return lambdaReg;
        case "call":
            bool isRec = false;
            bool isStatic = false;
            string staticName;
            if (Ident func = cast(Ident) form.args[0]) {
                if (func.repr == "println") {
                    Reg outreg = walk(form.args[1]);
                    bytecode ~= Opcode.println;
                    bytecode ~= outreg.reg;
                    return allocOut;
                } else if (func.repr == "putchar") {
                    Reg outreg = walk(form.args[1]);
                    bytecode ~= Opcode.putchar;
                    bytecode ~= outreg.reg;
                    return allocOut;
                } else if (func.repr == "rec") {
                    isRec = true;
                } else if (func.repr == "length") {
                    Reg outreg = allocOut;
                    Reg objreg = walk(form.args[1]);
                    bytecode ~= Opcode.length;
                    bytecode ~= outreg.reg;
                    bytecode ~= objreg.reg;
                    return outreg;
                } else {
                    isStatic = true;
                    staticName = func.repr;
                }
            }

            Reg funreg;
            Reg outreg = allocOut;
            if (!isRec && !isStatic) {
                funreg = walk(form.args[0]);
            }
            Reg[] argRegs;
            foreach (index, arg; form.args[1 .. $]) {
                argRegs ~= walk(arg);
            }
            switch (argRegs.length) {
            case 0:
                if (isRec) {
                    bytecode ~= Opcode.rec0;
                    bytecode ~= outreg.reg;
                } else if (isStatic) {
                    bytecode ~= Opcode.static_call0;
                    bytecode ~= outreg.reg;
                    if (int[]* preps = staticName in replaces) {
                        *preps ~= cast(int)(bytecode.length);
                    } else {
                        replaces[staticName] = [cast(int)(bytecode.length)];
                    }
                    bytecode ~= ubytes(-1);
                } else {
                    bytecode ~= Opcode.call0;
                    bytecode ~= outreg.reg;
                    bytecode ~= funreg.reg;
                }
                break;
            case 1:
                if (isRec) {
                    bytecode ~= Opcode.rec1;
                    bytecode ~= outreg.reg;
                } else if (isStatic) {
                    bytecode ~= Opcode.static_call1;
                    bytecode ~= outreg.reg;
                    if (int[]* preps = staticName in replaces) {
                        *preps ~= cast(int)(bytecode.length);
                    } else {
                        replaces[staticName] = [cast(int)(bytecode.length)];
                    }
                    bytecode ~= ubytes(-1);
                } else {
                    bytecode ~= Opcode.call1;
                    bytecode ~= outreg.reg;
                    bytecode ~= funreg.reg;
                }
                bytecode ~= argRegs[0].reg;
                break;
            case 2:
                if (isRec) {
                    bytecode ~= Opcode.rec2;
                    bytecode ~= outreg.reg;
                } else if (isStatic) {
                    bytecode ~= Opcode.static_call2;
                    bytecode ~= outreg.reg;
                    if (int[]* preps = staticName in replaces) {
                        *preps ~= cast(int)(bytecode.length);
                    } else {
                        replaces[staticName] = [cast(int)(bytecode.length)];
                    }
                    bytecode ~= ubytes(-1);
                } else {
                    bytecode ~= Opcode.call2;
                    bytecode ~= outreg.reg;
                    bytecode ~= funreg.reg;
                }
                bytecode ~= argRegs[0].reg;
                bytecode ~= argRegs[1].reg;
                break;
            default:
                if (isRec) {
                    bytecode ~= Opcode.rec;
                    bytecode ~= outreg.reg;
                } else if (isStatic) {
                    bytecode ~= Opcode.static_call;
                    bytecode ~= outreg.reg;
                    if (int[]* preps = staticName in replaces) {
                        *preps ~= cast(int)(bytecode.length);
                    } else {
                        replaces[staticName] = [cast(int)(bytecode.length)];
                    }
                    bytecode ~= ubytes(-1);
                } else {
                    bytecode ~= Opcode.call;
                    bytecode ~= outreg.reg;
                    bytecode ~= funreg.reg;
                }
                bytecode ~= ubytes(cast(int) argRegs.length);
                foreach (reg; argRegs) {
                    bytecode ~= reg.reg;
                }
                break;
            }
            return outreg;
        case "return":
            Reg res = walk(form.args[0]);
            bytecode ~= Opcode.ret;
            bytecode ~= res.reg;
            return null;
        case "capture":
            Reg fromreg = captureReg;
            Reg outreg = allocOutMaybe;
            if (outreg is null || outreg == fromreg) {
                return fromreg;
            } else {
                bytecode ~= Opcode.store_reg;
                bytecode ~= outreg.reg;
                bytecode ~= fromreg.reg;
                return outreg;
            }
        }

        vmError("Form: " ~ form.to!string);
        assert(false);
    }

    Node path(string name) {
        int where = -1;
        foreach (index, lvl; localss[0 .. $ - 1]) {
            if (name in lvl) {
                where = cast(int) index;
            }
        }
        assert(where >= 0, name);
        currentCaptures[where] ~= localss[where][name];
        captureValuess[where] ~= new Ident(name);
        inNthCaptures[where + 1][name] = cast(int) captureValuess[where].length;
        return new Form("index", new Form("capture"), new Value(cast(double) captureValuess[where].length));
    }

    Reg walkExact(Ident id) {
        if (double* pnum = id.repr in constants) {
            Reg ret = allocOut;
            bytecode ~= Opcode.store_int;
            bytecode ~= ret.reg;
            bytecode ~= ubytes(*pnum);
            return ret;
        } else if (Reg* fromreg = id.repr in locals) {
            Reg outreg = allocOutMaybe;
            if (outreg is null || outreg == *fromreg) {
                return *fromreg;
            } else {
                bytecode ~= Opcode.store_reg;
                bytecode ~= outreg.reg;
                bytecode ~= (*fromreg).reg;
                return outreg;
            }
        } else if (Node lookup = path(id.repr)) {
            Reg outreg = allocOutMaybe;
            Reg fromreg = walk(lookup, outreg);
            if (outreg is null || outreg == fromreg) {
                return fromreg;
            } else {
                bytecode ~= Opcode.store_reg;
                bytecode ~= outreg.reg;
                bytecode ~= fromreg.reg;
                return outreg;
            }
        } else {
            vmError("name resolution fail for: " ~ id.to!string);
            assert(false);
        }
    }

    Reg walkExact(Value val) {
        if (val.info == typeid(null)) {
            return null;
        } else if (val.info == typeid(double)) {
            Reg ret = allocOut;
            bytecode ~= Opcode.store_int;
            bytecode ~= ret.reg;
            bytecode ~= ubytes(*cast(double*) val.value);
            return ret;
        } else if (val.info == typeid(string)) {
            string src = *cast(string*) val.value;
            Reg outreg = allocOut;
            Reg[] regs;
            foreach (chr; src) {
                Reg reg = alloc;
                bytecode ~= Opcode.store_int;
                bytecode ~= reg.reg;
                bytecode ~= ubytes(cast(int) chr);
                regs ~= reg;
            }
            bytecode ~= Opcode.array;
            bytecode ~= outreg.reg;
            bytecode ~= ubytes(cast(int) src.length);
            foreach (reg; regs) {
                bytecode ~= reg.reg;
            }
            return outreg;
        } else {
            vmError("value type not supported yet: " ~ val.info.to!string);
            assert(false);
        }
    }
}
