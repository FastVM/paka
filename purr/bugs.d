module purr.bugs;

import purr.dynamic;
import purr.srcloc;
import purr.bytecode;

final class DebugFrame
{
    ushort index;
    Dynamic* locals;    
    Bytecode func;
    this(Bytecode f, ushort i, Dynamic* l)
    {
        func = f;
        index = i;
        locals = l;
    }

    Span span()
    {
        return func.spans[index];
    }
}