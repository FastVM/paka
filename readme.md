# Paka Language
Paka is a fletchling programming language that features a simple dynamic type system, efficient virtual machine and javascript meets python syntax.

## Types

### nil
`nil` is a type that only has one value of the same name.
`nil` is similar to `None` in python and `null` in javascript.
`nil` is not the lack of a value, unlike `nil` in lua and `undefined` in javascript.

examples:
```
io.print();
```
* returns nil (along with a newline in the console)
```
nil;
```
*  is the nil literal
```
lambda(){;}();
```
* by default functions return nil

### logical
`logical` is known as bool or boolean in many other languages.
It only has two values `true` and `false`.

examples:
```
3 == 3; # true
3 != 3; # false
3 > 3; # false
3 < 3; # false
3 >= 3; # true
3 <= 3; # true

1 == 2; # false
1 != 2; # true
1 > 2; # false
1 < 2; # true
1 >= 2; # false
1 <= 2; # true

4 == 0; # false
4 != 0; # true
4 > 0; # true
4 < 0; # false
4 >= 0; # true
4 <= 0; # false

true && true; # true
true && false; # false
false && true; # false
false && false; # false

true || true; # true
true || false; # true
false || true; # true
false || false; # false

if (true) {"it was true";} else {"it was false";}; # "it was true"
if (false) {"it was true";} else {"it was false";}; # "it was false"

while (true) {;}; # this will never exit
while (false) {;}; # this will never run
```

### number
`number` is a floating point value with bigint exponent.
it can accuratly represent any 32 bit unsigned or signed integer.
`number` has an alpha optimziation that turns smaller numbers from pointers to double precision native floating point.

examples:
```
1 + 2 # 3
1 * 2 # 2
1 / 2 # 0.5
1 - 2 # -1
if (0) {"it was true";} else {"it was false";}; # "it was true"
if (1) {"it was true";} else {"it was false";}; # "it was true"
```

### string
`string` is a utf-8 string of text. It is sure to have either a char array or a rope. 

### array
`array` is an list of one or many types. It is a reference datatype.

### table
`table` is a dictonary from any value to any other value.
unlike `dict` in python it can have any value as the key.
unlike `table` in lua, nil is a valid key.

### callable
`callable` is the type of functions, non nested callables are faster than nested ones.

### `--math` alpha

right now there are two modes that the number type can have, the first (with no `--math` flag) *should* act the same as the second with the `--math` flag set.
It yields a 4x-10x speedup and possibly some unknown bugs.