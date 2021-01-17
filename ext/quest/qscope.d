module quest.qscope;

import std.conv;
import std.stdio;
import lang.dynamic;
import quest.globals;
import quest.dynamic;

Table[] qScopes;

ref Table topScope()
{
    assert(qScopes.length != 0);
    return qScopes[$ - 1];
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
