module libbf-d.bigfloat;

import lang.data.bf;
import core.memory;
import std.string;
import std.stdio;

// bf_context_t ctx;

// struct BigFloat
// {
//     bf_t bf;
// }

// void* bf_gc_realloc(void* opaque, void* ptr, size_t size)
// {
//     return GC.realloc(ptr, size);
// }

// void run()
// {
//     bf_context_init(&ctx, &bf_gc_realloc, null);
//     bf_t val;
//     bf_init(&ctx, &val);
//     bf_atof(&val, cast(char*) "10".toStringz, null, 10, bf_prec_max, bf_rnd_t.bf_rndn);
//     char* pchar = bf_ftoa(cast(ulong*) null, &val, 10, bf_prec_max,
//             bf_rnd_t.bf_rndz | bf_ftoa_format_free);
//     string str = cast(string) pchar.fromStringz;
//     writeln(str);
// }

// static this()
// {
//     run();
// }
