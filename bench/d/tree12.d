module bench.d.tree12;

import std.stdio;

struct Tree {
    Tree* lhs;
    Tree* rhs;
    int value;
}

Tree *bottomUpTree(int item, int depth) {
    if (depth > 0)
    {
        int i = item + item;
        depth --;
        Tree* left = bottomUpTree(i - 1, depth);
        Tree* right = bottomUpTree(i, depth);
        return new Tree(left, right, item);
    } else {
        return new Tree(null, null, item);
    }
}

int itemCheck(Tree* tree) {
    if (tree.lhs is null) {
        return tree.value;
    } else {
        return tree.value + itemCheck(tree.lhs) - itemCheck(tree.rhs);
    }
}

void main()
{
    int n = 12;
    int mindepth = 4;
    int maxdepth = mindepth + 2;
    if (maxdepth < n)
    {
        maxdepth = n;
    }

    {
        int depth = maxdepth + 1;
        Tree* stretchTree = bottomUpTree(0, depth);
        writeln(itemCheck(stretchTree));
    }

    Tree* longLivedTree = bottomUpTree(0, maxdepth);

    for (int depth = mindepth; depth < maxdepth; depth += 2)
    {
        int iterations = 1 << (maxdepth - depth + mindepth);
        int check = 0;
        for (int i = 0; i < iterations; i++)
        {
            {
                Tree* tree1 = bottomUpTree(1, depth);
                check += itemCheck(tree1);
            }
            {
                Tree* tree2 = bottomUpTree(-1, depth);
                check += itemCheck(tree2);
            }    
        }
        writeln(check);
    }

    writeln(itemCheck(longLivedTree));
}