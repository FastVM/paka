module lang.lib.func;
import lang.dynamic;
import lang.number;

// Dynamic librange(Args args)
// {
//     if (args.length == 1)
//     {
//         Dynamic[] ret;
//         foreach (i; as!Number(0) .. args[0].as!size_t)
//         {
//             ret ~= dynamic(i);
//         }
//         return dynamic(ret);
//     }
//     if (args.length == 2)
//     {
//         Dynamic[] ret;
//         foreach (i; args[0].as!long .. args[1].as!long)
//         {
//             ret ~= dynamic(i);
//         }
//         return dynamic(ret);
//     }
//     throw new Exception("bad number of arguments to range");
// }
