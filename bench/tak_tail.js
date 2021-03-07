function tak_rec(n, x, y, z) {
    if(y < x) {
        return tak_rec(
            n + 1,
            tak_rec(0, x-1, y, z),
            tak_rec(0, y-1, z, x),
            tak_rec(0, z-1, x, y)
        );
    } else {
        return n + z;
    }
}

function tak(x, y, z) {
    return tak_rec(0, x, y, z);
}

console.log(tak_rec);