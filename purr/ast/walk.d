module purr.ast.walk;

import std.conv : to;
import purr.ast.ast: Node, Form, Ident, Value, NodeKind;
import purr.err: vmError, vmCheckError;
import purr.ast.lift: Lifter;
import purr.ast.optcall: CallOpt;
import purr.vm.bytecode: Opcode;

enum jumpTmp = -1;

enum jumpSize = 1;

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

    uint reg() {
        return (cast(uint) repr);
    }

    override bool opEquals(Object other) {
        Reg oreg = cast(Reg) other;
        return oreg !is null && repr == oreg.repr;
    }

    override string toString() {
        if (sym.length == 0) {
            return "." ~ repr.to!string;
        } else {
            return "(reg: " ~ sym ~ ")";
        }
    }
}

final class Walker {
    bool xinstrs = true;

    Node[] nodes;

    int[][string][] jumpLocss;
    int[string][] jumpLabelss;
    double[string][] inNthCaptures;

    Reg[string][] localss;

    Reg[] regs;

    uint[] bytecode;

    Reg[] targets;

    int[string] funcs;
    int[][string] replaces;

    ref Reg[string] locals() {
        return localss[$ - 1];
    }

    ref int[][string] jumpLocs() {
        return jumpLocss[$ - 1];
    }

    ref int[string] jumpLabels() {
        return jumpLabelss[$ - 1];
    }

    void fixGotoLabels() {
        foreach (name, where; jumpLabels) {
            if (name !in jumpLocs) {
                continue;
            }
            foreach (ent; jumpLocs[name]) {
                bytecode[ent .. ent + 4] = jump(where);
            }
        }
    }

    void walkProgram(Node program, bool lift = true) {
        if (lift) {
            Lifter lifter = new Lifter;
            Node lifted = lifter.liftProgram(program);
            CallOpt ca = new CallOpt;
            Node cad = ca.optCalls(lifted);
            program = cad;
        }
        localss.length++;
        jumpLocss.length++;
        jumpLabelss.length++;
        inNthCaptures.length++;
        scope (exit) {
            fixGotoLabels();
            localss.length--;
            jumpLocss.length--;
            jumpLabelss.length--;
            inNthCaptures.length--;
        }
        bytecode = null;
        locals["this"] = new Reg(0);
        walk(program);
        bytecode ~= Opcode.exit;
        foreach (name, locs; replaces) {
            if (int* setto = name in funcs) {
                foreach (n; locs) {
                    bytecode[n .. n + jumpSize] = jump(*setto);
                }
            } else {
                vmError("function not found: " ~ name);
            }
        }
    }

    uint[1] literal(bool val) {
        return [cast(uint) val];
    }

    uint[1] jump(int val) {
        return [cast(uint) val];
    }

    uint[1] literal(double val) {
        vmCheckError(val % 1 == 0, "floats are broken, sadly");
        int inum = cast(int) val;
        return cast(uint[])[inum];
    }

    Reg allocOut() {
        if (targets[$ - 1]!is null) {
            return targets[$ - 1];
        }
        return alloc(nodes[$ - 1]);
    }

    Reg allocOutMaybe() {
        if (targets[$ - 1]!is null) {
            return targets[$ - 1];
        }
        return null;
    }

    Reg alloc(Node isFor = null) {
        // if (isFor !is null) {
        //     Reg reg = new Reg(regs.length + 1, isFor.to!string);
        //     regs ~= reg;
        //     return reg;
        // } else {
            Reg reg = new Reg(regs.length + 1);
            regs ~= reg;
            return reg;
        // }
    }

    Reg walk(Node node, Reg target = null) {
        targets ~= target;
        nodes ~= node;
        scope (exit) {
            targets.length--;
            nodes.length--;
        }
        final switch (node.id) {
        case NodeKind.base:
            assert(false);
        case NodeKind.call:
            return walkExact(cast(Form) node);
        case NodeKind.ident:
            return walkExact(cast(Ident) node);
        case NodeKind.value:
            return walkExact(cast(Value) node);
        }
    }

