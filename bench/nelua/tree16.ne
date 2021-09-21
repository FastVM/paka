-- The Computer Language Benchmarks Game
-- http://shootout.alioth.debian.org/
-- contributed by Mike Pall

require 'allocators.default'

local Tree: type = @record{value: int32, lhs: *Tree, rhs: *Tree}
local Tree1: type = @record{value: int32, lhs: *Tree}

local function BottomUpTree(item : int32, depth : int32) : *Tree
  if depth > 0 then
    local i = item + item
    depth = depth - 1
    local left, right = BottomUpTree(i-1, depth), BottomUpTree(i, depth)
    local ret: *Tree = (@*Tree)(default_allocator:alloc(#Tree))
    ret.value = item
    ret.lhs = left
    ret.rhs = right
    return ret
  else 
    local ret: *Tree = (@*Tree)(default_allocator:alloc(#Tree1))
    ret.value = item
    ret.lhs = nilptr
    return ret
  end
end

local function ItemCheck(tree : *Tree) : int32
  if tree.lhs ~= nilptr then
    return tree.value + ItemCheck(tree.lhs) - ItemCheck(tree.rhs)
  else
    return tree.value
  end
end

local N = 16
local mindepth = 4
local maxdepth = mindepth + 2
if maxdepth < N then maxdepth = N end

do
  local stretchdepth = maxdepth + 1
  local stretchtree = BottomUpTree(0, stretchdepth)
  print(ItemCheck(stretchtree))
end

local longlivedtree = BottomUpTree(0, maxdepth)

for depth=mindepth,maxdepth,2 do
  local iterations = 2 ^ (maxdepth - depth + mindepth)
  local check = 0
  for i=1,iterations do
    check = check + ItemCheck(BottomUpTree(1, depth)) +
            ItemCheck(BottomUpTree(-1, depth))
  end
  print(check)
end

print(ItemCheck(longlivedtree))