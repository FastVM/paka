module purr.type.check;

import purr.ir.repr;
import purr.type.repr;

class TypeChecker
{
    Type[string][] locals;
    Type[] stack;

    void emit(T)(T instr)
    {
    }

    void enterFunc()
    {
        locals.length++;
    }

    void exitFunc()
    {
        locals.length--;
    }

    void enterBlock(string[] names)
    {
    }

    void emit(PushInstruction instr)
    {
    }
    
    void emit(ConstOperatorInstruction instr)
    {
    }
    
    void emit(ReturnBranch retb)
    {
    }
}