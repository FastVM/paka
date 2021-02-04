const getRand5 = function () {
    return Math.ceil(Math.random() * 5);
};

const rand7arr = [
    [1,2,3,4,5],
    [6,7,1,2,3],
    [4,5,6,7,1],
    [2,3,4,5,6],
    [7]
];

const getRand7 = function () {
    let result = rand7arr[getRand5() - 1][getRand5() - 1];
    if (result === undefined) {
        return getRand7();
    }
    return result;
}

const n = 10000;

let arr5 = new Array(5).fill(0);
for (let i = 0; i < n * 5; ++i) {
    ++arr5[getRand5() - 1];
}

console.log(arr5);
console.log("should be 5: ", arr5.reduce((x, y) => x + y, 0) / n);

let arr7 = new Array(7).fill(0);
for (let i = 0; i < n * 7; ++i) {
    ++arr7[getRand7() - 1];
}

console.log(arr7);
console.log("should be 7: ", arr7.reduce((x, y) => x + y, 0) / n);