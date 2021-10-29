module ext.zz.zrepr;

import purr.ast.ast;
import std.conv;

string tozz2(Node node, size_t ind=0) {
    if (Form form = cast(Form) node) {
        if (form.form == "call" && form.args.length > 1) {
            string ret = form.getArg(0).tozz2(ind);
            ret ~= ' ';
            size_t next = ind + ret.length;
            foreach(i, arg; form.sliceArg(1)) {
                if (i != 0) {
                    ret ~= '\n';
                    foreach (j; 0..next) {
                        ret ~= ' ';
                    }
                }
                ret ~= arg.tozz2(next);
            }
            return ret;
        } else {
            string ret = form.form;
            ret ~= ' ';
            size_t next = ind + ret.length;
            foreach(i, arg; form.args) {
                if (i != 0) {
                    ret ~= '\n';
                    foreach (j; 0..next) {
                        ret ~= ' ';
                    }
                }
                ret ~= arg.tozz2(next);
            }
            return ret;
        }
    }
    if (Value value = cast(Value) node) {
        if (value.info == typeid(string)) {
            return ": " ~ value.to!string;
        }
    }
    return node.to!string;
}

string tozz(Node node) {
    if (Form form = cast(Form) node) {
        string ret;
        if (form.form == "do") {
            foreach (i, arg; form.args) {
                if (i != 0) {
                    ret ~= '\n';
                }
                ret ~= arg.tozz2;
            }
        }
        return ret;
    } 
    return node.tozz2;
}