    int[][2] ifTrue(Node node, int where = -1) {
        if (Form form = cast(Form) node) {
            if (form.form == "||") {
                int[][2] reta = ifTrue(form.getArg(0), where);
                int midj = cast(int) bytecode.length;
                int[][2] retb = ifTrue(form.getArg(1), where);
                foreach (i; reta[1]) {
                    bytecode[i .. i + jumpSize] = midj;
                }
                return [reta[0] ~ retb[0], retb[1]];
            }
            if (form.form == "&&") {
                int[][2] reta = ifTrue(form.getArg(0), where);
                int midj = cast(int) bytecode.length;
                int[][2] retb = ifTrue(form.getArg(1), where);
                foreach (i; reta[0]) {
                    bytecode[i .. i + jumpSize] = midj;
                }
                return [retb[0], reta[1] ~ retb[1]];
            }
            if (form.form == "==") {
                if (xinstrs) {
                    if (Value valueLeft = cast(Value) form.getArg(0)) {
                        if (valueLeft.info != typeid(double)) {
                            goto cmpEq;
                        }
                        Reg rhs = walk(form.getArg(1));
                        bytecode ~= Opcode.branch_equal_num;
                        int ret1 = cast(int) bytecode.length;
                        bytecode ~= jump(where);
                        int ret2 = cast(int) bytecode.length;
                        bytecode ~= jump(where);
                        bytecode ~= rhs.reg;
                        bytecode ~= literal(*cast(double*) valueLeft.value);
                        return [[ret1], [ret2]];
                    } else if (Value valueRight = cast(Value) form.getArg(1)) {
                        if (valueRight.info != typeid(double)) {
                            goto cmpEq;
                        }
                        Reg lhs = walk(form.getArg(0));
                        bytecode ~= Opcode.branch_equal_num;
                        int ret1 = cast(int) bytecode.length;
                        bytecode ~= jump(where);
                        int ret2 = cast(int) bytecode.length;
                        bytecode ~= jump(where);
                        bytecode ~= lhs.reg;
                        bytecode ~= literal(*cast(double*) valueRight.value);
                        return [[ret1], [ret2]];
                    }
                }
            cmpEq:
                Reg lhs = walk(form.getArg(0));
                Reg rhs = walk(form.getArg(1));
                bytecode ~= Opcode.branch_equal;
                int ret1 = cast(int) bytecode.length;
                bytecode ~= jump(where);
                int ret2 = cast(int) bytecode.length;
                bytecode ~= jump(where);
                bytecode ~= lhs.reg;
                bytecode ~= rhs.reg;
                return [[ret1], [ret2]];
            }
            if (form.form == "!=") {
                if (xinstrs) {
                    if (Value valueLeft = cast(Value) form.getArg(0)) {
                        if (valueLeft.info != typeid(double)) {
                            goto cmpNeq;
                        }
                        Reg rhs = walk(form.getArg(1));
                        bytecode ~= Opcode.branch_not_equal_num;
                        int ret1 = cast(int) bytecode.length;
                        bytecode ~= jump(where);
                        int ret2 = cast(int) bytecode.length;
                        bytecode ~= jump(where);
                        bytecode ~= rhs.reg;
                        bytecode ~= literal(*cast(double*) valueLeft.value);
                        return [[ret1], [ret2]];
                    } else if (Value valueRight = cast(Value) form.getArg(1)) {
                        if (valueRight.info != typeid(double)) {
                            goto cmpNeq;
                        }
                        Reg lhs = walk(form.getArg(0));
                        bytecode ~= Opcode.branch_not_equal_num;
                        int ret1 = cast(int) bytecode.length;
                        bytecode ~= jump(where);
                        int ret2 = cast(int) bytecode.length;
                        bytecode ~= jump(where);
                        bytecode ~= lhs.reg;
                        bytecode ~= literal(*cast(double*) valueRight.value);
                        return [[ret1], [ret2]];
                    }
                }
            cmpNeq:
                Reg lhs = walk(form.getArg(0));
                Reg rhs = walk(form.getArg(1));
                bytecode ~= Opcode.branch_not_equal;
                int ret1 = cast(int) bytecode.length;
                bytecode ~= jump(where);
                int ret2 = cast(int) bytecode.length;
                bytecode ~= jump(where);
                bytecode ~= lhs.reg;
                bytecode ~= rhs.reg;
                return [[ret1], [ret2]];
            }
            if (form.form == "<") {
                if (xinstrs) {
                    if (Value valueLeft = cast(Value) form.getArg(0)) {
                        vmCheckError(valueLeft.info == typeid(double), "expected number");
                        Reg rhs = walk(form.getArg(1));
                        bytecode ~= Opcode.branch_greater_num;
                        int ret1 = cast(int) bytecode.length;
                        bytecode ~= jump(where);
                        int ret2 = cast(int) bytecode.length;
                        bytecode ~= jump(where);
                        bytecode ~= rhs.reg;
                        bytecode ~= literal(*cast(double*) valueLeft.value);
                        return [[ret1], [ret2]];
                    } else if (Value valueRight = cast(Value) form.getArg(1)) {
                        vmCheckError(valueRight.info == typeid(double), "expected number");
                        Reg lhs = walk(form.getArg(0));
                        bytecode ~= Opcode.branch_less_num;
                        int ret1 = cast(int) bytecode.length;
                        bytecode ~= jump(where);
                        int ret2 = cast(int) bytecode.length;
                        bytecode ~= jump(where);
                        bytecode ~= lhs.reg;
                        bytecode ~= literal(*cast(double*) valueRight.value);
                        return [[ret1], [ret2]];
                    }
                }
                Reg lhs = walk(form.getArg(0));
                Reg rhs = walk(form.getArg(1));
                bytecode ~= Opcode.branch_less;
                int ret1 = cast(int) bytecode.length;
                bytecode ~= jump(where);
                int ret2 = cast(int) bytecode.length;
                bytecode ~= jump(where);
                bytecode ~= lhs.reg;
                bytecode ~= rhs.reg;
                return [[ret1], [ret2]];
            }
            if (form.form == ">") {
                if (xinstrs) {
                    if (Value valueLeft = cast(Value) form.getArg(0)) {
                        vmCheckError(valueLeft.info == typeid(double), "expected number");
                        Reg rhs = walk(form.getArg(1));
                        bytecode ~= Opcode.branch_less_num;
                        int ret1 = cast(int) bytecode.length;
                        bytecode ~= jump(where);
                        int ret2 = cast(int) bytecode.length;
                        bytecode ~= jump(where);
                        bytecode ~= rhs.reg;
                        bytecode ~= literal(*cast(double*) valueLeft.value);
                        return [[ret1], [ret2]];
                    } else if (Value valueRight = cast(Value) form.getArg(1)) {
                        vmCheckError(valueRight.info == typeid(double), "expected number");
                        Reg lhs = walk(form.getArg(0));
                        bytecode ~= Opcode.branch_greater_num;
                        int ret1 = cast(int) bytecode.length;
                        bytecode ~= jump(where);
                        int ret2 = cast(int) bytecode.length;
                        bytecode ~= jump(where);
                        bytecode ~= lhs.reg;
                        bytecode ~= literal(*cast(double*) valueRight.value);
                        return [[ret1], [ret2]];
                    }
                }
                Reg lhs = walk(form.getArg(0));
                Reg rhs = walk(form.getArg(1));
                bytecode ~= Opcode.branch_greater;
                int ret1 = cast(int) bytecode.length;
                bytecode ~= jump(where);
                int ret2 = cast(int) bytecode.length;
                bytecode ~= jump(where);
                bytecode ~= lhs.reg;
                bytecode ~= rhs.reg;
                return [[ret1], [ret2]];
            }
            if (form.form == "<=") {
                if (xinstrs) {
                    if (Value valueLeft = cast(Value) form.getArg(0)) {
                        vmCheckError(valueLeft.info == typeid(double), "expected number");
                        Reg rhs = walk(form.getArg(1));
                        bytecode ~= Opcode.branch_greater_than_equal_num;
                        int ret1 = cast(int) bytecode.length;
                        bytecode ~= jump(where);
                        int ret2 = cast(int) bytecode.length;
                        bytecode ~= jump(where);
                        bytecode ~= rhs.reg;
                        bytecode ~= literal(*cast(double*) valueLeft.value);
                        return [[ret1], [ret2]];
                    } else if (Value valueRight = cast(Value) form.getArg(1)) {
                        vmCheckError(valueRight.info == typeid(double), "expected number");
                        Reg lhs = walk(form.getArg(0));
                        bytecode ~= Opcode.branch_less_than_equal_num;
                        int ret1 = cast(int) bytecode.length;
                        bytecode ~= jump(where);
                        int ret2 = cast(int) bytecode.length;
                        bytecode ~= jump(where);
                        bytecode ~= lhs.reg;
                        bytecode ~= literal(*cast(double*) valueRight.value);
                        return [[ret1], [ret2]];
                    }
                }
                Reg lhs = walk(form.getArg(0));
                Reg rhs = walk(form.getArg(1));
                bytecode ~= Opcode.branch_less_than_equal;
                int ret1 = cast(int) bytecode.length;
                bytecode ~= jump(where);
                int ret2 = cast(int) bytecode.length;
                bytecode ~= jump(where);
                bytecode ~= lhs.reg;
                bytecode ~= rhs.reg;
                return [[ret1], [ret2]];
            }
            if (form.form == ">=") {
                if (xinstrs) {
                    if (Value valueLeft = cast(Value) form.getArg(0)) {
                        vmCheckError(valueLeft.info == typeid(double), "expected number");
                        Reg rhs = walk(form.getArg(1));
                        bytecode ~= Opcode.branch_less_than_equal_num;
                        int ret1 = cast(int) bytecode.length;
                        bytecode ~= jump(where);
                        int ret2 = cast(int) bytecode.length;
                        bytecode ~= jump(where);
                        bytecode ~= rhs.reg;
                        bytecode ~= literal(*cast(double*) valueLeft.value);
                        return [[ret1], [ret2]];
                    } else if (Value valueRight = cast(Value) form.getArg(1)) {
                        vmCheckError(valueRight.info == typeid(double), "expected number");
                        Reg lhs = walk(form.getArg(0));
                        bytecode ~= Opcode.branch_greater_than_equal_num;
                        int ret1 = cast(int) bytecode.length;
                        bytecode ~= jump(where);
                        int ret2 = cast(int) bytecode.length;
                        bytecode ~= jump(where);
                        bytecode ~= lhs.reg;
                        bytecode ~= literal(*cast(double*) valueRight.value);
                        return [[ret1], [ret2]];
                    }
                }
                Reg lhs = walk(form.getArg(0));
                Reg rhs = walk(form.getArg(1));
                bytecode ~= Opcode.branch_greater_than_equal;
                int ret1 = cast(int) bytecode.length;
                bytecode ~= jump(where);
                int ret2 = cast(int) bytecode.length;
                bytecode ~= jump(where);
                bytecode ~= lhs.reg;
                bytecode ~= rhs.reg;
                return [[ret1], [ret2]];
            }
        }
        Reg cmp = walk(node);
        bytecode ~= Opcode.branch_true;
        int ret1 = cast(int) bytecode.length;
        bytecode ~= jump(where);
        int ret2 = cast(int) bytecode.length;
        bytecode ~= jump(where);
        bytecode ~= cmp.reg;
        return [[ret1], [ret2]];
    }

