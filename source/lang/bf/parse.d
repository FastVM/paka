module lang.bf.parse;

import std.stdio;
import lang.srcloc;
import lang.walk;
import lang.ast;
import lang.dext.parse;

Node parse(string code)
{
    string dext = "";
    dext ~= "intsize = 256;\n";
    dext ~= "tapesize = 15000;\n";
    dext ~= "data = arr.map(arr.range(tapesize * 2)) { return 0; };\n";
    dext ~= "ptr = tapesize;\n";
    size_t ind = 0;
    outter: foreach (i; code)
    {
        // dext ~= "io.print(ptr, \": \", data[ptr]);";
        if (i == ']')
        {
            ind--;
        }
        foreach (j; 0 .. ind)
        {
            dext ~= "  ";
        }
        switch (i)
        {
        case '+':
            dext ~= "data[ptr] = (data[ptr] + 1 + intsize) % intsize;\n";
            break;
        case '-':
            dext ~= "data[ptr] = (data[ptr] - 1 + intsize) % intsize;\n";
            break;
        case '<':
            dext ~= "ptr -= 1;\n";
            break;
        case '>':
            dext ~= "ptr += 1;\n";
            break;
        case '[':
            ind++;
            dext ~= "while (data[ptr] != 0) {\n";
            break;
        case ']':
            dext ~= "};\n";
            break;
        case '#':
            dext ~= "io.print(data[ptr]);";
            break;
        case '.':
            dext ~= "io.put(str.char(data[ptr]));\n";
            break;
        case ',':
            dext ~= "data[ptr] = str.ascii(io.getchar());\n";
            break;
        default:
            continue outter;
        }
    }
    return lang.dext.parse.parse(dext);
}