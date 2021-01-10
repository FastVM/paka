module lang.quest.qscope;

import std.stdio;
import std.conv;
import std.algorithm;
import lang.dynamic;
import lang.quest.globals;
import lang.quest.dynamic;

Table[] qScopes;

static this()
{
    qScopes ~= baseScope;
}

static ~this()
{
    qScopes.length--;
}

class ReturnValueFlowException : Exception
{
    Dynamic value;
    Table qscope;
    this(Dynamic v, Table q = qScopes[$ - 1])
    {
        value = v;
        qscope = q;
        super(null);
    }
}

void qScopeEnter(Table pscope, Args args = null)
{
    Mapping locals = emptyMapping;
    foreach (index, arg; args)
    {
        locals[dynamic("_" ~ index.to!string)] = arg;
    }
    qScopes ~= new Table(locals, new Table().withGet(pscope));
}

void qScopeExit()
{
    qScopes.length--;
}