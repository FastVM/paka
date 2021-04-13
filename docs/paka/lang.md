# Syntax 

Paka's Syntax is defined by a series of forms. Each form can be slotted into other forms. Paka's parser can start parsing from any one of the forms, but usually starts parsing with a BlockBody

## Blocks

Blocks are groups of Statments. The only block_body ever parsed outside of a block is the program's top level block.

``` bnf
block: "{" block_body "}" 
block_body: (";"* stmt)* ";"*
```

## Statments

Statments result in no value. When used at the end of a block, the block results in `nil` .
A statment must not start with `(` , `[` or `{` . This fixes ambiguity issues that would arrise otheriwse, as well as making it an erorr to write something like `thing[2]` when trying to get index `2` of thing (Use `thing.2` or `thing.[2]` instead).

``` bnf
stmt: return | assert | def | base_expr
return: "return" base_expr
assert: "assert" base_expr
def: "def" base_expr parens block
%ignore ";"
```

## Expressions

Expressions result in some value.

``` bnf
base_expr: binary_set
```

### Binary Expressions

Binary Expressions are a prefix value, or the result of binary operators. 

``` bnf
binary_set: binary_pipe (dot_set binary_pipe)*
binary_pipe: binary_func (dot_pipe binary_func)*
binary_func: bianry_cmp (dot_func bianry_cmp)*
bianry_cmp: bianry_add (dot_cmp bianry_add)*
bianry_add: bianry_mult (dot_add bianry_mult)*
bianry_mult: bianry_range (dot_mult bianry_range)*
bianry_range: prefix (dot_range prefix)*
```

Binary operators follow a table currently defined in [ext/paka/tokens.d](/ext/paka/tokens.d): `ext.paka.tokens.prec`

#### Binary Operators

``` bnf
SET: "+=" | "~=" | "*=" | "/=" | "%=" | "-=" | "="
PIPE: "|>" | "<|"
FUNC: "=>"
LOGIC: "||" | "&&"
CMP: "<=" | ">=" | "<" | ">" | "!=" | "=="
ADD: "+" | "-" | "~"
MULT: "*" | "/" | "%"
RANGE: "->"
```

#### Binary Meta Operators

Binary operators can be modifed by the meta operators.
For any binary operator there are 4 meta-operations, defined by 2 meta operators.

* op `.`
    - similar to `arr.map(rhs) { lhs op $0 }`
* `.` op 
    - similar to `arr.map(lhs) { $0 op rhs }`
* `.` op `.`
    - similar to `arr.map(0 -> #lhs) { lhs.[$0] op rhs.[$0] }`
    - rhs and lhs must be the same length
* `\` op `\`

    - no equivalent `arr.` call
    - folds the array rhs, starting with lhs

``` bnf
dot_set: SET
    | META_MAP dot_set
    | dot_set META_MAP
    | META_FOLD dot_set META_FOLD 
dot_pipe: PIPE
    | META_MAP dot_pipe
    | dot_pipe META_MAP
    | META_FOLD dot_pipe META_FOLD 
dot_func: FUNC
    | META_MAP dot_func
    | dot_func META_MAP
    | META_FOLD dot_func META_FOLD 
dot_cmp: CMP
    | META_MAP dot_cmp
    | dot_cmp META_MAP
    | META_FOLD dot_cmp META_FOLD 
dot_add: ADD
    | META_MAP dot_add
    | dot_add META_MAP
    | META_FOLD dot_add META_FOLD 
dot_mult: MULT
    | META_MAP dot_mult
    | dot_mult META_MAP
    | META_FOLD dot_mult META_FOLD 
dot_range: RANGE
    | META_MAP dot_range
    | dot_range META_MAP
    | META_FOLD dot_range META_FOLD 
```

### Preifx Expression

``` bnf
prefix: prefix_op postfix
```

#### Prefix Operators

The only unique preifx operator is `#` .

``` bnf
LENGTH: "#"
```

#### Prefix Meta Operators

Binary Operators can be used in prefix when followed by `\` . This will cause the operaotr to fold over the array on thr right hand side.

``` bnf
prefix_op: single_prefix_op+
single_prefix_op: LENGTH 
    | prefix_op META_MAP
    | prefix_foldable "\"
prefix_foldable: dot_pipe | dot_func | dot_logic | dot_cmp | dot_add | dot_mult
```

### Postfix Expressions

There are many types of postfix expression. They are a single value followed by zero or more postfix-extend sequence.

``` bnf
postfix: single postfix_extension
```

### Postfix Extensions
These are the function calls and array index type operations.

```bnf
postfix_extension: call
call: args block+
args: "("  (expr_base ",")* expr_base? ")"
index: "." parens | "." IDENT | "." "[" expr_base "]" 
```

### Single Values

Single values are of the lowest precidence.

``` bnf
single: lambda
    | static
    | parens
    | array | table
    | if | while
    | ident | string
lambda: "lambda" call
static: "static" block
parens: "(" expr_base ")"
table: "{" (table_entry ", ")* table_entry? "}"
table_entry: expr_base ":" expr_base
array: "{" (expr_base ", ")* expr_base? "}"
if: "if" parens block 
while: "while" parens block
string: QUOTE string_part QUOTE
string_part: string_char
    | string_escape_format
    | string_escape_unicode
        | string_escape_format_unicode
string_escape_format: "\\" "f" "{" expr_base "}"
string_escape_unicode: "\\" "u" "{" UNICODE_NAME "}"
string_escape_format_unicode: "\\" ("uf" | "fu") "{" expr_base "}"

UNICODE_NAME: /[a-zA-Z_]+/
QUOTE: "\""
```

### Skipped Characters

```bnf
%ignore " " | "\n" | "\r" | "\t" 