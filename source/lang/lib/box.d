module lang.lib.box;

import lang.dynamic;

Dynamic libbox(Args args)
{
    return Dynamic([args[0]].ptr);
}

Dynamic libunbox(Args args)
{
    return *args[0].box;
}
