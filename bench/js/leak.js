let x = 0;
let leak = [];
while (x < 100000000) {
    leak = [[[[[[[[[[x]]]]]]]]]];
    x = x + 1;
}
console.log(leak[0][0][0][0][0][0][0][0][0][0]);