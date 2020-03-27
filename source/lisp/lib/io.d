module lisp.lib.io;
private import lisp.dynamic: Dynamic, Array;

Dynamic print(Array args) {
    import std.stdio: write, writeln;
    import lisp.dynamic: dynamic, nil;
    foreach (i; args) {
        write(i);
    }
    writeln;
    return nil;
}