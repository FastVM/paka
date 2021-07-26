module purr.ast.walk;

import core.memory;
import std.conv : to;
import std.stdio;
import std.string;
import std.algorithm;
import std.ascii;
import purr.ast.ast;
import purr.srcloc;
import purr.vm.bytecode;
import purr.type.repr;
import purr.type.err;

__gshared bool dumpast = false;

class Reg {
    int repr;
    string sym;

    this(T)(T n, string s = null) {
        if (n >= 256) {
            throw new Exception("reg too high");
        }
        if (n < 0) {
            throw new Exception("reg too low");
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
    Node[] nodes = [];

    Reg[string] regs;

    ubyte[] bytecode;

    Reg[] targets;

    void walkProgram(Node program) {
        if (dumpast) {
            writeln(program);
        }
        bytecode = null;
        walk(program);
        foreach (_; 0 .. 16) {
            bytecode ~= Opcode.exit;
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

    int n;
    string symbol() {
        n += 1;
        return "." ~ n.to!string;
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
        regs[symbol] = reg;
        return reg;
    }

    Reg local(string name) {
        if (Reg* ret = name in regs) {
            return *ret;
        } else {
            Reg reg = new Reg(regs.length, name);
            regs[name] = reg;
            return reg;
        }
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

    int jumpOn(bool doNotNegate)(Node node, int where = -1) {
        if (Form form = cast(Form) node) {
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
                    bytecode ~= ubytes(ret);
                    bytecode ~= rhs.reg;
                    bytecode ~= ubytes(*cast(double*) valueLeft.value);
                    return ret;
                } else if (Value valueRight = cast(Value) form.args[1]) {
                    assert(valueRight.info == typeid(double));
                    Reg lhs = walk(form.args[0]);
                    static if (doNotNegate) {
                        bytecode ~= Opcode.jump_if_equal_num;
                    } else {
                        bytecode ~= Opcode.jump_if_not_equal_num;
                    }
                    int ret = cast(int) bytecode.length;
                    bytecode ~= ubytes(ret);
                    bytecode ~= lhs.reg;
                    bytecode ~= ubytes(*cast(double*) valueRight.value);
                    return ret;
                } else {
                    Reg lhs = walk(form.args[0]);
                    Reg rhs = walk(form.args[1]);
                    static if (doNotNegate) {
                        bytecode ~= Opcode.jump_if_equal;
                    } else {
                        bytecode ~= Opcode.jump_if_not_equal;
                    }
                    int ret = cast(int) bytecode.length;
                    bytecode ~= ubytes(ret);
                    bytecode ~= lhs.reg;
                    bytecode ~= rhs.reg;
                    return ret;
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
                    bytecode ~= ubytes(ret);
                    bytecode ~= rhs.reg;
                    bytecode ~= ubytes(*cast(double*) valueLeft.value);
                    return ret;
                } else if (Value valueRight = cast(Value) form.args[1]) {
                    assert(valueRight.info == typeid(double));
                    Reg lhs = walk(form.args[0]);
                    static if (doNotNegate) {
                        bytecode ~= Opcode.jump_if_not_equal_num;
                    } else {
                        bytecode ~= Opcode.jump_if_equal_num;
                    }
                    int ret = cast(int) bytecode.length;
                    bytecode ~= ubytes(ret);
                    bytecode ~= lhs.reg;
                    bytecode ~= ubytes(*cast(double*) valueRight.value);
                    return ret;
                } else {
                    Reg lhs = walk(form.args[0]);
                    Reg rhs = walk(form.args[1]);
                    static if (doNotNegate) {
                        bytecode ~= Opcode.jump_if_not_equal;
                    } else {
                        bytecode ~= Opcode.jump_if_equal;
                    }
                    int ret = cast(int) bytecode.length;
                    bytecode ~= ubytes(ret);
                    bytecode ~= lhs.reg;
                    bytecode ~= rhs.reg;
                    return ret;
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
                    bytecode ~= ubytes(ret);
                    bytecode ~= rhs.reg;
                    bytecode ~= ubytes(*cast(double*) valueLeft.value);
                    return ret;
                } else if (Value valueRight = cast(Value) form.args[1]) {
                    assert(valueRight.info == typeid(double));
                    Reg lhs = walk(form.args[0]);
                    static if (doNotNegate) {
                        bytecode ~= Opcode.jump_if_less_num;
                    } else {
                        bytecode ~= Opcode.jump_if_greater_than_equal_num;
                    }
                    int ret = cast(int) bytecode.length;
                    bytecode ~= ubytes(ret);
                    bytecode ~= lhs.reg;
                    bytecode ~= ubytes(*cast(double*) valueRight.value);
                    return ret;
                } else {
                    Reg lhs = walk(form.args[0]);
                    Reg rhs = walk(form.args[1]);
                    static if (doNotNegate) {
                        bytecode ~= Opcode.jump_if_less;
                    } else {
                        bytecode ~= Opcode.jump_if_greater_than_equal;
                    }
                    int ret = cast(int) bytecode.length;
                    bytecode ~= ubytes(ret);
                    bytecode ~= lhs.reg;
                    bytecode ~= rhs.reg;
                    return ret;
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
                    bytecode ~= ubytes(ret);
                    bytecode ~= rhs.reg;
                    bytecode ~= ubytes(*cast(double*) valueLeft.value);
                    return ret;
                } else if (Value valueRight = cast(Value) form.args[1]) {
                    assert(valueRight.info == typeid(double));
                    Reg lhs = walk(form.args[0]);
                    static if (doNotNegate) {
                        bytecode ~= Opcode.jump_if_less_than_equal_num;
                    } else {
                        bytecode ~= Opcode.jump_if_greater_num;
                    }
                    int ret = cast(int) bytecode.length;
                    bytecode ~= ubytes(ret);
                    bytecode ~= lhs.reg;
                    bytecode ~= ubytes(*cast(double*) valueRight.value);
                    return ret;
                } else {
                    Reg lhs = walk(form.args[0]);
                    Reg rhs = walk(form.args[1]);
                    static if (doNotNegate) {
                        bytecode ~= Opcode.jump_if_less_than_equal;
                    } else {
                        bytecode ~= Opcode.jump_if_greater;
                    }
                    int ret = cast(int) bytecode.length;
                    bytecode ~= ubytes(ret);
                    bytecode ~= lhs.reg;
                    bytecode ~= rhs.reg;
                    return ret;
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
                    bytecode ~= ubytes(ret);
                    bytecode ~= rhs.reg;
                    bytecode ~= ubytes(*cast(double*) valueLeft.value);
                    return ret;
                } else if (Value valueRight = cast(Value) form.args[1]) {
                    assert(valueRight.info == typeid(double));
                    Reg lhs = walk(form.args[0]);
                    static if (doNotNegate) {
                        bytecode ~= Opcode.jump_if_greater_than_equal_num;
                    } else {
                        bytecode ~= Opcode.jump_if_less_num;
                    }
                    int ret = cast(int) bytecode.length;
                    bytecode ~= ubytes(ret);
                    bytecode ~= lhs.reg;
                    bytecode ~= ubytes(*cast(double*) valueRight.value);
                    return ret;
                } else {
                    Reg lhs = walk(form.args[0]);
                    Reg rhs = walk(form.args[1]);
                    static if (doNotNegate) {
                        bytecode ~= Opcode.jump_if_greater_than_equal;
                    } else {
                        bytecode ~= Opcode.jump_if_less;
                    }
                    int ret = cast(int) bytecode.length;
                    bytecode ~= ubytes(ret);
                    bytecode ~= lhs.reg;
                    bytecode ~= rhs.reg;
                    return ret;
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
        return ret;
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
                    throw new Exception("reg alloc fail for: " ~ form.to!string);
                }
                return last;
            }
        case "set":
            if (Ident id = cast(Ident) form.args[0]) {
                Reg target = local(id.repr);
                Reg from = walk(form.args[1], target);
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
                break;
            }
        case "if":
            int jumpFalseFrom = ifFalse(form.args[0]);
            walk(form.args[1]);
            bytecode ~= Opcode.jump_always;
            int jumpOutFrom = cast(int) bytecode.length;
            bytecode ~= ubytes(-1);
            int jumpFalseTo = cast(int) bytecode.length;
            walk(form.args[2]);
            int jumpOutTo = cast(int) bytecode.length;
            bytecode[jumpOutFrom .. jumpOutFrom + 4] = ubytes(jumpOutTo);
            bytecode[jumpFalseFrom .. jumpFalseFrom + 4] = ubytes(jumpFalseTo);
            return null;
        case "while":
            bytecode ~= Opcode.jump_always;
            int jumpCondFrom = cast(int) bytecode.length;
            bytecode ~= ubytes(-1);
            int jumpRedoTo = cast(int) bytecode.length;
            walk(form.args[1]);
            int jumpCondTo = cast(int) bytecode.length;
            int jumpRedoFrom = ifTrue(form.args[0]);
            bytecode[jumpCondFrom .. jumpCondFrom + 4] = ubytes(jumpCondTo);
            bytecode[jumpRedoFrom .. jumpRedoFrom + 4] = ubytes(jumpRedoTo);
            return null;
            // int redoLoop = cast(int) bytecode.length;
            // int jumpTarget = ifFalse(form.args[0]);
            // walk(form.args[1]);
            // bytecode ~= Opcode.jump_always;
            // bytecode ~= ubytes(redoLoop);
            // int exitPoint = cast(int) bytecode.length;
            // bytecode[jumpTarget .. jumpTarget + 4] = ubytes(exitPoint);
            // return null;
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
            Reg outLambdaReg = allocOut;
            bytecode ~= Opcode.store_fun;
            bytecode ~= outLambdaReg.reg;
            int refLength = cast(int) bytecode.length;
            bytecode ~= ubytes(-1);
            Reg[string] oldRegs = regs;
            regs = null;
            foreach (index, arg; argnames) {
                regs[arg] = new Reg(index);
            }
            n = cast(int) argnames.length;
            Reg retreg = walk(form.args[1]);
            if (retreg !is null) {
                bytecode ~= Opcode.ret;
                bytecode ~= retreg.reg;
            } else {
                bytecode ~= Opcode.ret;
                bytecode ~= alloc().reg;
            }
            regs = oldRegs;
            int funcEnd = cast(int) bytecode.length;
            bytecode[refLength .. refLength + 4] = ubytes(funcEnd);
            return outLambdaReg;
        case "call":
            bool isRec = false;
            if (Ident func = cast(Ident) form.args[0]) {
                if (func.repr == "println") {
                    Reg outreg = walk(form.args[1]);
                    bytecode ~= Opcode.println;
                    bytecode ~= outreg.reg;
                    return allocOut;
                }
                if (func.repr == "rec") {
                    isRec = true;
                }
            }
            Reg funreg;
            if (!isRec) {
                funreg = walk(form.args[0]);
            }
            Reg[] argRegs;
            foreach (index, arg; form.args[1 .. $]) {
                argRegs ~= walk(arg);
            }
            Reg outreg = allocOut;
            if (isRec) {
                bytecode ~= Opcode.rec;
            } else {
                bytecode ~= Opcode.call;
                bytecode ~= funreg.reg;
            }
            bytecode ~= outreg.reg;
            bytecode ~= ubytes(cast(int) argRegs.length);
            foreach (reg; argRegs) {
                bytecode ~= reg.reg;
            }
            return outreg;
        case "return":
            if (Form callForm = cast(Form) form.args[0]) {
                if (callForm.form == "call") {
                    bool isRec = false;
                    if (Ident func = cast(Ident) callForm.args[0]) {
                        if (func.repr == "println") {
                            goto noTailCallPossible;
                        }
                        if (func.repr == "rec") {
                            isRec = true;
                        }
                    }
                    Reg funreg;
                    if (!isRec) {
                        funreg = walk(callForm.args[0]);
                    }
                    Reg[] argRegs;
                    foreach (index, arg; callForm.args[1 .. $]) {
                        argRegs ~= walk(arg);
                    }
                    if (isRec) {
                        bytecode ~= Opcode.tail_rec;
                    } else {
                        bytecode ~= Opcode.tail_call;
                        bytecode ~= funreg.reg;
                    }
                    bytecode ~= ubytes(cast(int) argRegs.length);
                    foreach (reg; argRegs) {
                        bytecode ~= reg.reg;
                    }
                    return null;
                }
            }
        noTailCallPossible:
            Reg res = walk(form.args[0]);
            bytecode ~= Opcode.ret;
            bytecode ~= res.reg;
            return res;
        }

        throw new Exception("Form: " ~ form.to!string);
    }

    Reg walkExact(Ident id) {
        Reg outreg = allocOutMaybe;
        if (id.repr !in regs) {
            throw new Exception("name resolution fail for: " ~ id.to!string);
        }
        Reg fromreg = local(id.repr);
        if (outreg is null || outreg == fromreg) {
            return fromreg;
        } else {
            bytecode ~= Opcode.store_reg;
            bytecode ~= outreg.reg;
            bytecode ~= fromreg.reg;
            return outreg;
        }
    }

    Reg walkExact(Value val) {
        if (val.info == typeid(null)) {
            return null;
        } else if (val.info == typeid(bool)) {
            Reg ret = allocOut;
            bytecode ~= Opcode.store_log;
            bytecode ~= ret.reg;
            bytecode ~= ubytes(*cast(bool*) val.value);
            return ret;
        } else if (val.info == typeid(double)) {
            Reg ret = allocOut;
            bytecode ~= Opcode.store_num;
            bytecode ~= ret.reg;
            bytecode ~= ubytes(*cast(double*) val.value);
            return ret;
        } else {
            throw new Exception("value type not supported yet: " ~ val.info.to!string);
        }
    }
}
