
# Paka
Paka is a programming language that features dynamic types, unambiguous syntax, and statement expressions. Paka can also refer to the default implementation of that language.

# Purr
Purr is a virtual machine that, for now, runs the Paka language.

# Implementation

## Pipeline
Alot has to happen before Paka can be ran.

1. Paka has source code as a string.
2. Paka chunks the string into parts called tokens.
3. Paka parses the tokens into a Paka Syntax Tree.
6. Purr transforms the Paka Syntax Tree into an Purr Abstract Tree. 
6. Purr walks this tree and generates Purr Intermediate Representation blocks.
7. Purr iterates over these blocks and generates Function objects.
8. Purr runs the Function objects.