    Reg walkExact(Form form) {
        switch (form.form) {
        default:
            break;
        case "label":
            Ident label = cast(Ident) form.getArg(0);
            jumpLabels[label.repr] = cast(int) bytecode.length;
            return null;
        case "goto":
            Ident label = cast(Ident) form.getArg(0);
            bytecode ~= Opcode.jump;
            if (int[]* places = label.repr in jumpLocs) {
                *places ~= cast(int) bytecode.length;
            } else {
                jumpLocs[label.repr] = [cast(int) bytecode.length];
            }
            bytecode ~= jumpTmp;
            return null;
        case "do":
            if (form.args.length == 0) {
                Reg ret = allocOutMaybe;
                if (ret is null) {
                    return ret;
                }
                bytecode ~= Opcode.store_none;
                bytecode ~= ret.reg;
                return ret;
            } else {
                Reg ret = allocOutMaybe;
                foreach (elem; form.sliceArg(0, 1)) {
                    walk(elem);
                }
                Reg last = walk(form.getArg(form.args.length - 1), ret);
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
            bytecode ~= Opcode.array_new;
            bytecode ~= outreg.reg;
            bytecode ~= cast(uint) regs.length;
            foreach (reg; regs) {
                bytecode ~= reg.reg;
            }
            return outreg;
        case "map":
            Reg outreg = allocOut;
            bytecode ~= Opcode.map_new;
            bytecode ~= outreg.reg;
            return outreg;
        case "index":
            Reg outreg = allocOut;
            Reg objreg = walk(form.getArg(0));
            Reg index = walk(form.getArg(1));
            bytecode ~= Opcode.index_get;
            bytecode ~= outreg.reg;
            bytecode ~= objreg.reg;
            bytecode ~= index.reg;
            return outreg;
        case "length":
            Reg outreg = allocOut;
            Reg objreg = walk(form.getArg(0), outreg);
            bytecode ~= Opcode.length;
            bytecode ~= outreg.reg;
            bytecode ~= objreg.reg;
            return outreg;
        case "box":
            Reg outreg = allocOut;
            Reg objreg = walk(form.getArg(0), outreg);
            bytecode ~= Opcode.box_new;
            bytecode ~= outreg.reg;
            bytecode ~= objreg.reg;
            return outreg;
        case "ref":
            Reg outreg = allocOut;
            Reg objreg = walk(form.getArg(0));
            bytecode ~= Opcode.ref_new;
            bytecode ~= outreg.reg;
            bytecode ~= objreg.reg;
            return outreg;
        case "deref":
            Reg outreg = allocOut;
            Reg objreg = walk(form.getArg(0), outreg);
            bytecode ~= Opcode.ref_get;
            bytecode ~= outreg.reg;
            bytecode ~= objreg.reg;
            return outreg;
        case "unbox":
            Reg outreg = allocOut;
            Reg objreg = walk(form.getArg(0), outreg);
            bytecode ~= Opcode.box_get;
            bytecode ~= outreg.reg;
            bytecode ~= objreg.reg;
            return outreg;
        case "decl":
            if (Ident id = cast(Ident) form.getArg(0)) {
                locals[id.repr] = alloc(id);
                return null;
            } else {
                vmError("decl to bad value");
                assert(false);
            }
        case "handle":
            Reg valueReg = walk(form.getArg(1));
            Reg nameReg = walk(form.getArg(0));
            bytecode ~= Opcode.set_handler;
            bytecode ~= nameReg.reg;
            bytecode ~= valueReg.reg;
            return null;
        case "throw":
            Reg outreg = allocOut;
            Reg valueReg = walk(form.getArg(0));
            bytecode ~= Opcode.call_handler;
            bytecode ~= outreg.reg;
            bytecode ~= valueReg.reg;
            return outreg;
        case "resolve":
            Reg valueReg = walk(form.getArg(0));
            bytecode ~= Opcode.return_handler;
            bytecode ~= valueReg.reg;
            return null;
        case "reject":
            Reg valueReg = walk(form.getArg(0));
            bytecode ~= Opcode.exit_handler;
            bytecode ~= valueReg.reg;
            return null;
        case "exit":
            bytecode ~= Opcode.exit;
            return null;
        case "set":
            if (Ident id = cast(Ident) form.getArg(0)) {
                Reg target;
                if (Reg* ret = id.repr in locals) {
                    target = *ret;
                } else {
                    vmError("set to unknown variable: " ~ id.repr);
                }
                Reg from = walk(form.getArg(1), target);
                if (from is null) {
                    bytecode ~= Opcode.store_none;
                    bytecode ~= target.reg;
                } else if (target != from) {
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
            } else if (Form call = cast(Form) form.getArg(0)) {
                if (call.form == "index") {
                    Reg arrayReg = walk(call.getArg(0));
                    Reg indexReg = walk(call.getArg(1));
                    Reg valueReg = walk(form.getArg(1));
                    bytecode ~= Opcode.index_set, bytecode ~= arrayReg.reg;
                    bytecode ~= indexReg.reg;
                    bytecode ~= valueReg.reg;
                    return arrayReg;
                } else if (call.form == "unbox") {
                    Reg boxReg = walk(call.getArg(0));
                    Reg valueReg = walk(form.getArg(1));
                    bytecode ~= Opcode.box_set, bytecode ~= boxReg.reg;
                    bytecode ~= valueReg.reg;
                    return boxReg;
                } else if (call.form == "deref") {
                    Reg boxReg = walk(call.getArg(0));
                    Reg valueReg = walk(form.getArg(1));
                    bytecode ~= Opcode.ref_set, bytecode ~= boxReg.reg;
                    bytecode ~= valueReg.reg;
                    return boxReg;
                } else if (call.form == "do") {
                    Reg target = walk(form.getArg(0));
                    Reg from = walk(form.getArg(1), target);
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
            } else {
                vmError("set to bad value");
                assert(false);
            }
        case "if":
            Reg outreg = allocOut;
            int[][2] jumpPairs = ifTrue(form.getArg(0));
            int jumpTrueTo = cast(int) bytecode.length;
            walk(form.getArg(1), outreg);
            bytecode ~= Opcode.jump;
            int jumpOutFrom = cast(int) bytecode.length;
            bytecode ~= jumpTmp;
            int jumpFalseTo = cast(int) bytecode.length;
            Node arg2 = new Value(0);
            if (form.args.length > 2) {
                arg2 = form.getArg(2);
            }
            walk(arg2, outreg);
            int jumpOutTo = cast(int) bytecode.length;
            bytecode[jumpOutFrom .. jumpOutFrom + jumpSize] = jump(jumpOutTo);
            foreach (j; jumpPairs[0]) {
                bytecode[j .. j + jumpSize] = jump(jumpTrueTo);
            }
            foreach (j; jumpPairs[1]) {
                bytecode[j .. j + jumpSize] = jump(jumpFalseTo);
            }
            return outreg;
        case "while":
            bytecode ~= Opcode.jump;
            int jumpCondFrom = cast(int) bytecode.length;
            bytecode ~= jumpTmp;
            int jumpTrueTo = cast(int) bytecode.length;
            walk(form.getArg(1));
            int jumpCondTo = cast(int) bytecode.length;
            int[][2] jumpPairs = ifTrue(form.getArg(0));
            int jumpFalseTo = cast(int) bytecode.length;
            bytecode[jumpCondFrom .. jumpCondFrom + jumpSize] = jumpCondTo;
            foreach (j; jumpPairs[0]) {
                bytecode[j .. j + jumpSize] = jump(jumpTrueTo);
            }
            foreach (j; jumpPairs[1]) {
                bytecode[j .. j + jumpSize] = jump(jumpFalseTo);
            }
            return null;
        case "~":
            Reg lhs = walk(form.getArg(0));
            Reg rhs = walk(form.getArg(1));
            Reg res = allocOut;
            bytecode ~= Opcode.concat;
            bytecode ~= res.reg;
            bytecode ~= lhs.reg;
            bytecode ~= rhs.reg;
            return res;
        case "+":
            if (xinstrs) {
                if (Value valueLeft = cast(Value) form.getArg(0)) {
                    Reg rhs = walk(form.getArg(1));
                    Reg res = allocOut;
                    if (res == rhs) {
                        bytecode ~= Opcode.inc_num;
                        bytecode ~= res.reg;
                    } else {
                        bytecode ~= Opcode.add_num;
                        bytecode ~= res.reg;
                        bytecode ~= rhs.reg;
                    }
                    vmCheckError(valueLeft.info == typeid(double), "expected number");
                    bytecode ~= literal(*cast(double*) valueLeft.value);
                    return res;
                } else if (Value valueRight = cast(Value) form.getArg(1)) {
                    Reg lhs = walk(form.getArg(0));
                    Reg res = allocOut;
                    if (res == lhs) {
                        bytecode ~= Opcode.inc_num;
                        bytecode ~= res.reg;
                    } else {
                        bytecode ~= Opcode.add_num;
                        bytecode ~= res.reg;
                        bytecode ~= lhs.reg;
                    }
                    vmCheckError(valueRight.info == typeid(double), "expected number");
                    bytecode ~= literal(*cast(double*) valueRight.value);
                    return res;
                }
            }
            Reg lhs = walk(form.getArg(0));
            Reg rhs = walk(form.getArg(1));
            Reg res = allocOut;
            if (xinstrs) {
                if (lhs == res) {
                    bytecode ~= Opcode.inc;
                    bytecode ~= res.reg;
                    bytecode ~= rhs.reg;
                    return res;
                } else if (rhs == res) {
                    bytecode ~= Opcode.inc;
                    bytecode ~= res.reg;
                    bytecode ~= lhs.reg;
                    return res;
                }
            }
            bytecode ~= Opcode.add;
            bytecode ~= res.reg;
            bytecode ~= lhs.reg;
            bytecode ~= rhs.reg;
            return res;
        case "-":
            if (xinstrs) {
                if (Value valueRight = cast(Value) form.getArg(1)) {
                    Reg lhs = walk(form.getArg(0));
                    Reg res = allocOut;
                    if (lhs == res) {
                        bytecode ~= Opcode.dec_num;
                        bytecode ~= res.reg;
                    } else {
                        bytecode ~= Opcode.sub_num;
                        bytecode ~= res.reg;
                        bytecode ~= lhs.reg;
                    }
                    vmCheckError(valueRight.info == typeid(double), "expected number");
                    bytecode ~= literal(*cast(double*) valueRight.value);
                    return res;
                }
            }
            Reg lhs = walk(form.getArg(0));
            Reg rhs = walk(form.getArg(1));
            Reg res = allocOut;
            if (xinstrs) {
                if (lhs == res) {
                    bytecode ~= Opcode.dec;
                    bytecode ~= res.reg;
                    bytecode ~= rhs.reg;
                    return res;
                }
            }
            bytecode ~= Opcode.sub;
            bytecode ~= res.reg;
            bytecode ~= lhs.reg;
            bytecode ~= rhs.reg;
            return res;
        case "*":
            if (xinstrs) {
                if (Value valueLeft = cast(Value) form.getArg(0)) {
                    Reg rhs = walk(form.getArg(1));
                    Reg res = allocOut;
                    bytecode ~= Opcode.mul_num;
                    bytecode ~= res.reg;
                    bytecode ~= rhs.reg;
                    vmCheckError(valueLeft.info == typeid(double), "expected number");
                    bytecode ~= literal(*cast(double*) valueLeft.value);
                    return res;
                } else if (Value valueRight = cast(Value) form.getArg(1)) {
                    Reg lhs = walk(form.getArg(0));
                    Reg res = allocOut;
                    bytecode ~= Opcode.mul_num;
                    bytecode ~= res.reg;
                    bytecode ~= lhs.reg;
                    vmCheckError(valueRight.info == typeid(double), "expected number");
                    bytecode ~= literal(*cast(double*) valueRight.value);
                    return res;
                }
            }
            Reg lhs = walk(form.getArg(0));
            Reg rhs = walk(form.getArg(1));
            Reg res = allocOut;
            bytecode ~= Opcode.mul;
            bytecode ~= res.reg;
            bytecode ~= lhs.reg;
            bytecode ~= rhs.reg;
            return res;
        case "/":
            if (xinstrs) {
                if (Value valueRight = cast(Value) form.getArg(1)) {
                    Reg lhs = walk(form.getArg(0));
                    Reg res = allocOut;
                    bytecode ~= Opcode.div_num;
                    bytecode ~= res.reg;
                    bytecode ~= lhs.reg;
                    vmCheckError(valueRight.info == typeid(double), "expected number");
                    bytecode ~= literal(*cast(double*) valueRight.value);
                    return res;
                }
            }
            Reg lhs = walk(form.getArg(0));
            Reg rhs = walk(form.getArg(1));
            Reg res = allocOut;
            bytecode ~= Opcode.div;
            bytecode ~= res.reg;
            bytecode ~= lhs.reg;
            bytecode ~= rhs.reg;
            return res;
        case "%":
            if (xinstrs) {
                if (Value valueRight = cast(Value) form.getArg(1)) {
                    Reg lhs = walk(form.getArg(0));
                    Reg res = allocOut;
                    bytecode ~= Opcode.mod_num;
                    bytecode ~= res.reg;
                    bytecode ~= lhs.reg;
                    vmCheckError(valueRight.info == typeid(double), "expected number");
                    bytecode ~= literal(*cast(double*) valueRight.value);
                    return res;
                }
            }
            Reg lhs = walk(form.getArg(0));
            Reg rhs = walk(form.getArg(1));
            Reg res = allocOut;
            bytecode ~= Opcode.mod;
            bytecode ~= res.reg;
            bytecode ~= lhs.reg;
            bytecode ~= rhs.reg;
            return res;
        case "==":
            if (!xinstrs) {
                return walk(new Form("if", form, new Value(1), new Value(0)));
            }
            if (Value valueLeft = cast(Value) form.getArg(0)) {
                if (valueLeft.info != typeid(double)) {
                    goto cmpEq;
                }
                Reg rhs = walk(form.getArg(1));
                Reg res = allocOut;
                bytecode ~= Opcode.equal_num;
                bytecode ~= res.reg;
                bytecode ~= rhs.reg;
                vmCheckError(valueLeft.info == typeid(double), "expected number");
                bytecode ~= literal(*cast(double*) valueLeft.value);
                return res;
            } else if (Value valueRight = cast(Value) form.getArg(1)) {
                if (valueRight.info != typeid(double)) {
                    goto cmpEq;
                }
                Reg lhs = walk(form.getArg(0));
                Reg res = allocOut;
                bytecode ~= Opcode.equal_num;
                bytecode ~= res.reg;
                bytecode ~= lhs.reg;
                bytecode ~= literal(*cast(double*) valueRight.value);
                return res;
            }
        cmpEq:
            Reg lhs = walk(form.getArg(0));
            Reg rhs = walk(form.getArg(1));
            Reg res = allocOut;
            bytecode ~= Opcode.equal;
            bytecode ~= res.reg;
            bytecode ~= lhs.reg;
            bytecode ~= rhs.reg;
            return res;
        case "!=":
            if (!xinstrs) {
                return walk(new Form("if", form, new Value(1), new Value(0)));
            }
            if (Value valueLeft = cast(Value) form.getArg(0)) {
                if (valueLeft.info != typeid(double)) {
                    goto cmpNeq;
                }
                Reg rhs = walk(form.getArg(1));
                Reg res = allocOut;
                bytecode ~= Opcode.not_equal_num;
                bytecode ~= res.reg;
                bytecode ~= rhs.reg;
                vmCheckError(valueLeft.info == typeid(double), "expected number");
                bytecode ~= literal(*cast(double*) valueLeft.value);
                return res;
            } else if (Value valueRight = cast(Value) form.getArg(1)) {
                if (valueRight.info != typeid(double)) {
                    goto cmpNeq;
                }
                Reg lhs = walk(form.getArg(0));
                Reg res = allocOut;
                bytecode ~= Opcode.not_equal_num;
                bytecode ~= res.reg;
                bytecode ~= lhs.reg;
                vmCheckError(valueRight.info == typeid(double), "expected number");
                bytecode ~= literal(*cast(double*) valueRight.value);
                return res;
            }
        cmpNeq:
            Reg lhs = walk(form.getArg(0));
            Reg rhs = walk(form.getArg(1));
            Reg res = allocOut;
            bytecode ~= Opcode.not_equal;
            bytecode ~= res.reg;
            bytecode ~= lhs.reg;
            bytecode ~= rhs.reg;
            return res;
        case "<":
            if (!xinstrs) {
                return walk(new Form("if", form, new Value(1), new Value(0)));
            }
            if (Value valueLeft = cast(Value) form.getArg(0)) {
                Reg rhs = walk(form.getArg(1));
                Reg res = allocOut;
                bytecode ~= Opcode.greater_num;
                bytecode ~= res.reg;
                bytecode ~= rhs.reg;
                vmCheckError(valueLeft.info == typeid(double), "expected number");
                bytecode ~= literal(*cast(double*) valueLeft.value);
                return res;
            } else if (Value valueRight = cast(Value) form.getArg(1)) {
                Reg lhs = walk(form.getArg(0));
                Reg res = allocOut;
                bytecode ~= Opcode.less_num;
                bytecode ~= res.reg;
                bytecode ~= lhs.reg;
                vmCheckError(valueRight.info == typeid(double), "expected number");
                bytecode ~= literal(*cast(double*) valueRight.value);
                return res;
            } else {
                Reg lhs = walk(form.getArg(0));
                Reg rhs = walk(form.getArg(1));
                Reg res = allocOut;
                bytecode ~= Opcode.less;
                bytecode ~= res.reg;
                bytecode ~= lhs.reg;
                bytecode ~= rhs.reg;
                return res;
            }
        case ">":
            if (!xinstrs) {
                return walk(new Form("if", form, new Value(1), new Value(0)));
            }
            if (Value valueLeft = cast(Value) form.getArg(0)) {
                Reg rhs = walk(form.getArg(1));
                Reg res = allocOut;
                bytecode ~= Opcode.less_num;
                bytecode ~= res.reg;
                bytecode ~= rhs.reg;
                vmCheckError(valueLeft.info == typeid(double), "expected number");
                bytecode ~= literal(*cast(double*) valueLeft.value);
                return res;
            } else if (Value valueRight = cast(Value) form.getArg(1)) {
                Reg lhs = walk(form.getArg(0));
                Reg res = allocOut;
                bytecode ~= Opcode.greater_num;
                bytecode ~= res.reg;
                bytecode ~= lhs.reg;
                vmCheckError(valueRight.info == typeid(double), "expected number");
                bytecode ~= literal(*cast(double*) valueRight.value);
                return res;
            } else {
                Reg lhs = walk(form.getArg(0));
                Reg rhs = walk(form.getArg(1));
                Reg res = allocOut;
                bytecode ~= Opcode.greater;
                bytecode ~= res.reg;
                bytecode ~= lhs.reg;
                bytecode ~= rhs.reg;
                return res;
            }
        case "<=":
            if (!xinstrs) {
                return walk(new Form("if", form, new Value(1), new Value(0)));
            }
            if (Value valueLeft = cast(Value) form.getArg(0)) {
                Reg rhs = walk(form.getArg(1));
                Reg res = allocOut;
                bytecode ~= Opcode.greater_than_equal_num;
                bytecode ~= res.reg;
                bytecode ~= rhs.reg;
                vmCheckError(valueLeft.info == typeid(double), "expected number");
                bytecode ~= literal(*cast(double*) valueLeft.value);
                return res;
            } else if (Value valueRight = cast(Value) form.getArg(1)) {
                Reg lhs = walk(form.getArg(0));
                Reg res = allocOut;
                bytecode ~= Opcode.less_than_equal_num;
                bytecode ~= res.reg;
                bytecode ~= lhs.reg;
                vmCheckError(valueRight.info == typeid(double), "expected number");
                bytecode ~= literal(*cast(double*) valueRight.value);
                return res;
            } else {
                Reg lhs = walk(form.getArg(0));
                Reg rhs = walk(form.getArg(1));
                Reg res = allocOut;
                bytecode ~= Opcode.less_than_equal;
                bytecode ~= res.reg;
                bytecode ~= lhs.reg;
                bytecode ~= rhs.reg;
                return res;
            }
        case ">=":
            if (!xinstrs) {
                return walk(new Form("if", form, new Value(1), new Value(0)));
            }
            if (Value valueLeft = cast(Value) form.getArg(0)) {
                Reg rhs = walk(form.getArg(1));
                Reg res = allocOut;
                bytecode ~= Opcode.less_than_equal_num;
                bytecode ~= res.reg;
                bytecode ~= rhs.reg;
                vmCheckError(valueLeft.info == typeid(double), "expected number");
                bytecode ~= literal(*cast(double*) valueLeft.value);
                return res;
            } else if (Value valueRight = cast(Value) form.getArg(1)) {
                Reg lhs = walk(form.getArg(0));
                Reg res = allocOut;
                bytecode ~= Opcode.greater_than_equal_num;
                bytecode ~= res.reg;
                bytecode ~= lhs.reg;
                vmCheckError(valueRight.info == typeid(double), "expected number");
                bytecode ~= literal(*cast(double*) valueRight.value);
                return res;
            } else {
                Reg lhs = walk(form.getArg(0));
                Reg rhs = walk(form.getArg(1));
                Reg res = allocOut;
                bytecode ~= Opcode.greater_than_equal;
                bytecode ~= res.reg;
                bytecode ~= lhs.reg;
                bytecode ~= rhs.reg;
                return res;
            }
        case "def":
            Ident id = cast(Ident) form.getArg(0);
            vmCheckError(id !is null, "interal: bad def");
            Form argsForm = cast(Form) form.getArg(1);
            vmCheckError(argsForm !is null, "function must take args");
            vmCheckError(argsForm.form == "call" || argsForm.form == "args",
                    "malformed args type (must be 'args' or 'call')");
            string[] argnames;
            foreach (arg; argsForm.args) {
                Ident argid = cast(Ident) arg;
                vmCheckError(argid !is null, "malformed arg");
                argnames ~= argid.repr;
            }
            Reg lambdaReg = allocOut;
            bytecode ~= Opcode.store_fun;
            bytecode ~= lambdaReg.reg;
            int refLength = cast(uint) bytecode.length;
            bytecode ~= jumpTmp;
            int refRegc = cast(uint) bytecode.length;
            bytecode ~= 255;
            Reg[] oldRegs = regs;
            regs = null;
            localss.length++;
            int* ptr = null;
            if (int* ptr_ = "rec" in funcs) {
                ptr = ptr_;
            }
            funcs["rec"] = cast(int) bytecode.length;
            funcs[id.repr] = cast(int) bytecode.length; 
            foreach (index, arg; argnames) {
                locals[arg] = alloc();
            }
            jumpLabelss.length++;
            jumpLocss.length++;
            inNthCaptures.length++;
            Reg retreg;
            foreach (arg; form.sliceArg(2)) {
                retreg = walk(arg);
            }
            if (retreg !is null) {
                bytecode ~= Opcode.ret;
                bytecode ~= retreg.reg;
            } else {
                Reg reg = alloc();
                bytecode ~= Opcode.store_none;
                bytecode ~= reg.reg;
                bytecode ~= Opcode.ret;
                bytecode ~= reg.reg;
            }
            bytecode[refRegc] = cast(uint)(regs.length + 1);
            regs = oldRegs;
            fixGotoLabels();
            localss.length--;
            jumpLocss.length--;
            jumpLabelss.length--;
            inNthCaptures.length--;
            bytecode ~= Opcode.fun_done;
            bytecode[refLength .. refLength + jumpSize] = jump(cast(int) bytecode.length);
            if (ptr is null) {
                funcs.remove("rec");
            } else {
                funcs["rec"] = *ptr;
            }
            return lambdaReg;
        case "lambda":
            Form argsForm = cast(Form) form.getArg(0);
            vmCheckError(argsForm !is null, "function must take args");
            vmCheckError(argsForm.form == "call" || argsForm.form == "args",
                    "malformed args type (must be 'args' or 'call')");
            string[] argnames;
            foreach (arg; argsForm.args) {
                Ident id = cast(Ident) arg;
                vmCheckError(id !is null, "malformed arg");
                argnames ~= id.repr;
            }
            Reg lambdaReg = allocOut;
            bytecode ~= Opcode.store_fun;
            bytecode ~= lambdaReg.reg;
            int refLength = cast(uint) bytecode.length;
            bytecode ~= jumpTmp;
            int refRegc = cast(uint) bytecode.length;
            bytecode ~= 255;
            Reg[] oldRegs = regs;
            regs = null;
            localss.length++;
            locals["rec"] = new Reg(0);
            foreach (index, arg; argnames) {
                locals[arg] = alloc();
            }
            jumpLabelss.length++;
            jumpLocss.length++;
            inNthCaptures.length++;
            Reg retreg;
            foreach (arg; form.sliceArg(1)) {
                retreg = walk(arg);
            }
            if (retreg !is null) {
                bytecode ~= Opcode.ret;
                bytecode ~= retreg.reg;
            } else {
                Reg reg = alloc();
                bytecode ~= Opcode.store_none;
                bytecode ~= reg.reg;
                bytecode ~= Opcode.ret;
                bytecode ~= reg.reg;
            }
            bytecode[refRegc] = cast(uint)(regs.length + 1);
            regs = oldRegs;
            fixGotoLabels();
            localss.length--;
            jumpLocss.length--;
            jumpLabelss.length--;
            inNthCaptures.length--;
            bytecode ~= Opcode.fun_done;
            bytecode[refLength .. refLength + jumpSize] = jump(cast(int) bytecode.length);
            return lambdaReg;
        case "type":
            Reg outreg = allocOut;
            Reg objreg = walk(form.getArg(0));
            bytecode ~= Opcode.type;
            bytecode ~= outreg.reg;
            bytecode ~= objreg.reg;
            return outreg;
        case "putchar":
            Reg reg = walk(form.getArg(0));
            bytecode ~= Opcode.putchar;
            bytecode ~= reg.reg;
            return null;
        case "call":
            if (Ident id = cast(Ident) form.getArg(0)) {
                if (int *freg = id.repr in funcs) {
                    Reg[] argRegs;
                    foreach (index, arg; form.sliceArg(1)) {
                        argRegs ~= walk(arg);
                    }
                    Reg outreg = allocOut;
                    switch (argRegs.length) {
                    case 0:
                        bytecode ~= Opcode.static_call0;
                        bytecode ~= outreg.reg;
                        bytecode ~= jump(*freg);
                        return outreg;
                    case 1:
                        bytecode ~= Opcode.static_call1;
                        bytecode ~= outreg.reg;
                        bytecode ~= jump(*freg);
                        bytecode ~= argRegs[0].reg;
                        return outreg;
                    case 2:
                        bytecode ~= Opcode.static_call2;
                        bytecode ~= outreg.reg;
                        bytecode ~= jump(*freg);
                        bytecode ~= argRegs[0].reg;
                        bytecode ~= argRegs[1].reg;
                        return outreg;
                    default:
                        bytecode ~= Opcode.static_call;
                        bytecode ~= outreg.reg;
                        bytecode ~= jump(*freg);
                        bytecode ~= cast(uint) argRegs.length;
                        foreach (reg; argRegs) {
                            bytecode ~= reg.reg;
                        }
                        return outreg;
                    }
                }
            }
            Reg funreg = walk(form.getArg(0));
            Reg[] argRegs;
            foreach (index, arg; form.sliceArg(1)) {
                argRegs ~= walk(arg);
            }
            Reg outreg = allocOut;
            switch (argRegs.length) {
            case 0:
                bytecode ~= Opcode.call0;
                bytecode ~= outreg.reg;
                bytecode ~= funreg.reg;
                return outreg;
            case 1:
                bytecode ~= Opcode.call1;
                bytecode ~= outreg.reg;
                bytecode ~= funreg.reg;
                bytecode ~= argRegs[0].reg;
                return outreg;
            case 2:
                bytecode ~= Opcode.call2;
                bytecode ~= outreg.reg;
                bytecode ~= funreg.reg;
                bytecode ~= argRegs[0].reg;
                bytecode ~= argRegs[1].reg;
                return outreg;
            default:
                bytecode ~= Opcode.call;
                bytecode ~= outreg.reg;
                bytecode ~= funreg.reg;
                bytecode ~= cast(uint) argRegs.length;
                foreach (reg; argRegs) {
                    bytecode ~= reg.reg;
                }
                return outreg;
            }
        case "return":
            if (Form call = cast(Form) form.getArg(0)) {
                if (call.form == "call") {
                    if (Ident id = cast(Ident) call.getArg(0)) {
                        if (int* func = id.repr in funcs) {
                            Reg[] argRegs;
                            foreach (index, arg; call.sliceArg(1)) {
                                Reg r = walk(arg);
                                argRegs ~= r;
                            }
                            // this switch has a bug in argument order
                            // i cannot figure it out, it is a fancy bug
                            switch (argRegs.length) {
                            case 0:
                                bytecode ~= Opcode.jump;
                                bytecode ~= jump(*func);
                                return null;
                            case 1:
                                if (argRegs[0].repr != 1) {
                                    bytecode ~= Opcode.store_reg;
                                    bytecode ~= new Reg(1).reg;
                                    bytecode ~= argRegs[0].reg;
                                }
                                bytecode ~= Opcode.jump;
                                bytecode ~= jump(*func);
                                return null;
                            case 2:
                                if (argRegs[1].repr == 1) {
                                    bytecode ~= Opcode.store_reg;
                                    bytecode ~= new Reg(0).reg;
                                    bytecode ~= argRegs[1].reg;
                                    argRegs[1] = new Reg(0);
                                }
                                if (argRegs[0].repr != 1) {
                                    bytecode ~= Opcode.store_reg;
                                    bytecode ~= new Reg(1).reg;
                                    bytecode ~= argRegs[0].reg;
                                }
                                if (argRegs[1].repr != 2) {
                                    bytecode ~= Opcode.store_reg;
                                    bytecode ~= new Reg(2).reg;
                                    bytecode ~= argRegs[1].reg;
                                }
                                bytecode ~= Opcode.jump;
                                bytecode ~= jump(*func);
                                return null;
                            default:
                                if (argRegs[0].repr != 1) {
                                    bytecode ~= Opcode.store_reg;
                                    bytecode ~= new Reg(1).reg;
                                    bytecode ~= argRegs[0].reg;
                                }
                                foreach (i, v; argRegs[1..$]) {
                                    Reg outreg = new Reg(i + 2);
                                    if (v.repr == outreg.repr) {
                                        continue;
                                    }
                                    bytecode ~= Opcode.store_reg;
                                    bytecode ~= outreg.reg;
                                    bytecode ~= v.reg;
                                }
                                bytecode ~= Opcode.jump;
                                bytecode ~= jump(*func);
                                return null;
                            }
                        }
                    }
                    Reg func = walk(call.getArg(0));
                    Reg[] argRegs;
                    foreach (index, arg; call.sliceArg(1)) {
                        argRegs ~= walk(arg);
                    }
                    switch (argRegs.length) {
                    case 0:
                        bytecode ~= Opcode.tail_call0;
                        bytecode ~= func.reg;
                        return null;
                    case 1:
                        bytecode ~= Opcode.tail_call1;
                        bytecode ~= func.reg;
                        bytecode ~= argRegs[0].reg;
                        return null;
                    case 2:
                        bytecode ~= Opcode.tail_call2;
                        bytecode ~= func.reg;
                        bytecode ~= argRegs[0].reg;
                        bytecode ~= argRegs[1].reg;
                        return null;
                    default:
                        bytecode ~= Opcode.tail_call;
                        bytecode ~= func.reg;
                        bytecode ~= cast(uint) argRegs.length;
                        foreach (reg; argRegs) {
                            bytecode ~= reg.reg;
                        }
                        return null;
                    }
                }
            }
            Reg res = walk(form.getArg(0));
            bytecode ~= Opcode.ret;
            bytecode ~= res.reg;
            return null;
        }

        vmError("Form: " ~ form.to!string);
        assert(false);
    }

    Reg walkExact(Ident id) {
        if (Reg* fromreg = id.repr in locals) {
            Reg outreg = allocOutMaybe;
            if (outreg is null || outreg == *fromreg) {
                return *fromreg;
            } else {
                bytecode ~= Opcode.store_reg;
                bytecode ~= outreg.reg;
                bytecode ~= (*fromreg).reg;
                return outreg;
            }
        } else {
            vmError("name resolution fail for: " ~ id.to!string);
            assert(false);
        }
    }

    Reg walkExact(Value val) {
        if (val.info == typeid(null)) {
            Reg ret = allocOut;
            bytecode ~= Opcode.store_none;
            bytecode ~= ret.reg;
            return ret;
        } else if (val.info == typeid(bool)) {
            Reg ret = allocOut;
            bytecode ~= Opcode.store_bool;
            bytecode ~= ret.reg;
            bytecode ~= cast(uint)*cast(bool*) val.value;
            return ret;
        } else if (val.info == typeid(int)) {
            Reg ret = allocOut;
            bytecode ~= Opcode.store_int;
            bytecode ~= ret.reg;
            bytecode ~= jump(cast(double)*cast(int*) val.value);
            return ret;
        } else if (val.info == typeid(double)) {
            Reg ret = allocOut;
            bytecode ~= Opcode.store_int;
            bytecode ~= ret.reg;
            bytecode ~= literal(*cast(double*) val.value);
            return ret;
        } else if (val.info == typeid(string)) {
            string src = *cast(string*) val.value;
            Reg outreg = allocOut;
            bytecode ~= Opcode.string_new;
            bytecode ~= outreg.reg;
            bytecode ~= cast(uint) src.length;
            foreach (chr; src) {
                bytecode ~= cast(uint) chr;
            }
            return outreg;
        } else {
            vmError("value type not supported yet: " ~ val.info.to!string);
            assert(false);
        }
    }
}
