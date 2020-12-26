module lang.bc.typer;

import std.conv;
import std.stdio;
import lang.dynamic;
import lang.bytecode;
import lang.bc.iterator;
import lang.bc.types.types;

TypeBox getPushType(Dynamic value)
{
    switch (value.type)
    {
    default:
        assert(0);
    case Dynamic.Type.pro:
        assert(0);
    case Dynamic.Type.sml:
        return new Box!NumberType().generic;
    case Dynamic.Type.str:
        return new Box!StringType().generic;
    }
}

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

    bool[] tester = [false];
    TypeSignature signature;
    TypeBox[] returnTypeArray;
    TypeBox[] argumentsTypeArray;
    TypeBox[][] stackTypesArray;
    TypeBox[][] localTypesArray;
    this()
    {
    }

override:
    void enter(Function func)
    {
        if (!tester[$ - 1])
        {
            returnTypeArray ~= type!NullType;
            argumentsTypeArray ~= type!TupleType;
        }
        stackTypesArray.length++;
        localTypesArray.length++;
    }

    void exit(Function func)
    {
        TypeSignature sig1 = TypeSignature(returnType.deepcopy, argumentsType.deepcopy);
        if (!tester[$ - 1])
        {
            while (true) {
                tester ~= true;
                walk(func);
                tester.length--;
                if (sig1 == signature) {
                    break;
                }
                sig1 = signature;
            }
            TypeBox functy = type!FunctionType(returnType, argumentsType);
            writeln(functy);
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
    }

    void got(Opcode op)
    {
        // writeln(stackTypes, " & ", op, " -> ");    
    }

    void nop()
    {
    }

    void push(ushort constIndex)
    {
        stackTypes ~= func.constants[constIndex].getPushType;
    }

    void pop()
    {
        stackTypes.length--;
    }

    void sub(ushort funcIndex)
    {
        assert(0);
    }

    void call(ushort argCount)
    {
        assert(0);
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
        if (lhs.type == typeid(NullType) && rhs.type == typeid(NullType))
        {
            TypeBox ut = type!NullType;
            ut.given(type!NumberType);
            ut.given(type!StringType);
            lhs.given(ut);
            rhs.given(ut);
            return;
        }
        if (lhs.type == typeid(NullType))
        {
            lhs.given(rhs);
        }
        else if (rhs.type == typeid(NullType))
        {
            rhs.given(lhs);
        }
        bool okay = false;
        TypeBox res = type!NullType;
        // writeln(lhs, " + ", lhs, " -> ", res);
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
        lhs.set(res);
        rhs.set(res);
        // writeln(lhs, " + ", lhs, " -> ", res);
        // writeln;
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
        assert(0);
    }

    void loadc(ushort captureIndex)
    {
        assert(0);
    }

    void store(ushort localIndex)
    {
        assert(0);
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
            tt.elementTypes ~= type!NullType;
        }
        stackTypes ~= tt.elementTypes[argIndex];
    }

    void args()
    {
        assert(0);
    }
}
