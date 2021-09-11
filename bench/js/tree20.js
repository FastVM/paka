function bottomUpTree(item, depth) {
    if (depth != 0) {
        let i = item + item
        let left = bottomUpTree(i - 1, depth - 1)
        let right = bottomUpTree(i, depth - 1)
        return [item, left, right];
    } else {
        return [item];
    }
}

function itemCheck(tree) {
    if (tree.length != 1) {
        return tree[0] + itemCheck(tree[1]) - itemCheck(tree[2]);
    } else {
        return tree[0];
    }
}

let N = 20;
let minDepth = 4;
let maxDepth = minDepth + 2;
if (maxDepth < N) {
    maxDepth = N;
}

let stretchTreeDepth = maxDepth + 1;
let stretchTree = bottomUpTree(0, stretchTreeDepth);
console.log(itemCheck(stretchTree));

let longLivedTree = bottomUpTree(0, maxDepth);

for (let depth = minDepth; depth < maxDepth + 1; depth += 2) {
    let iters = 1 << (maxDepth - depth + minDepth);
    let checks = 0
    for (let check = 0; check < iters; check++) {
        let cur = itemCheck(bottomUpTree(1, depth)) + itemCheck(bottomUpTree(-1, depth));
        checks += cur;
    }
    console.log(checks);
}

console.log(itemCheck(longLivedTree));
