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
    TypeBox[][Function] knownCaptureTypes;
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
                    tt.elementTypes ~= type!AnyType;
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
            returnTypeArray ~= type!AnyType;
            argumentsTypeArray ~= type!TupleType;
        }
        stackTypesArray.length++;
        localTypesArray.length++;
        foreach (lt; 0 .. func.stab.length)
        {
            localTypes ~= type!AnyType;
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
                returnType.set(type!AnyType);
                walk(func);
                tester.length--;
                if (sig1 == signature)
                {
                    break;
                }
                sig1 = signature;
            }
            returnType.cleanUnionFlatten;
            foreach (ty; argumentsType.as!TupleType.elementTypes)
            {
                ty.cleanUnionFlatten;
            }
            TypeBox functy = type!FunctionType(returnType, argumentsType);
            knownTypes[func] = functy;
        }
        else
        {
            signature = sig1;
        }
        if (!tester[$ - 1])
        {
            returnTypeArray.length--;
            argumentsTypeArray.length--;
        }
        if (tester.length == 1)
        {
            foreach (k, v; knownTypes)
            {
                if (k == func)
                {
                    writeln("return: ", v.as!FunctionType.returnType.flat);
                    foreach (argno, argty; v.as!FunctionType
                            .argumentsType
                            .as!TupleType
                            .elementTypes)
                    {
                        writeln("arg ", argno, ": ", argty.flat);
                    }
                }
            }
            foreach (tyi, ty; localTypes)
            {
                writeln("local ", func.stab[tyi], ": ", ty.flat);
            }
        }
        stackTypesArray.length--;
        localTypesArray.length--;
        aboveStack.length--;
    }

    void got(Opcode op)
    {
        // writeln;
        // writeln("stack: ", stackTypes);
        // writeln("local: ", localTypes);
        // writeln(op);
        // writeln(func.captab.byPlace, ":", func.stab.byPlace, " ", op);
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
            if (mytype.type != typeid(FunctionType))
            {
                mytype.given(FunctionType.any);
            }
            returnTypeArray ~= mytype.as!FunctionType.returnType;
            argumentsTypeArray ~= mytype.as!FunctionType.argumentsType;
            tester ~= true;
            captureTypesArray ~= knownCaptureTypes[subFunc];
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
            knownCaptureTypes[subFunc] = captureTypesArray[$ - 1];
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
        if (subfunc.type == typeid(FunctionType))
        {
            TypeBox[] funcArgTypes = subfunc.as!FunctionType
                .argumentsType
                .as!TupleType
                .elementTypes;
            foreach (index, value; last)
            {
                while (index >= funcArgTypes.length)
                {
                    funcArgTypes ~= type!AnyType;
                }
                // writeln("idx: ", funcArgTypes[index]);
                // funcArgTypes[index].unite(value);
                // writeln("value: ", value);
                // writeln("idx: ", funcArgTypes[index]);
                // writeln;
                funcArgTypes[index].given(value);
                value.given(funcArgTypes[index]);
            }
        }
        else
        {
            subfunc.set(type!FunctionType(type!AnyType, type!TupleType(last)));
        }
        stackTypes[$ - 1] = subfunc.as!FunctionType.returnType;
    }

    void upcall()
    {
        assert(0);
    }

    void opgt()
    {
        stackTypes ~= type!LogicalType;
    }

    void oplt()
    {
        stackTypes ~= type!LogicalType;
    }

    void opgte()
    {
        stackTypes ~= type!LogicalType;
    }

    void oplte()
    {
        stackTypes ~= type!LogicalType;
    }

    void opeq()
    {
        stackTypes ~= type!LogicalType;
    }

    void opneq()
    {
        stackTypes ~= type!LogicalType;
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
    }

    void opadd()
    {
        TypeBox rhs = stackTypes[$ - 1];
        stackTypes.length--;
        TypeBox lhs = stackTypes[$ - 1];

        if (lhs.type == typeid(UnionType) && rhs.type == typeid(UnionType))
        {
            TypeBox ut = type!UnionType;
            ut.given(type!NumberType);
            ut.given(type!StringType);
            lhs.given(ut);
            rhs.given(ut);
            return;
        }
        if (lhs.type == typeid(UnionType))
        {
            lhs.given(rhs);
        }
        else if (rhs.type == typeid(UnionType))
        {
            rhs.given(lhs);
        }
        bool okay = false;
        TypeBox res = type!UnionType;
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
        lhs.tie(res);
        rhs.tie(res);
        stackTypes[$ - 1] = res;
    }

    void opsub()
    {
        TypeBox rhs = stackTypes[$ - 1];
        stackTypes.length--;
        TypeBox lhs = stackTypes[$ - 1];

        if (lhs.type == typeid(UnionType) && rhs.type == typeid(UnionType))
        {
            TypeBox ut = type!UnionType;
            ut.given(type!NumberType);
            lhs.given(ut);
            rhs.given(ut);
            return;
        }
        if (lhs.type == typeid(UnionType))
        {
            lhs.given(rhs);
        }
        else if (rhs.type == typeid(UnionType))
        {
            rhs.given(lhs);
        }
        bool okay = false;
        TypeBox res = type!UnionType;
        if (lhs.same(type!NumberType) && rhs.same(type!NumberType))
        {
            res.given(type!NumberType);
        }
        else if (!okay)
        {
            throw new Exception(
                    "type error: cannot perform: { " ~ lhs.to!string ~ " - " ~ rhs.to!string ~ " }");
        }
        lhs.tie(res);
        rhs.tie(res);
        stackTypes[$ - 1] = res;
    }

    void opmul()
    {
        TypeBox rhs = stackTypes[$ - 1];
        stackTypes.length--;
        TypeBox lhs = stackTypes[$ - 1];

        if (lhs.type == typeid(UnionType) && rhs.type == typeid(UnionType))
        {
            TypeBox ut = type!UnionType;
            ut.given(type!NumberType);
            ut.given(type!StringType);
            lhs.given(ut);
            rhs.given(type!NumberType);
            return;
        }
        if (lhs.type == typeid(UnionType))
        {
            lhs.given(type!UnionType([type!NumberType, type!StringType]));
        }
        else if (rhs.type == typeid(UnionType))
        {
            rhs.given(type!NumberType);
        }
        TypeBox res = type!UnionType;
        TypeBox[] given;
        if (lhs.same(type!NumberType) && rhs.same(type!NumberType))
        {
            given ~= type!NumberType;
        }
        if (lhs.same(type!StringType) && rhs.same(type!NumberType))
        {
            given ~= type!StringType;
        }
        foreach (give; given)
        {
            res.given(give);
            lhs.set(res);
            // lhs.given(give);
        }
        rhs.set(type!NumberType);
        if (given.length == 0)
        {
            throw new Exception(
                    "type error: cannot perform: { " ~ lhs.to!string ~ " * " ~ rhs.to!string ~ " }");
        }
        stackTypes[$ - 1] = res;
    }

    void opdiv()
    {
        TypeBox rhs = stackTypes[$ - 1];
        stackTypes.length--;
        TypeBox lhs = stackTypes[$ - 1];

        if (lhs.type == typeid(UnionType) && rhs.type == typeid(UnionType))
        {
            TypeBox ut = type!UnionType;
            ut.given(type!NumberType);
            lhs.given(ut);
            rhs.given(ut);
            return;
        }
        if (lhs.type == typeid(UnionType))
        {
            lhs.given(rhs);
        }
        else if (rhs.type == typeid(UnionType))
        {
            rhs.given(lhs);
        }
        bool okay = false;
        TypeBox res = type!UnionType;
        if (lhs.same(type!NumberType) && rhs.same(type!NumberType))
        {
            res.given(type!NumberType);
        }
        else if (!okay)
        {
            throw new Exception(
                    "type error: cannot perform: { " ~ lhs.to!string ~ " / " ~ rhs.to!string ~ " }");
        }
        lhs.tie(res);
        rhs.tie(res);
        stackTypes[$ - 1] = res;
    }

    void opmod()
    {
        TypeBox rhs = stackTypes[$ - 1];
        stackTypes.length--;
        TypeBox lhs = stackTypes[$ - 1];

        if (lhs.type == typeid(UnionType) && rhs.type == typeid(UnionType))
        {
            TypeBox ut = type!UnionType;
            ut.given(type!NumberType);
            lhs.given(ut);
            rhs.given(ut);
            return;
        }
        if (lhs.type == typeid(UnionType))
        {
            lhs.given(rhs);
        }
        else if (rhs.type == typeid(UnionType))
        {
            rhs.given(lhs);
        }
        bool okay = false;
        TypeBox res = type!UnionType;
        if (lhs.same(type!NumberType) && rhs.same(type!NumberType))
        {
            res.given(type!NumberType);
        }
        else if (!okay)
        {
            throw new Exception(
                    "type error: cannot perform: { " ~ lhs.to!string ~ " % " ~ rhs.to!string ~ " }");
        }
        lhs.tie(res);
        rhs.tie(res);
        stackTypes[$ - 1] = res;
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
        localTypes[localIndex].given(stackTypes[$ - 1]);
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
            tt.elementTypes ~= type!AnyType;
        }
        stackTypes ~= tt.elementTypes[argIndex];
    }

    void args()
    {
        assert(0);
    }
}
