let n = [0, 0];
while (n[0] < 10000) {
    while (n[1] < 10000) {
        n = [n[0], n[1] + 1, n];
    }
    n = [n[0] + 1, 0];
}
console.log(n[0] + n[1]);