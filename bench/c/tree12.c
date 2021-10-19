#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>

struct tree_s;
struct leaf_s;
typedef struct tree_s tree_s;
typedef struct leaf_s leaf_s;
typedef tree_s *tree_t;

struct leaf_s
{
    bool is_leaf;
    int num;
};

struct tree_s
{
    bool is_leaf;
    int num;
    tree_t lhs;
    tree_t rhs;
};

tree_t new_tree(tree_s value)
{
    tree_t ret = malloc(sizeof(tree_s));
    *ret = value;
    return ret;
}

tree_t new_leaf(int num)
{
    tree_t ret = malloc(sizeof(leaf_s));
    ret->is_leaf = true;
    ret->num = num;
    return ret;
}

tree_t bottom_up_tree(int item, int depth)
{
    if (depth > 0)
    {
        int i = item + item;
        depth -= 1;
        tree_t left = bottom_up_tree(i - 1, depth);
        tree_t right = bottom_up_tree(i, depth);
        return new_tree((tree_s){
            .is_leaf = false,
            .num = item,
            .lhs = left,
            .rhs = right,
        });
    }
    else
    {
        return new_leaf(item);
    }
}

int item_check(tree_t tree)
{
    if (tree->is_leaf)
    {
        return tree->num;
    }
    else
    {
        return tree->num + item_check(tree->lhs) - item_check(tree->rhs);
    }
}

void free_tree(tree_t tree)
{
    if (tree->is_leaf)
    {
        free(tree);
    }
    else
    {
        free_tree(tree->lhs);
        free_tree(tree->rhs);
        free(tree);
    }
}

int main()
{
    int n = 12;
    int mindepth = 4;
    int maxdepth = mindepth + 2;
    if (maxdepth < n)
    {
        maxdepth = n;
    }

    int stretch_depth = maxdepth + 1;
    tree_t stretch_tree = bottom_up_tree(0, stretch_depth);
    printf("%i\n", item_check(stretch_tree));
    free_tree(stretch_tree);

    tree_t long_lived_tree = bottom_up_tree(0, maxdepth);

    for (int depth = mindepth; depth < maxdepth + 1; depth += 2)
    {
        int iterations = 1 << (maxdepth - depth + mindepth);
        int check = 0;
        for (int i = 0; i < iterations; i++)
        {
            tree_t tree1 = bottom_up_tree(1, depth);
            check += item_check(tree1);
            free_tree(tree1);
            tree_t tree2 = bottom_up_tree(-1, depth);
            check += item_check(tree2);
            free_tree(tree2);
        }
        printf("%i\n", check);
    }

    printf("%i\n", item_check(long_lived_tree));
    free_tree(long_lived_tree);
    return 0;
}