module purr.ast.cons;

import std.algorithm;
import std.conv;
import std.array;
import purr.srcloc;
import purr.dynamic;
import purr.ast.ast;

Dynamic astDynamic(Location loc)
{
    Mapping ret;
    ret["line".dynamic] = loc.line.dynamic;
    ret["column".dynamic] = loc.column.dynamic;
    ret["file".dynamic] = loc.file.dynamic;
    ret["src".dynamic] = loc.src.dynamic;
    return ret.dynamic;
}

Dynamic astDynamic(Span span)
{
    Mapping ret;
    ret["start".dynamic] = span.first.astDynamic; 
    ret["last".dynamic] = span.first.astDynamic; 
    return ret.dynamic;
}

Dynamic astDynamic(Node node, bool useSpan=false)
{
    Mapping ret;
    ret["id".dynamic] = node.id.to!string.dynamic;
    if (useSpan)
    {
        ret["span".dynamic] = node.span.astDynamic; 
    }
    final switch (node.id)
    {
    case NodeKind.base:
        assert(false);
    case NodeKind.call:
        Call call = cast(Call) node;
        Dynamic[] args;
        foreach (arg; call.args)
        {
            args ~= arg.astDynamic(useSpan);
        }
        ret["args".dynamic] = args.dynamic;
        return ret.dynamic;
    case NodeKind.ident:
        Ident id = cast(Ident) node;
        ret["repr".dynamic] = id.repr.dynamic;
        return ret.dynamic;
    case NodeKind.value:
        Value val = cast(Value) node;
        ret["value".dynamic] = val.value;
        return ret.dynamic;
    }
}

Node getNode(Dynamic val)
{
    if (val.type == Dynamic.Type.str)
    {
        if (val.str[0] == '$')
        {
            return new Ident(val.str[1..$]);
        }
        else if (val.str[0] >= '0' && val.str[0] <= '9')
        {
            return new Ident(val.str);
        }
        else if (val.str[0] == '@')
        {
            return new Ident(val.str);
        }
        else if (val.str[0] == ':')
        {
            return new Value(val.str[1..$]);
        }
        else
        {
            throw new Exception("error: string[0] must match regex [$@:0-9], (string was: \"" ~ val.str ~ "\")");
        }
    }
    if (val.type == Dynamic.Type.sml)
    {
        return new Ident(val.as!double.to!string);
    }
    if (val.type == Dynamic.Type.arr)
    {
        return new Call(val.arr.map!getNode.array);
    }
    Mapping map = val.tab.table;
    NodeKind id = map["id".dynamic].str.to!NodeKind;
    final switch (id) {
    case NodeKind.base:
        assert(false);
    case NodeKind.call:
        Node[] args;
        foreach (arg; map["args".dynamic].arr)
        {
            args ~= arg.getNode;
        }
        return new Call(args);
    case NodeKind.ident:
        return new Ident(map["repr".dynamic].str);
    case NodeKind.value:
        return new Value(map["value".dynamic]);
    }
}
