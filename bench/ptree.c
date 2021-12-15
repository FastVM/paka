
#include <stdio.h>
#include <stdlib.h>

struct tree_t;
typedef struct tree_t tree_t;

struct tree_t {
    tree_t *pair; 
    int item;
};

int tree_size(int depth) {
    if (depth != 0) {
        return 2 + tree_size(depth - 1) * 2;
    } else {
        return 0;
    }
}

tree_t xbottom_up_tree(tree_t **ptr, int item, int depth) {
    if (depth != 0) {
        int i = item + item;
        tree_t *pair = *ptr;
        *ptr += 2;
        pair[0] = xbottom_up_tree(ptr, i-1, depth - 1);
        pair[1] = xbottom_up_tree(ptr, i, depth - 1);
        return (tree_t) {
            .item = item,
            .pair = pair,
        };
    } else {
        return (tree_t) {
            .item = item,
        };
    }
}

tree_t bottom_up_tree(int item, int depth) {
    int size = tree_size(depth);
    tree_t *ptr = malloc(sizeof(tree_t) * size);
    return xbottom_up_tree(&ptr, item, depth);
}

void delete_tree(tree_t tree) {
    free(tree.pair);
}

int item_check(tree_t tree) {
    if (tree.pair != NULL) {
        return tree.item + item_check(tree.pair[0]) - item_check(tree.pair[1]);
    } else {
        return tree.item;
    }
}

int main(int argc, char **argv) {
    if (argc < 2) {
        printf("error: need an integer argument\n");
        exit(1);
    }

    int N = atoi(argv[1]);
    int mindepth = 4;
    int maxdepth = mindepth + 2;
    if (maxdepth < N) {
        maxdepth = N;
    }

    int stretchdepth = maxdepth + 1;
    tree_t tree = bottom_up_tree(0, stretchdepth);
    printf("%i\n", item_check(tree));
    delete_tree(tree);

    tree_t longlivedtree = bottom_up_tree(0, maxdepth);

    int depth = mindepth;
    while (depth < maxdepth + 1) {
        int iters = 1 << (maxdepth - depth + mindepth);
        int check = 0;
        int checks = 0;
        while (check < iters) {
            tree_t tree1 = bottom_up_tree(1, depth);
            checks = checks + item_check(tree1); 
            delete_tree(tree1);
            tree_t tree2 = bottom_up_tree(0-1, depth);
            checks = checks + item_check(tree2);
            delete_tree(tree2);
            check += 1;
        }
        printf("%i\n", checks);
        depth += 2;
    }
    printf("%i\n", item_check(longlivedtree));
    delete_tree(longlivedtree);
}
