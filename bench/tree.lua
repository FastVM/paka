
local function bottom_up_tree(item, depth)
    if depth ~= 0 then
        local i = item + item
        local left = bottom_up_tree(i-1, depth - 1)
        local right = bottom_up_tree(i, depth - 1)
        return {item, left, right}
    else
        return {item}
    end
end

local function item_check(tree)
    if tree[2] then
        return tree[1] + item_check(tree[2]) - item_check(tree[3])
    else
        return tree[1]
    end
end

local function pow2(n)
    if n == 0 then
        return 1
    else
        return pow2(n-1) * 2
    end
end

if #arg == 0 then
    print("error: need an integer argument")
else
    local N = tonumber(arg[1])
    local mindepth = 4
    local maxdepth = mindepth + 2
    if maxdepth < N then
        maxdepth = N
    end

    local stretchdepth = maxdepth + 1
    local tree = bottom_up_tree(0, stretchdepth)
    print(item_check(tree))

    local longlivedtree = bottom_up_tree(0, maxdepth)

    local depth = mindepth
    while depth < maxdepth + 1 do
        local iters = pow2(maxdepth - depth + mindepth)
        local check = 0
        local checks = 0
        while check < iters do
            local tree1 = bottom_up_tree(1, depth)
            checks = checks + item_check(tree1) 
            local tree2 = bottom_up_tree(0-1, depth)
            checks = checks + item_check(tree2)
            check = check + 1
        end
        print(checks)
        depth = depth + 2
    end
    print(item_check(longlivedtree))
end