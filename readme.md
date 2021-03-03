
# Paka language

(WARNING: much is broken now as the JIT is being developed)

## Datatypes

`nil`: lack of a value

`logical`: either `true` or `false`

`number`: some real number
* no less accurate than single precision floating point
* no bitops yet

`string`: textual data
* cannot be indexed as they are not a collection
* `str` has useful utilities for string data

`array`: starting at 0, mixed element types allowed
* it is faster to not mix the element types in the array
* arrays use the `~` operator for concatenation
* arrays compare deeply by `==` and `!=`

`table`: mapping from key to value
* tables have a lua-style metatable
* tables can emulate all datatypes other than `logical` and `nil`
* tables keys can be anything, even themselves
* tables are compared deeply by `==` and `!=`

`callable`: something that may be called
* does not compare using == and != like one would expect

# Implementation

## Paka
Paka is a programming language that features dynamic types, unambiguous syntax, and statement expressions. Paka can also refer to the default implementation of that language.

The steps Paka takes to generate Purr AST are:
* Read a specified file into a string.
* Split the string into an array of tokens.
* Parse the tokens into an internal representation.
* Turn that internal representation into an AST-like form (AST+) that purr can understand.

## Purr
Purr is the backend for Paka's frontend.

The steps Purr takes to run code are:
* Take an AST+ from a frontend like Paka.
* Transform the AST+ into an Intermediate Representation (IR).
* Annotate the types in the IR to the best of what is available.
* Transform the typed parts of the IR into native code using GCC (NativeFunction).
* Transform the untyped parts of the IR into a series of bytecode object (BytecodeFunction).
* Run any NativeFunctions by calling them directly.
* Run any BytecodeFunctions by a standard interpreter.
