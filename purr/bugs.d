module purr.bugs;

import purr.dynamic;
import purr.srcloc;
import purr.bytecode;

class DebugFrame
{
    ushort index;
    Dynamic* locals;    
    Function func;
    this(Function f, ushort i, Dynamic* l)
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