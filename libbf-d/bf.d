module libbf-d.bf;

import gfm.integers;

version (X86_64)
{
    enum size_t limb_log2_bits = 6;
}
else
{
    enum size_t limb_log2_bits = 5;
}

enum size_t limb_bits = 1 << limb_log2_bits;

static if (limb_bits == 64)
{
    alias slimb_t = long;
    alias limb_t = ulong;
    alias dlimb_t = uwideint!128;
    enum size_t bf_raw_exp_min = long.min;
    enum size_t bf_raw_exp_max = long.max;
    enum size_t limb_digits = 19;
    enum size_t bf_dec_base = 10000000000000000000;
}
else
{
    alias slimb_t = int;
    alias limb_t = uint;
    alias dlimb_t = ulong;
    enum size_t bf_raw_exp_min = int.min;
    enum size_t bf_raw_exp_max = int.max;
    enum size_t limb_digits = 9;
    enum size_t bf_dec_base = 1000000000;
}

enum size_t bf_exp_bits_min = 3;
enum size_t bf_exp_bits_max = limb_bits - 3;
enum size_t bf_ext_exp_bits_max = bf_exp_bits_max + 1;
enum size_t bf_prec_min = 2;
enum size_t bf_prec_max = ((cast(limb_t) 1 << (limb_bits - 2)) - 2);
enum size_t bf_prec_inf = bf_prec_max + 1;
static if (limb_bits == 64)
{
    enum size_t bf_chksum_mod = 975620677 * 9795002197;
}
else
{
    enum size_t bf_chksum_mod = 975620677;
}
enum size_t bf_exp_zero = bf_raw_exp_min;
enum size_t bf_exp_inf = bf_raw_exp_max - 1;
enum size_t bf_exp_nan = bf_raw_exp_max;

struct bf_t
{
    bf_context_t* ctx;
    int sign;
    slimb_t expn;
    limb_t len;
    limb_t* tab;
}

struct bfdec_t
{
    bf_context_t* ctx;
    int sign;
    slimb_t expn;
    limb_t len;
    limb_t* tab;
}

enum bf_rnd_t
{
    bf_rndn, // round to nearest, ties to even
    bf_rndz, // round to zero
    bf_rndd, // round to -inf
    bf_rndu, // round to +inf
    bf_rndna, // round to nearest, ties away from zero
    bf_rnda, // round away from zero
    bf_rndf, // faithful rounding
    bf_divrem_euclidean = bf_rndf,
}

enum size_t bf_flag_subnormal = 1 << 3;
enum size_t bf_flat_radpnt_prec = 1 << 4;
enum size_t bf_rnd_mask = 0x7;
enum size_t bf_exp_bits_shift = 5;
enum size_t bf_exp_bits_mask = 0x3F;
enum size_t bf_flat_ext_exp = bf_exp_bits_mask << bf_exp_bits_shift;

alias bf_flags_t = uint;
alias bf_realloc_func_t = void* function(void* opaque, void* ptr, size_t size);
struct BFConstCache
{
    bf_t val;
    limb_t prec;
}

enum size_t nb_mods = 5;
enum size_t ntt_trig_k_max = 19;

alias NTTLimb = limb_t;

static if (limb_bits == 64)
{
    enum size_t ntt_proot_2exp = 51;
}
else
{
    enum size_t ntt_proot_2exp = 20;
}

struct BFNTTState
{
    bf_context_t* ctx;

    limb_t[nb_mods] ntt_mods_div;

    limb_t[nb_mods][2][ntt_proot_2exp + 1] ntt_proot_pow;
    limb_t[nb_mods][2][ntt_proot_2exp + 1] ntt_proot_pow_inv;
    NTTLimb[nb_mods][2][ntt_trig_k_max + 1]* ntt_trig;
    limb_t[nb_mods][ntt_proot_2exp + 1][2] ntt_len_inv;
    limb_t[nb_mods * (nb_mods - 1) / 2] ntt_mods_cr_inv;
}

struct bf_context_t
{
    void* realloc_opaque;
    bf_realloc_func_t realloc_func;
    BFConstCache log2_cache;
    BFConstCache pi_cache;
    BFNTTState* ntt_state;
}

pragma(inline, true) ulong bf_get_exp_bits(bf_flags_t flags)
{
    int e;
    e = (flags >> bf_exp_bits_shift) & bf_exp_bits_mask;
    if (e == bf_exp_bits_mask)
        return bf_exp_bits_max + 1;
    else
        return bf_exp_bits_max - e;
}

pragma(inline, true) bf_flags_t bf_set_exp_bits(int n)
{
    return ((bf_exp_bits_max - n) & bf_exp_bits_mask) << bf_exp_bits_shift;
}

enum size_t bf_st_invalid_op = 1 << 0;
enum size_t bf_st_divide_zero = 1 << 1;
enum size_t bf_st_overflow = 1 << 2;
enum size_t bf_st_underflow = 1 << 3;
enum size_t bf_st_indexact = 1 << 4;
enum size_t bf_st_mem_error = 1 << 5;

