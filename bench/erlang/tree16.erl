#!/usr/bin/env escript

-module('binary-trees').
-export([main/1]).
-mode(compile).

make_tree(Item, Depth) when Depth > 0 ->
    Item2 = Item + Item,
    Depth2 = Depth - 1,
    { Item, make_tree(Item2 - 1, Depth2), make_tree(Item2, Depth2) };
make_tree(Item, _) ->
    { Item, nil, nil }.

check_tree({ Item, nil, _ }) ->
    Item;
check_tree({ Item, Left, Right }) ->
    Item + check_tree(Left) - check_tree(Right).

loop2(N, Max, Check, _) when N >= Max ->
    Check;
loop2(N, Max, Check, Depth) ->
    Check2 = Check + check_tree(make_tree(N, Depth)) + check_tree(make_tree(-N, Depth)),
    loop2(N + 1, Max, Check2, Depth).

loop(Depth, MaxDepth, _) when Depth >= MaxDepth ->
    ok;
loop(Depth, MaxDepth, Iterations) ->
    Check = loop2(1, Iterations + 1, 0, Depth),
    io:format("~p~n", [Check]),
    loop(Depth + 2, MaxDepth, Iterations div 4).

main(_) ->
    MinDepth = 4,
    MaxDepth = 16,
    StretchDepth = MaxDepth + 1,
    io:format("~p~n", [check_tree(make_tree(0, StretchDepth))]),
    LongLivedTree = make_tree(0, MaxDepth),
    Iterations = round(math:pow(2, MaxDepth)),
    loop(MinDepth, StretchDepth, Iterations),
    io:format("~p~n", [check_tree(LongLivedTree)]).