module lang.bc.typer;

import std.conv;
import std.stdio;
import std.algorithm;
import std.array;
import lang.dynamic;
import lang.bytecode;
import lang.bc.iterator;
import lang.bc.types.types;

struct TypeSignature
{
    TypeBox returnType;
    TypeBox argumentsType;
}

class TypeGenerator : OpcodeIterator
{
    ref TypeBox returnType()
    {
        return returnTypeArray[$ - 1];
    }

    ref TypeBox argumentsType()
    {
        return argumentsTypeArray[$ - 1];
    }

    ref TypeBox[] stackTypes()
    {
        return stackTypesArray[$ - 1];
    }

    ref TypeBox[] localTypes()
    {
        return localTypesArray[$ - 1];
    }

    ref TypeBox[] captureTypes()
    {
        return captureTypesArray[$ - 1];
    }

    bool[] tester = [false];
    TypeBox[Function] knownTypes;
    TypeSignature signature;
    TypeBox[] returnTypeArray;
    TypeBox[] argumentsTypeArray;
    TypeBox[][] stackTypesArray;
    TypeBox[][] localTypesArray;
    TypeBox[][] captureTypesArray;
    Function[] aboveStack;
    this()
    {
    }

    TypeBox getPushType(Dynamic value)
    {
        switch (value.type)
        {
        default:
            assert(0);
        case Dynamic.Type.nil:
            return type!NilType;
        case Dynamic.Type.sml:
            return type!NumberType;
        case Dynamic.Type.str:
            return type!StringType;
        }
    }

    TypeBox[] buildCapture(Function subFunc)
    {
        foreach (cap; subFunc.capture)
        {
            if (cap.is2)
            {
                captureTypes ~= captureTypesArray[$ - 2][cap.from];
            }
            else if (cap.isArg)
            {
                TupleType tt = argumentsType.as!TupleType;
                while (cap.from >= tt.elementTypes.length)
                {
                    tt.elementTypes ~= type!VoidType;
                }
                captureTypes ~= argumentsType.as!TupleType.elementTypes[cap.from];
            }
            else
            {
                captureTypes ~= localTypes[cap.from];
            }
        }
        return captureTypes;
    }

override:
    void enter(Function func)
    {
        aboveStack ~= func;
        if (!tester[$ - 1])
        {
            returnTypeArray ~= type!VoidType;
            argumentsTypeArray ~= type!TupleType;

        }
        stackTypesArray.length++;
        localTypesArray.length++;
        foreach (lt; 0 .. func.stab.length)
        {
            localTypes ~= type!VoidType;
        }
    }

    void exit(Function func)
    {
        TypeSignature sig1 = TypeSignature(returnType.deepcopy, argumentsType.deepcopy);
        if (!tester[$ - 1])
        {
            while (true)
            {
                tester ~= true;
                walk(func);
                tester.length--;
                if (sig1 == signature)
                {
                    break;
                }
                sig1 = signature;
            }
            TypeBox functy = type!FunctionType(returnType, argumentsType);
            knownTypes[func] = functy;
        }
        else
        {
            signature = sig1;
        }
        // sigs ~= sig;
        if (!tester[$ - 1])
        {
            returnTypeArray.length--;
            argumentsTypeArray.length--;
        }
        stackTypesArray.length--;
        localTypesArray.length--;
        if (tester.length == 1)
        {
            foreach (k, v; knownTypes)
            {
                if (k == func)
                {
                    write("final: ");
                }
                writeln(v);
            }
        }
        aboveStack.length--;
    }

    void got(Opcode op)
    {
        // writeln;
        // writeln("stack: ", stackTypes);
        // writeln("local: ", localTypes);
        writeln(func.captab.byPlace, ":", func.stab.byPlace, " ", op);
    }

    void nop()
    {
    }

    void push(ushort constIndex)
    {
        stackTypes ~= getPushType(func.constants[constIndex]);
    }

    void pop()
    {
        stackTypes.length--;
    }

    int x = 0;

    void sub(ushort funcIndex)
    {
        Function subFunc = func.funcs[funcIndex];
        TypeBox* ptype = subFunc in knownTypes;
        if (ptype !is null)
        {
            TypeBox mytype = *ptype;
            writeln(cast(void*) subFunc, ": ", *ptype);
            returnTypeArray ~= mytype.as!FunctionType.returnType;
            argumentsTypeArray ~= mytype.as!FunctionType.argumentsType;
            tester ~= true;
            writeln(mytype.as!FunctionType.capture);
            captureTypesArray ~= mytype.as!FunctionType.capture;
            walk(subFunc);
            tester.length--;
            captureTypesArray.length--;
            argumentsTypeArray.length--;
            returnTypeArray.length--;
        }
        else
        {
            captureTypesArray.length++;
            captureTypesArray[$ - 1] = null;
            TypeBox[] cap = buildCapture(subFunc);
            tester ~= false;
            walk(subFunc);
            knownTypes[subFunc].as!FunctionType.generatedFrom ~= subFunc;
            knownTypes[subFunc].as!FunctionType.capture = cap;
            captureTypesArray.length--;
            tester.length--;
        }
        stackTypes ~= knownTypes[subFunc];
    }

