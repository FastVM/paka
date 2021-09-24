#!/usr/bin/env escript

-module('fib-recurs').
-export([main/1]).
-mode(compile).

-spec fib(int) -> int.
fib(N) when N < 2 ->
    N;
fib(N) ->
    fib(N - 2) + fib(N - 1).

main(_) ->
    io:format("~p~n", [fib(45)]).