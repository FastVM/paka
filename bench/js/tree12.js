function bottom_up_tree(item, depth) {
    if (depth > 0) {
        let i = item + item;
        let left = bottom_up_tree(i - 1, depth - 1);
        let right = bottom_up_tree(i, depth - 1);
        return [item, left, right];
    } else {
        return [item];
    }
}

function item_check(tree) {
    if (tree.length == 3) {
        return tree[0] + item_check(tree[1]) - item_check(tree[2]);
    } else {
        return tree[0];
    }
}

let min_depth = 4;
let max_depth = 12;

let stretch_depth = max_depth + 1;
let stretch_tree = bottom_up_tree(0, stretch_depth);
console.log("stretch tree of depth", stretch_depth, "check:", item_check(stretch_tree));

let long_lived_tree = bottom_up_tree(0, max_depth);
let depth = min_depth;
while (depth <= max_depth) {
    let iterations = Math.pow(2, max_depth - depth + min_depth);
    let check = 0;
    let i = 1;
    while (i <= iterations) {
        check = check + item_check(bottom_up_tree(1, depth)) +
            item_check(bottom_up_tree(0 - 1, depth));
        i = i + 1;
    }
    depth = depth + 2;
    console.log(iterations * 2, "trees of depth", depth, "check:", check);
}
console.log("long lived tree of depth", max_depth, "check:", item_check(long_lived_tree));