pragma(inline, true) slimb_t bf_max(slimb_t a, slimb_t b)
{
    if (a > b)
        return a;
    else
        return b;
}

pragma(inline, true) slimb_t bf_min(slimb_t a, slimb_t b)
{
    if (a < b)
        return a;
    else
        return b;
}

pragma(inline, true) void* bf_realloc(bf_context_t* s, void* ptr, size_t size)
{
    return (*s.realloc_func)(s.realloc_opaque, ptr, size);
}

pragma(inline, true) void* bf_malloc(bf_context_t* s, size_t size)
{
    return bf_realloc(s, null, size);
}

pragma(inline, true) void bf_free(bf_context_t* s, void* ptr)
{
    if (ptr)
        bf_realloc(s, ptr, 0);
}

pragma(inline, true) void bf_delete(bf_t* r)
{
    bf_context_t* s = r.ctx;
    if (s && r.tab)
    {
        bf_realloc(s, r.tab, 0);
    }
}

pragma(inline, true) void bf_neg(bf_t* r)
{
    r.sign ^= 1;
}

pragma(inline, true) int bf_is_finite(bf_t* a)
{
    return (a.expn < bf_exp_inf);
}

pragma(inline, true) int bf_is_nan(bf_t* a)
{
    return (a.expn == bf_exp_nan);
}

pragma(inline, true) int bf_is_zero(bf_t* a)
{
    return (a.expn == bf_exp_zero);
}

pragma(inline, true) void bf_memcpy(bf_t* r, bf_t* a)
{
    *r = *a;
}

enum size_t bf_ftoa_format_free = 2 << 16;
enum size_t bf_ftoa_format_free_min = 3 << 16;

extern (C):
char* bf_ftoa(size_t* plen, bf_t* a, int radix, limb_t prec, bf_flags_t flags);
void bf_context_init(bf_context_t* s, bf_realloc_func_t realloc_func, void* realloc_opaque);
void bf_context_end(bf_context_t* s);
void bf_clear_cache(bf_context_t* s);
void bf_init(bf_context_t* s, bf_t* r);
int bf_set_ui(bf_t* r, ulong a);
int bf_set_si(bf_t* r, long a);
void bf_set_nan(bf_t* r);
void bf_set_zero(bf_t* r, int is_neg);
void bf_set_inf(bf_t* r, int is_neg);
int bf_set(bf_t* r, bf_t* a);
void bf_move(bf_t* r, bf_t* a);
int bf_get_float64(bf_t* a, double* pres, bf_rnd_t rnd_mode);
int bf_set_float64(bf_t* a, double d);
int bf_cmpu(bf_t* a, bf_t* b);
int bf_cmp_full(bf_t* a, bf_t* b);
int bf_cmp(bf_t* a, bf_t* b);
int bf_add(bf_t* r, bf_t* a, bf_t* b, limb_t prec, bf_flags_t flags);
int bf_sub(bf_t* r, bf_t* a, bf_t* b, limb_t prec, bf_flags_t flags);
int bf_add_si(bf_t* r, bf_t* a, long b1, limb_t prec, bf_flags_t flags);
int bf_mul(bf_t* r, bf_t* a, bf_t* b, limb_t prec, bf_flags_t flags);
int bf_mul_ui(bf_t* r, bf_t* a, ulong b1, limb_t prec, bf_flags_t flags);
int bf_mul_si(bf_t* r, bf_t* a, long b1, limb_t prec, bf_flags_t flags);
int bf_mul_2exp(bf_t* r, slimb_t e, limb_t prec, bf_flags_t flags);
int bf_div(bf_t* r, bf_t* a, bf_t* b, limb_t prec, bf_flags_t flags);
int bf_divrem(bf_t* q, bf_t* r, bf_t* a, bf_t* b, limb_t prec, bf_flags_t flags, int rnd_mode);
int bf_rem(bf_t* r, bf_t* a, bf_t* b, limb_t prec, bf_flags_t flags, int rnd_mode);
int bf_remquo(slimb_t* pq, bf_t* r, bf_t* a, bf_t* b, limb_t prec, bf_flags_t flags, int rnd_mode);
int bf_rint(bf_t* r, int rnd_mode);
int bf_round(bf_t* r, limb_t prec, bf_flags_t flags);
int bf_sqrtrem(bf_t* r, bf_t* rem1, bf_t* a);
int bf_sqrt(bf_t* r, bf_t* a, limb_t prec, bf_flags_t flags);
slimb_t bf_get_exp_min(bf_t* a);
int bf_logic_or(bf_t* r, bf_t* a, bf_t* b);
int bf_logic_xor(bf_t* r, bf_t* a, bf_t* b);
int bf_logic_and(bf_t* r, bf_t* a, bf_t* b);
enum size_t bf_atof_no_hex = 1 << 16;
enum size_t bf_atof_bin_oct = 1 << 17;
enum size_t bf_atof_no_nan_inf = 1 << 18;
enum size_t bf_atof_exponent = 1 << 19;
int bf_atof(bf_t* a, char* str, char** pnext, int radix, limb_t prec, bf_flags_t flags);
int bf_atof2(bf_t* r, slimb_t* pexponent, char* str, char** pnext, int radix,
        limb_t prec, bf_flags_t flags);
