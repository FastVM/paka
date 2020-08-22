module lang.lib.func;
import lang.dynamic;

Dynamic librange(Args args)
{
    if (args.length == 1)
    {
        Dynamic[] ret;
        foreach (i; Number(0) .. args[0].num)
        {
            ret ~= dynamic(i);
        }
        return dynamic(ret);
    }
    if (args.length == 2)
    {
        Dynamic[] ret;
        foreach (i; args[0].num .. args[1].num)
        {
            ret ~= dynamic(i);
        }
        return dynamic(ret);
    }
    throw new Exception("bad number of arguments to range");
}
