module quest.walk;

import std.stdio;
import purr.ast;

Node delegate(Node[])[string] questTransforms()
{
    Node delegate(Node[])[string] questTransforms;
    Node questString(string name)
    {
        return new Call(new Ident("@quest.string"), [new String(name)]);
    }

    questTransforms["@quest.env"] = (Node[] args) {
        return new Call(new Ident("_quest_load_current"), null);
    };

    questTransforms["@quest.load"] = (Node[] args) {
        Node env = new Call(new Ident("@quest.env"), null);
        Node name = questString((cast(Ident) args[0]).repr);
        return new Call(new Ident("@quest.dot"), [env, name]);
    };

    questTransforms["@quest.null"] = (Node[] args) {
        return new Call(new Ident("_quest_null"), args);
    };

    questTransforms["@quest.colon"] = (Node[] args) {
        return new Call(new Ident("_quest_colon"), args);
    };

    questTransforms["@quest.string"] = (Node[] args) {
        return new Call(new Ident("_quest_cons_value"), args);
    };

    questTransforms["@quest.number"] = (Node[] args) {
        return new Call(new Ident("_quest_cons_value"), args);
    };

    questTransforms["@quest.array"] = (Node[] args) {
        return new Call(new Ident("_quest_cons_value"), [new Call(new Ident("@array"), args)]);
    };

    questTransforms["@quest.dot"] = (Node[] args) {
        return new Call(new Ident("_quest_index"), args);
    };

    questTransforms["@quest.colons"] = (Node[] args) {
        return new Call(new Ident("_quest_index"), args);
    };

    questTransforms["@quest.cmp"] = (Node[] args) {
        return new Call(new Ident("_quest_index_call"), [
                questString("<=>"), args[0], args[1]
                ]);
    };

    questTransforms["@quest.lt"] = (Node[] args) {
        return new Call(new Ident("_quest_index_call"), [
                questString("<"), args[0], args[1]
                ]);
    };

    questTransforms["@quest.gt"] = (Node[] args) {
        return new Call(new Ident("_quest_index_call"), [
                questString(">"), args[0], args[1]
                ]);
    };

    questTransforms["@quest.lte"] = (Node[] args) {
        return new Call(new Ident("_quest_index_call"), [
                questString("<="), args[0], args[1]
                ]);
    };

    questTransforms["@quest.gte"] = (Node[] args) {
        return new Call(new Ident("_quest_index_call"), [
                questString(">="), args[0], args[1]
                ]);
    };

    questTransforms["@quest.eq"] = (Node[] args) {
        return new Call(new Ident("_quest_index_call"), [
                questString("=="), args[0], args[1]
                ]);
    };

    questTransforms["@quest.neq"] = (Node[] args) {
        return new Call(new Ident("_quest_index_call"), [
                questString("!="), args[0], args[1]
                ]);
    };

    questTransforms["@quest.add"] = (Node[] args) {
        return new Call(new Ident("_quest_index_call"), [
                questString("+"), args[0], args[1]
                ]);
    };

    questTransforms["@quest.sub"] = (Node[] args) {
        return new Call(new Ident("_quest_index_call"), [
                questString("-"), args[0], args[1]
                ]);
    };

    questTransforms["@quest.mul"] = (Node[] args) {
        return new Call(new Ident("_quest_index_call"), [
                questString("*"), args[0], args[1]
                ]);
    };

    questTransforms["@quest.div"] = (Node[] args) {
        return new Call(new Ident("_quest_index_call"), [
                questString("/"), args[0], args[1]
                ]);
    };

    questTransforms["@quest.mod"] = (Node[] args) {
        return new Call(new Ident("_quest_index_call"), [
                questString("%"), args[0], args[1]
                ]);
    };

    questTransforms["@quest.set.add"] = (Node[] args) {
        return new Call(new Ident("_quest_index_call"), [
                questString("+="), args[0], args[1]
                ]);
    };

    questTransforms["@quest.set.sub"] = (Node[] args) {
        return new Call(new Ident("_quest_index_call"), [
                questString("-="), args[0], args[1]
                ]);
    };

    questTransforms["@quest.set.mul"] = (Node[] args) {
        return new Call(new Ident("_quest_index_call"), [
                questString("*="), args[0], args[1]
                ]);
    };

    questTransforms["@quest.set.div"] = (Node[] args) {
        return new Call(new Ident("_quest_index_call"), [
                questString("/="), args[0], args[1]
                ]);
    };

    questTransforms["@quest.set.mod"] = (Node[] args) {
        return new Call(new Ident("_quest_index_call"), [
                questString("%="), args[0], args[1]
                ]);
    };

    questTransforms["@quest.call"] = (Node[] args) {
        if (Call func = cast(Call) args[0])
        {
            if (Ident id = cast(Ident) func.args[0])
            {
                if (id.repr == "@quest.dot")
                {
                    return new Call(new Ident("_quest_index_call"),
                            [func.args[2], func.args[1]] ~ args[1 .. $]);
                }
            }
        }
        return new Call(new Ident("_quest_index_call"), questString("()") ~ args);
    };

    questTransforms["@quest.enter"] = (Node[] args) {
        return new Call(new Ident("_quest_enter"), args);
    };

    questTransforms["@quest.exit"] = (Node[] args) {
        return new Call(new Ident("@return"), [
                new Call(new Ident("_quest_exit"), args)
                ]);
    };

    questTransforms["@quest.block"] = (Node[] args) {
        Node[] block;
        block ~= new Call(null);
        block ~= args;
        Node ret = new Call(new Ident("@fun"), block);
        return new Call(new Ident("_quest_cons_value"), [ret]);
    };

    questTransforms["@quest.base"] = (Node[] args) {
        return new Call(new Ident("_quest_base_scope"), null);
    };

    questTransforms["@quest.program"] = (Node[] args) {
        Node[] block;
        block ~= new Call(new Ident("@quest.enter"), [new Call(new Ident("@quest.base"), null)]);
        block ~= new Call(new Ident("@quest.exit"), args);
        return new Call(new Ident("@do"), block);
    };

    questTransforms["@quest.set.to"] = (Node[] args) {
        if (Call target = cast(Call) args[0])
        {
            if (Ident id = cast(Ident) target.args[0])
            {
                if (id.repr == "@quest.load")
                {
                    Node obj = questString((cast(Ident) target.args[1]).repr);
                    return new Call(new Ident("_quest_index_call"), [
                            questString("="),
                            obj, args[1]
                            ]);
                }
                if (id.repr == "@quest.dot")
                {
                    return new Call(new Ident("_quest_index_call"),
                            questString(".=") ~ target.args[1 .. $] ~ args[1]);
                }
                return new Call(new Ident("_quest_index_call"), [
                        questString("="), target, args[1]
                        ]);
            }
        }
        assert(false);
    };

    return questTransforms;
}
