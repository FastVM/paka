module test;
import core.thread.fiber;
import std.stdio;

void other() {
    writeln(10);
}

void main() {
    Fiber fiber = new Fiber(&other);
    fiber.call();
}