    void call(ushort argCount)
    {
        TypeBox[] last = stackTypes[$ - argCount .. $];
        stackTypes.length -= argCount;
        TypeBox subfunc = stackTypes[$ - 1];
        TypeBox[] funcArgTypes = subfunc.as!FunctionType
            .argumentsType
            .as!TupleType
            .elementTypes;
        foreach (index, value; last)
        {
            while (index >= funcArgTypes.length)
            {
                funcArgTypes ~= type!VoidType;
            }
            // writeln("idx: ", funcArgTypes[index]);
            // funcArgTypes[index].unite(value);
            // writeln("value: ", value);
            // writeln("idx: ", funcArgTypes[index]);
            // writeln;
            funcArgTypes[index].given(value);
        }
        // subfunc.as!FunctionType
        //     .argumentsType
        //     .as!TupleType
        //     .elementTypes = funcArgTypes;
        stackTypes[$ - 1] = subfunc.as!FunctionType.returnType;
        subfunc.as!FunctionType.returnType.set(stackTypes[$ - 1]);
        Function[] generatedFrom = subfunc.as!FunctionType.generatedFrom;
        assert(generatedFrom.length == 1);
        Function regenerate = generatedFrom[0];
        if (!aboveStack.canFind(regenerate))
        {
            TypeBox sig1 = subfunc.deepcopy;
            while (true)
            {
                returnTypeArray ~= subfunc.as!FunctionType.returnType;
                argumentsTypeArray ~= subfunc.as!FunctionType.argumentsType;
                captureTypesArray ~= subfunc.as!FunctionType.capture;
                tester ~= true;
                walk(regenerate);
                tester.length--;
                returnTypeArray.length--;
                argumentsTypeArray.length--;
                captureTypesArray.length--;
                if (sig1 == subfunc)
                {
                    break;
                }
                sig1 = subfunc.deepcopy;
            }
            knownTypes[regenerate] = sig1;
        }
    }

    void upcall()
    {
        assert(0);
    }

    void opgt()
    {
        assert(0);
    }

    void oplt()
    {
        assert(0);
    }

    void opgte()
    {
        assert(0);
    }

    void oplte()
    {
        assert(0);
    }

    void opeq()
    {
        assert(0);
    }

    void opneq()
    {
        assert(0);
    }

    void array()
    {
        assert(0);
    }

    void unpack()
    {
        assert(0);
    }

    void table()
    {
        assert(0);
    }

    void index()
    {
        assert(0);
    }

    void opneg()
    {
        assert(0);
    }

    void opadd()
    {
        TypeBox rhs = stackTypes[$ - 1];
        stackTypes.length--;
        TypeBox lhs = stackTypes[$ - 1];
        if (lhs.type == typeid(VoidType) && rhs.type == typeid(VoidType))
        {
            TypeBox ut = type!VoidType;
            ut.given(type!NumberType);
            ut.given(type!StringType);
            lhs.given(ut);
            rhs.given(ut);
            return;
        }
        if (lhs.type == typeid(VoidType))
        {
            lhs.given(rhs);
        }
        else if (rhs.type == typeid(VoidType))
        {
            rhs.given(lhs);
        }
        bool okay = false;
        TypeBox res = type!VoidType;
        if (lhs.same(type!NumberType) && rhs.same(type!NumberType))
        {
            res.given(type!NumberType);
            okay = true;
        }
        if (lhs.same(type!StringType) && rhs.same(type!StringType))
        {
            res.given(type!StringType);
            okay = true;
        }
        if (!okay)
        {
            throw new Exception(
                    "type error: cannot perform: { " ~ lhs.to!string ~ " + " ~ rhs.to!string ~ " }");
        }
        res.children ~= [lhs, rhs];
        // lhs.set(res);
        // rhs.set(res);
        lhs.tie(res);
        rhs.tie(res);
        stackTypes[$ - 1] = res;
    }

    void opsub()
    {
        assert(0);
    }

    void opmul()
    {
        assert(0);
    }

    void opdiv()
    {
        assert(0);
    }

    void opmod()
    {
        assert(0);
    }

    void load(ushort localIndex)
    {
        stackTypes ~= localTypes[localIndex];
    }

    void loadc(ushort captureIndex)
    {
        stackTypes ~= captureTypes[captureIndex];
    }

    void store(ushort localIndex)
    {
        localTypes[localIndex].tie(stackTypes[$ - 1]);
    }

    void istore()
    {
        assert(0);
    }

    void opstore(ushort localIndex, ushort operation)
    {
        assert(0);
    }

    void opistore(ushort operation)
    {
        assert(0);
    }

    void retval()
    {
        returnType.given(stackTypes[$ - 1]);
        stackTypes[$ - 1].tie(returnType);
        stackTypes.length--;
    }

    void retnone()
    {
        returnType.given(type!NilType);
    }

    void iftrue(ushort jumpIndex)
    {
        assert(0);
    }

    void iffalse(ushort jumpIndex)
    {
        assert(0);
    }

    void jump(ushort jumpIndex)
    {
        assert(0);
    }

    void argno(ushort argIndex)
    {
        TupleType tt = argumentsType.as!TupleType;
        while (argIndex >= tt.elementTypes.length)
        {
            tt.elementTypes ~= type!VoidType;
        }
        stackTypes ~= tt.elementTypes[argIndex];
    }

    void args()
    {
        assert(0);
    }
}
