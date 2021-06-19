module purr.inter;

import std.typecons;
import std.traits;
import std.array;
import purr.io;
import std.functional;
import std.conv;
import std.algorithm;
import std.meta;
import purr.ast.ast;
import purr.parse;
import purr.inter;
import purr.srcloc;
import purr.ir.repr;
import purr.ir.walk;
import purr.type.repr;

__gshared bool dumpir = false;

Type[] done;
string json(Type unk)
{
    foreach (index, val; done)
    {
        if (unk is val)
        {
            return `{"type": "rec", "to": ` ~ index.to!string ~ `}`;
        }
    }
    done ~= unk;
    scope (exit)
    {
        done.length--;
    }
    if (unk.isUnk) {
        return `{"type": "unknown"}`;
    }
    Known ty = unk.as!Known;
    if (ty.as!Never)
    {
        return `{"type": "never"}`;
    }
    if (ty.as!Nil)
    {
        return `{"type": "nil"}`;
    }
    if (ty.as!Logical)
    {
        return `{"type": "logical"}`;
    }
    if (ty.as!Integer)
    {
        return `{"type": "int"}`;
    }
    if (ty.as!Float)
    {
        return `{"type": "float"}`;
    }
    if (ty.as!Text)
    {
        return `{"type": "text"}`;
    }
    if (Higher h = ty.as!Higher)
    {
        return `{"type": "higher", "of": ` ~ h.type.json ~ `}`;
    }
    if (Func f = ty.as!Func)
    {
        string args = f.args.map!json.join(`,`);
        if (f.impl !is null)
        {
            return `{"type": "lambda", "return": ` ~ f.json ~ `, "args": [`
                ~ args ~ `], "impl": "` ~ f.impl ~ `"}`;
        }
        else
        {
            return `{"type": "function", "return": ` ~ f.json ~ `, "args": [` ~ args ~ `]}`;
        }
    }
    if (Join j = ty.as!Join)
    {
        return `{"type": "tuple", "elems": [` ~ j.elems.map!json.join(`,`) ~ `]}`;
    }
    if (Generic g = ty.as!Generic)
    {
        string rets = g.rets.map!json.join(`,`);
        string cases = g.cases.map!(x => `[` ~ x.map!json.join(`,`) ~ `]`).join(`,`);
        return `{"type": "generic", "rets": [` ~ rets ~ `], "cases": [` ~ cases ~ `]}`;
    }
    assert(false);
}

string dumpedit;

string eval(SrcLoc code)
{
    Node node = code.parse;
    Walker walker = new Walker;
    string prog = walker.walkProgram(node);
    string json = `{`;
    json ~= `"pairs": [`;
    bool first = true;
    foreach (span, type; walker.editInfo)
    {
        if (!first)
        {
            json ~= `, `;
        }
        else
        {
            first = false;
        }
        json ~= `{"span": ` ~ span.json ~ `, "type": ` ~ type.json ~ `}`;
    }
    json ~= `],`;
    json ~= `"holes": {`;
    first = true;
    foreach (name, type; walker.holes) {
        if (!first)
        {
            json ~= `, `;
        }
        else
        {
            first = false;
        }
        json ~= `"` ~ name ~ `": ` ~ type.json;
    }
    json ~= `}`;
    json ~= `}`;
    if (dumpedit == null) {
        File("bin/editor.json", "w").write(json);
    }
    return prog;
}
