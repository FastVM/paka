module purr.ast.lift;

import std.stdio: writeln;
import std.conv: to;
import std.algorithm: canFind;
import purr.ast.ast: Node, Form, Ident, Value, NodeKind;
import purr.err: vmError, vmCheckError;

string[] findVars(Node node) {
    string[] vars;
    findVars(vars, node);
    return vars;
}

void findVars(ref string[] vars, Node node) {
    final switch (node.id) {
    case NodeKind.base:
        assert(false);
    case NodeKind.call:
        return findVarsExact(vars, cast(Form) node);
    case NodeKind.ident:
        return findVarsExact(vars, cast(Ident) node);
    case NodeKind.value:
        return findVarsExact(vars, cast(Value) node);
    }
}

void findVarsExact(ref string[] vars, Form node) {
    if (node.form == "set") {
        if (Ident id = cast(Ident) node.getArg(0)) {
            findVars(vars, node.getArg(1));
            if (!vars.canFind(id.repr)) {
                vars ~= id.repr;
            }
        } else {
            findVars(vars, node.getArg(0));
        }
        findVars(vars, node.getArg(1));
    } else if (node.form == "lambda") {

    } else {
        foreach (arg; node.args) {
            findVars(vars, arg);
        }
    }
}

void findVarsExact(ref string[] vars, Ident node) {}
void findVarsExact(ref string[] vars, Value node) {}

string[] findUsages(Node node) {
    string[] vars;
    findUsages(vars, node);
    return vars;
}

void findUsages(ref string[] vars, Node node) {
    final switch (node.id) {
    case NodeKind.base:
        assert(false);
    case NodeKind.call:
        return findUsagesExact(vars, cast(Form) node);
    case NodeKind.ident:
        return findUsagesExact(vars, cast(Ident) node);
    case NodeKind.value:
        return findUsagesExact(vars, cast(Value) node);
    }
}

void findUsagesExact(ref string[] vars, Form node) {
    if (node.form == "set") {
        if (Ident id = cast(Ident) node.getArg(0)) {
            findUsages(vars, node.getArg(1));
        } else {
            findUsages(vars, node.getArg(0));
            findUsages(vars, node.getArg(1));
        }
    } else if (node.form == "lambda") {
        string[] has = findVars(node.getArg(1));
        string[] uses = findUsages(node.getArg(1));
        Form form = cast(Form) node.getArg(0);
        if (form is null) {
            vmError("internal error: lambda args");
        }
        foreach (index, arg; form.args) {
            Ident id = cast(Ident) arg;
            if (id is null) {
                vmError("internal error: lambda arg " ~ index.to!string);
            }
            if (!has.canFind(id.repr)) {
                has ~= id.repr;
            }
        }
        string[] needs;
        foreach (use; uses) {
            if (!has.canFind(use) && !vars.canFind(use)) {
                vars ~= use;
                needs ~= use;
            }
        }
    } else {
        foreach (arg; node.args) {
            findUsages(vars, arg);
        }
    }
}

void findUsagesExact(ref string[] vars, Ident node) {
    if (!vars.canFind(node.repr)) {
        vars ~= node.repr;
    }
}
void findUsagesExact(ref string[] vars, Value node) {}

class Lifter {
    Node[string] locals;
    Node[] nodes;
    size_t depth;
    string outname;

    Node liftProgram(Node node) {
        locals["this"] = new Ident("this");
        Node[] pre;
        foreach (name; findVars(node)) {
            locals[name] = new Ident(name);
            pre ~= new Form("decl", new Ident(name));
        }
        Node lifted = lift(node);
        return new Form("do", pre, lifted);
    }

    Node lift(Node node, string outname_=null) {
        string oldOutname = outname;
        scope(exit) {
            outname = oldOutname;
        }
        outname = outname_;
        nodes ~= node;
        scope (exit) {
            nodes.length--;
        }
        final switch (node.id) {
        case NodeKind.base:
            assert(false);
        case NodeKind.call:
            return liftExact(cast(Form) node);
        case NodeKind.ident:
            return liftExact(cast(Ident) node);
        case NodeKind.value:
            return liftExact(cast(Value) node);
        }
    }

    Node liftExact(Ident id) {
        if (Node* ret = id.repr in locals) {
            return cast(Node) *ret;
        }
        vmError("name resolution failure for: " ~ id.repr);
        assert(false);
    }

    Node liftExact(Value val) {
        return cast(Node) val;
    }

    Node liftExact(Form form) {
        switch (form.form) {
        case "lambda":
            depth++;
            scope(exit) {
                depth--;
            }
            Node[string] oldLocals = locals;
            locals = ["rec": new Ident("rec")];
            scope(exit) {
                locals = oldLocals;
            }
            Form argsForm = cast(Form) form.getArg(0);
            if (argsForm is null) {
                vmError("malformed ast");
            }
            string[] varNames = ["rec"];
            foreach (arg; form.sliceArg(1)) {
                findVars(varNames, arg);
            }
            string[] used;
            foreach (arg; form.sliceArg(1)) {
                findUsages(used, arg);
            }
            foreach (arg; argsForm.args) {
                if (Ident id = cast(Ident) arg) {
                    locals[id.repr] = arg;
                    varNames ~= id.repr;
                }
            }
            Node[] pre;
            string[] notFound;
            foreach (index, name; used) {
                if (!varNames.canFind(name)) {
                    notFound ~= name;
                    locals[name] = new Form("deref", new Form("index", new Ident("rec"), new Value(cast(double) notFound.length)));
                } else if (name !in locals) {
                    pre ~= new Form("decl", new Ident(name));
                    locals[name] = new Ident(name);
                } 
            }
            Node[] arrayValues;
            foreach (name; notFound) {
                if (Node* val = name in oldLocals) {
                    arrayValues ~= new Form("ref", *val);
                } else {
                    vmError("local name resolution failure: " ~ name);
                }
            }
            Node[] lambdaBody;
            foreach (arg; form.sliceArg(1)) {
                lambdaBody ~= lift(arg);
            }
            Form lambda = new Form("lambda", new Form("args", argsForm.args), pre, lambdaBody);
            if (arrayValues.length != 0) {
                lambda = new Form("array", lambda, arrayValues);
            }
            return cast(Node) lambda;
        case "set":
            if (Ident id = cast(Ident) form.getArg(0)) {
                return new Form("set", lift(form.getArg(0)), lift(form.getArg(1), id.repr));
            } else {
                return new Form("set", lift(form.getArg(0)), lift(form.getArg(1)));
            }
        default:
            Node[] args;
            foreach (arg; form.args) {
                args ~= lift(arg);
            }
            return cast(Node) new Form(form.form, args);
        }
    }
}
