# arr

The array library contains utilites for dealing with arrays.

## arr.split

Takes an array and separators.
Returns a new array with sub-arrays of elements between each separator.

input | output | reasoning
--- | --- | ---
`arr.split([0, 0, 1, 1, 0, 1, 1, 0], 0)` | `[[], [], [1, 1], [1, 1], []]` | empty arrays represent two values next to one another
`arr.split([], "not there")` | `[[]]` | always returns atleast one array
`arr.split([[1], [2], [1], [2]], [1])` | `[[], [[2]], [[2]]]` | elements are deep compared
`arr.split(["zero", 1, 1, "one", 1, 1, "two", 1, 1, "three"], [1, 1])` | `[["zero", 1, 1, "one", 1, 1, "two", 1, 1, "three"]]` | this is not how to check for multiple values
`arr.split(["zero", 1, 1, "one", 1, 1, "two", 1, 1, "three"], 1, 1)` | `[["zero"], ["one"], ["two"], ["three"]]` | this is how to split on sequence
`arr.split("abacaba", "a")` | type error | split expects an array

## arr.fsplit

Takes an array and a function to act as seperator.

input | output | reasoning
--- | --- | ---
`arr.fsplit([0, 1, 2, 3, 4, 5, 6, 7, 8]) { $0 % 3 == 0 }` | `[[1, 2], [4, 5], [7, 8]]` | splits on every element divisible by 3
`arr.fsplit([0, "sep", "no", 1, "sep", "nope", 2]) { $0 == "sep" && 2 }` | `[[0], [1], [2]]` | splits on every string "sep", 2 indicates that sep and the next value are the sperator

## arr.slice

Takes an array, a starting position, and an ending position. Returns a new array containing the indexes in the array from the start upto the end. Does not handle negative indexes.
input | output
--- | ---
`arr.slice([0, 1, 2, 3, 4], 1, 3)` | `[1, 2]`
`arr.slice([], 0, 0)` | `[]`
`arr.slice([0, 1, 2], 0, 3)` | `[0, 1, 2]`
`arr.slice([0, 1, 2], 0, 5)` | range error

## arr.sorted

Takes an array, returns a sorted copy. Does not modify the array itself.
input | output
--- | ---
`arr.sorted([0, 2, 1])` | `[0, 1, 2]`
`arr.sorted(["ayy", "cee", "bee"])` | `["ayy", "bee", "cee"]`
`arr.sorted([[0], [3], [1], [2]])` | `[[0], [1], [2], [3]]`
`arr.sorted(([[0, 1], nil, false, {1: 0}, [1], [2], [], {1: 1}, 2, {}, [0], true, 1, [0, 0], {0: 0}, [1, 0], 0, {0: 1}])` | `[nil, false, true, 0, 1, 2, [], [0], [1], [2], [0, 0], [0, 1], [1, 0], {}, {0: 0}, {0: 1}, {1: 0}, {1: 1}]`
`arr.sorted(1)` | type error

## arr.len

Gets length of an array
input | output
--- | ---
`arr.len([])` | `0`
`arr.len([1])` | `1`
`arr.len([1, [2, 3]])` | `2`

## arr.pop

Removes the last element of an array
setup | input | equivalent
--- | --- | ---
`a = [0, 1, 2, 3]` | `arr.pop(a)` | `a = [0, 1, 2]`
`empty = []` | `arr.pop(empty)` | range error

## arr.zip

Zips arrays together. Similar to reflecting a matrix.

input | output
--- | ---
`arr.zip([1, 2, 3], [10, 20, 30])` | `[[1, 10], [2, 20], [3, 30]]`
`arr.zip([1, 10], [2, 20], [3, 30])` | `[[1, 2, 3], [10, 20, 30]]`
`arr.zip([4, 5, 6, 7])` | `[[4], [5], [6], [7]]`
`arr.zip()` | range error
`arr.zip([1], [])` | range error

## arr.map

Takes an array and a function, applies the function to each element of the array, build new array from results.
input | output
--- | ---
`arr.map([0, 1, 2]) {$0 * 2}` | `[0, 2, 4]`
`arr.map([4, 9, 8, 4]) {$0 + $1}` | `[0, 10, 10, 7]`
`arr.map(["h", "e", "l", "l", "o"]) {args}` | `[["h", 0], ["e", 1], ["l", 2], ["l", 3], ["o", 4]]`

## arr.each
Takes an array and a function, applies the function to each element of the array, discarding the result and keeping side effects.

## arr.from

Calls metatable `.arr` with args.
