
function bottom_up_tree(item, depth) {
    if (depth !== 0) {
        let i = item + item;
        let left = bottom_up_tree(i-1, depth - 1);
        let right = bottom_up_tree(i, depth - 1);
        return [item, left, right];
    } else {
        return [item];
    }
}

function item_check(tree) {
    if (tree.length !== 1) {
        return tree[0] + item_check(tree[1]) - item_check(tree[2]);
    } else {
        return tree[0];
    }
}

function pow2(n) {
    if (n === 0) {
        return 1;
    } else {
        return pow2(n-1) * 2;
    }
}

if (process.argv.length !== 3) {
    console.log("error: need an integer argument");
} else {
    let N = Number(process.argv[2]);
    let mindepth = 4;
    let maxdepth = mindepth + 2;
    if (maxdepth < N) {
        maxdepth = N;
    }

    let stretchdepth = maxdepth + 1;
    let tree = bottom_up_tree(0, stretchdepth);
    console.log(item_check(tree));
    
    let longlivedtree = bottom_up_tree(0, maxdepth);
    
    let depth = mindepth;
    while (depth < maxdepth + 1) {
        let iters = pow2(maxdepth - depth + mindepth);
        let check = 0;
        let checks = 0;
        while (check < iters) {
            let tree1 = bottom_up_tree(1, depth);
            checks = checks + item_check(tree1);
            let tree2 = bottom_up_tree(0-1, depth);
            checks = checks + item_check(tree2);
            check = check + 1;
        }
        console.log(checks);
        depth = depth + 2;
    }
    console.log(item_check(longlivedtree));
}