int bf_mul_pow_radix(bf_t* r, bf_t* T, limb_t radix, slimb_t expn, limb_t prec, bf_flags_t flags);
int bf_get_int32(int* pres, bf_t* a, int flags);
int bf_get_int64(long* pres, bf_t* a, int flags);

void mp_print_str(char* str, limb_t* tab, limb_t n);
void bf_print_str(char* str, bf_t* a);
int bf_resize(bf_t* r, limb_t len);
int bf_get_fft_size(int* pdpl, int* pnb_mods, limb_t len);
int bf_normalize_and_round(bf_t* r, limb_t prec1, bf_flags_t flags);
int bf_can_round(bf_t* a, slimb_t prec, bf_rnd_t rnd_mode, slimb_t k);
slimb_t bf_mul_log2_radix(slimb_t a1, uint radix, int is_inv, int is_ceil1);
int mp_mul(bf_context_t* s, limb_t* result, limb_t* op1, limb_t op1_size,
        limb_t* op2, limb_t op2_size);
limb_t mp_add(limb_t* res, limb_t* op1, limb_t* op2, limb_t n, limb_t carry);
limb_t mp_add_ui(limb_t* tab, limb_t b, size_t n);
int mp_sqrtrem(bf_context_t* s, limb_t* tabs, limb_t* taba, limb_t n);
int mp_recip(bf_context_t* s, limb_t* tabr, limb_t* taba, limb_t n);
limb_t bf_isqrt(limb_t a);

int bf_const_log2(bf_t* T, limb_t prec, bf_flags_t flags);
int bf_const_pi(bf_t* T, limb_t prec, bf_flags_t flags);
int bf_exp(bf_t* r, bf_t* a, limb_t prec, bf_flags_t flags);
int bf_log(bf_t* r, bf_t* a, limb_t prec, bf_flags_t flags);
int bf_pow(bf_t* r, bf_t* x, bf_t* y, limb_t prec, bf_flags_t flags);
int bf_cos(bf_t* r, bf_t* a, limb_t prec, bf_flags_t flags);
int bf_sin(bf_t* r, bf_t* a, limb_t prec, bf_flags_t flags);
int bf_tan(bf_t* r, bf_t* a, limb_t prec, bf_flags_t flags);
int bf_atan(bf_t* r, bf_t* a, limb_t prec, bf_flags_t flags);
int bf_atan2(bf_t* r, bf_t* y, bf_t* x, limb_t prec, bf_flags_t flags);
int bf_asin(bf_t* r, bf_t* a, limb_t prec, bf_flags_t flags);
int bf_acos(bf_t* r, bf_t* a, limb_t prec, bf_flags_t flags);
int bfdec_add(bfdec_t* r, bfdec_t* a, bfdec_t* b, limb_t prec, bf_flags_t flags);
int bfdec_sub(bfdec_t* r, bfdec_t* a, bfdec_t* b, limb_t prec, bf_flags_t flags);
int bfdec_add_si(bfdec_t* r, bfdec_t* a, long b1, limb_t prec, bf_flags_t flags);
int bfdec_mul(bfdec_t* r, bfdec_t* a, bfdec_t* b, limb_t prec, bf_flags_t flags);
int bfdec_mul_si(bfdec_t* r, bfdec_t* a, long b1, limb_t prec, bf_flags_t flags);
int bfdec_div(bfdec_t* r, bfdec_t* a, bfdec_t* b, limb_t prec, bf_flags_t flags);
int bfdec_divrem(bfdec_t* q, bfdec_t* r, bfdec_t* a, bfdec_t* b, limb_t prec,
        bf_flags_t flags, int rnd_mode);
int bfdec_rem(bfdec_t* r, bfdec_t* a, bfdec_t* b, limb_t prec, bf_flags_t flags, int rnd_mode);
int bfdec_rint(bfdec_t* r, int rnd_mode);
int bfdec_sqrt(bfdec_t* r, bfdec_t* a, limb_t prec, bf_flags_t flags);
int bfdec_round(bfdec_t* r, limb_t prec, bf_flags_t flags);
int bfdec_get_int32(int* pres, bfdec_t* a);
int bfdec_pow_ui(bfdec_t* r, bfdec_t* a, limb_t b);

char* bfdec_ftoa(size_t* plen, bfdec_t* a, limb_t prec, bf_flags_t flags);
int bfdec_atof(bfdec_t* r, char* str, char** pnext, limb_t prec, bf_flags_t flags);
