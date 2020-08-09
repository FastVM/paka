module lang.lib.box;

import lang.dynamic;

Dynamic libbox(Dynamic[] args)
{
    return Dynamic([args[0]].ptr);
}

Dynamic libunbox(Dynamic[] args)
{
    return *args[0].box;
}
