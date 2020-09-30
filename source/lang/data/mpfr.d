module lang.data.mpfr;

import core.stdc.stdio : FILE;
import core.stdc.stdarg : va_list;
import core.stdc.config : c_long, c_ulong;

nothrow extern (C):

alias mp_limb_t = c_ulong;

struct __mpz_struct
{
    int _mp_alloc;
    int _mp_size;
    mp_limb_t* _mp_d;
}

alias mpz_t = __mpz_struct;

struct __mpq_struct
{
    __mpz_struct _mp_num;
    __mpz_struct _mp_den;
}

alias mpq_t = __mpq_struct;

alias mp_exp_t = c_long;

struct __mpf_struct
{
    int _mp_prec;
    int _mp_size;
    mp_exp_t _mp_exp;
    mp_limb_t* _mp_d;
}

alias mpf_t = __mpf_struct;

enum mpfr_rnd_t
{
    MPFR_RNDN = 0, /* round to nearest, with ties to even */
    MPFR_RNDZ, /* round toward zero */
    MPFR_RNDU, /* round toward +Inf */
    MPFR_RNDD, /* round toward -Inf */
    MPFR_RNDA, /* round away from zero */
    MPFR_RNDF, /* faithful rounding (not implemented yet) */
    MPFR_RNDNA = -1 /* round to nearest, with ties away from zero (mpfr_round) */
}

// Types
alias mpfr_prec_t = c_long;
alias mpfr_uprec_t = c_ulong;
alias mpfr_sign_t = int;
alias mpfr_exp_t = c_long;
alias mpfr_uexp_t = c_ulong;
alias intmax_t = mpfr_exp_t;
alias uintmax_t = mpfr_uexp_t;

// Structs
struct __mpfr_struct
{
    mpfr_prec_t _mpfr_prec;
    mpfr_sign_t _mpfr_sign;
    mpfr_exp_t _mpfr_exp;
    mp_limb_t* _mpfr_d;
}

alias mpfr_t = __mpfr_struct;
alias mpfr_ptr = __mpfr_struct*;

// Initialization Functions

void mpfr_init2(ref mpfr_t x, mpfr_prec_t prec);
// void mpfr_inits2 (mpfr_prec_t prec, ref mpfr_t x, ...);
void mpfr_clear(ref mpfr_t x);
// void mpfr_clears (ref mpfr_t x, ...);
void mpfr_init(ref mpfr_t x);
// void mpfr_inits (ref mpfr_t x, ...);
void mpfr_set_default_prec(mpfr_prec_t prec);
mpfr_prec_t mpfr_get_default_prec();
void mpfr_set_prec(ref mpfr_t x, mpfr_prec_t prec);
mpfr_prec_t mpfr_get_prec(ref const mpfr_t x);

// Assignment Functions

int mpfr_set(ref mpfr_t rop, ref const mpfr_t op, mpfr_rnd_t rnd);
int mpfr_set_ui(ref mpfr_t rop, c_ulong op, mpfr_rnd_t rnd);
int mpfr_set_si(ref mpfr_t rop, c_long op, mpfr_rnd_t rnd);
int mpfr_set_uj(ref mpfr_t rop, uintmax_t op, mpfr_rnd_t rnd);
int mpfr_set_sj(ref mpfr_t rop, intmax_t op, mpfr_rnd_t rnd);
int mpfr_set_flt(ref mpfr_t rop, float op, mpfr_rnd_t rnd);
int mpfr_set_d(ref mpfr_t rop, double op, mpfr_rnd_t rnd);
int mpfr_set_ld(ref mpfr_t rop, real op, mpfr_rnd_t rnd);
// int mpfr_set_decimal64 (ref mpfr_t rop, _Decimal64 op, mpfr_rnd_t rnd);
int mpfr_set_z(ref mpfr_t rop, ref mpz_t op, mpfr_rnd_t rnd);
int mpfr_set_q(ref mpfr_t rop, ref mpq_t op, mpfr_rnd_t rnd);
int mpfr_set_f(ref mpfr_t rop, ref mpf_t op, mpfr_rnd_t rnd);
int mpfr_set_ui_2exp(ref mpfr_t rop, c_ulong op, mpfr_exp_t e, mpfr_rnd_t rnd);
int mpfr_set_si_2exp(ref mpfr_t rop, c_long op, mpfr_exp_t e, mpfr_rnd_t rnd);
int mpfr_set_uj_2exp(ref mpfr_t rop, uintmax_t op, intmax_t e, mpfr_rnd_t rnd);
int mpfr_set_sj_2exp(ref mpfr_t rop, intmax_t op, intmax_t e, mpfr_rnd_t rnd);
int mpfr_set_z_2exp(ref mpfr_t rop, mpz_t op, mpfr_exp_t e, mpfr_rnd_t rnd);
int mpfr_set_str(ref mpfr_t rop, const(char)* s, int base, mpfr_rnd_t rnd);
int mpfr_strtofr(ref mpfr_t rop, const(char)* nptr, char** endptr, int base, mpfr_rnd_t rnd);
void mpfr_set_nan(ref mpfr_t x);
void mpfr_set_inf(ref mpfr_t x, int sign);
void mpfr_set_zero(ref mpfr_t x, int sign);
void mpfr_swap(ref mpfr_t x, ref mpfr_t y);
int mpfr_init_set_str(ref mpfr_t x, const(char)* s, int base, mpfr_rnd_t rnd);

// Conversion Functions

float mpfr_get_flt(ref const mpfr_t op, mpfr_rnd_t rnd);
double mpfr_get_d(ref const mpfr_t op, mpfr_rnd_t rnd);
real mpfr_get_ld(ref const mpfr_t op, mpfr_rnd_t rnd);
// _Decimal64 mpfr_get_decimal64 (ref const mpfr_t op, mpfr_rnd_t rnd);
c_long mpfr_get_si(ref const mpfr_t op, mpfr_rnd_t rnd);
c_ulong mpfr_get_ui(ref const mpfr_t op, mpfr_rnd_t rnd);
intmax_t mpfr_get_sj(ref const mpfr_t op, mpfr_rnd_t rnd);
uintmax_t mpfr_get_uj(ref const mpfr_t op, mpfr_rnd_t rnd);
double mpfr_get_d_2exp(c_long* exp, ref const mpfr_t op, mpfr_rnd_t rnd);
real mpfr_get_ld_2exp(c_long* exp, ref const mpfr_t op, mpfr_rnd_t rnd);
int mpfr_frexp(mpfr_exp_t* exp, ref mpfr_t y, ref mpfr_t x, mpfr_rnd_t rnd);
mpfr_exp_t mpfr_get_z_2exp(mpz_t rop, ref const mpfr_t op);
int mpfr_get_z(mpz_t rop, ref const mpfr_t op, mpfr_rnd_t rnd);
int mpfr_get_f(mpf_t rop, ref const mpfr_t op, mpfr_rnd_t rnd);
char* mpfr_get_str(char* str, mpfr_exp_t* expptr, int b, size_t n, ref const mpfr_t op,
        mpfr_rnd_t rnd);
void mpfr_free_str(char* str);
int mpfr_fits_uc_long_p(ref const mpfr_t op, mpfr_rnd_t rnd);
int mpfr_fits_sc_long_p(ref const mpfr_t op, mpfr_rnd_t rnd);
int mpfr_fits_uint_p(ref const mpfr_t op, mpfr_rnd_t rnd);
int mpfr_fits_sint_p(ref const mpfr_t op, mpfr_rnd_t rnd);
int mpfr_fits_ushort_p(ref const mpfr_t op, mpfr_rnd_t rnd);
int mpfr_fits_sshort_p(ref const mpfr_t op, mpfr_rnd_t rnd);
int mpfr_fits_uintmax_p(ref const mpfr_t op, mpfr_rnd_t rnd);
int mpfr_fits_intmax_p(ref const mpfr_t op, mpfr_rnd_t rnd);

// Basic Arithmetic Functions

int mpfr_add(ref mpfr_t rop, ref const mpfr_t op1, ref const mpfr_t op2, mpfr_rnd_t rnd);
int mpfr_add_ui(ref mpfr_t rop, ref const mpfr_t op1, c_ulong op2, mpfr_rnd_t rnd);
int mpfr_add_si(ref mpfr_t rop, ref const mpfr_t op1, c_long op2, mpfr_rnd_t rnd);
int mpfr_add_d(ref mpfr_t rop, ref const mpfr_t op1, double op2, mpfr_rnd_t rnd);
int mpfr_add_z(ref mpfr_t rop, ref const mpfr_t op1, mpz_t op2, mpfr_rnd_t rnd);
int mpfr_add_q(ref mpfr_t rop, ref const mpfr_t op1, mpq_t op2, mpfr_rnd_t rnd);
int mpfr_sub(ref mpfr_t rop, ref const mpfr_t op1, ref const mpfr_t op2, mpfr_rnd_t rnd);
int mpfr_ui_sub(ref mpfr_t rop, c_ulong op1, ref const mpfr_t op2, mpfr_rnd_t rnd);
int mpfr_sub_ui(ref mpfr_t rop, ref const mpfr_t op1, c_ulong op2, mpfr_rnd_t rnd);
int mpfr_si_sub(ref mpfr_t rop, c_long op1, ref const mpfr_t op2, mpfr_rnd_t rnd);
int mpfr_sub_si(ref mpfr_t rop, ref const mpfr_t op1, c_long op2, mpfr_rnd_t rnd);
int mpfr_d_sub(ref mpfr_t rop, double op1, ref const mpfr_t op2, mpfr_rnd_t rnd);
int mpfr_sub_d(ref mpfr_t rop, ref const mpfr_t op1, double op2, mpfr_rnd_t rnd);
int mpfr_z_sub(ref mpfr_t rop, mpz_t op1, ref const mpfr_t op2, mpfr_rnd_t rnd);
int mpfr_sub_z(ref mpfr_t rop, ref const mpfr_t op1, mpz_t op2, mpfr_rnd_t rnd);
int mpfr_sub_q(ref mpfr_t rop, ref const mpfr_t op1, mpq_t op2, mpfr_rnd_t rnd);
int mpfr_mul(ref mpfr_t rop, ref const mpfr_t op1, ref const mpfr_t op2, mpfr_rnd_t rnd);
int mpfr_mul_ui(ref mpfr_t rop, ref const mpfr_t op1, c_ulong op2, mpfr_rnd_t rnd);
int mpfr_mul_si(ref mpfr_t rop, ref const mpfr_t op1, c_long op2, mpfr_rnd_t rnd);
int mpfr_mul_d(ref mpfr_t rop, ref const mpfr_t op1, double op2, mpfr_rnd_t rnd);
int mpfr_mul_z(ref mpfr_t rop, ref const mpfr_t op1, mpz_t op2, mpfr_rnd_t rnd);
int mpfr_mul_q(ref mpfr_t rop, ref const mpfr_t op1, mpq_t op2, mpfr_rnd_t rnd);
int mpfr_sqr(ref mpfr_t rop, ref const mpfr_t op, mpfr_rnd_t rnd);
int mpfr_div(ref mpfr_t rop, ref const mpfr_t op1, ref const mpfr_t op2, mpfr_rnd_t rnd);
int mpfr_ui_div(ref mpfr_t rop, c_ulong op1, ref const mpfr_t op2, mpfr_rnd_t rnd);
int mpfr_div_ui(ref mpfr_t rop, ref const mpfr_t op1, c_ulong op2, mpfr_rnd_t rnd);
int mpfr_si_div(ref mpfr_t rop, c_long op1, ref const mpfr_t op2, mpfr_rnd_t rnd);
int mpfr_div_si(ref mpfr_t rop, ref const mpfr_t op1, c_long op2, mpfr_rnd_t rnd);
int mpfr_d_div(ref mpfr_t rop, double op1, ref const mpfr_t op2, mpfr_rnd_t rnd);
int mpfr_div_d(ref mpfr_t rop, ref const mpfr_t op1, double op2, mpfr_rnd_t rnd);
int mpfr_div_z(ref mpfr_t rop, ref const mpfr_t op1, mpz_t op2, mpfr_rnd_t rnd);
int mpfr_div_q(ref mpfr_t rop, ref const mpfr_t op1, mpq_t op2, mpfr_rnd_t rnd);
int mpfr_sqrt(ref mpfr_t rop, ref const mpfr_t op, mpfr_rnd_t rnd);
int mpfr_sqrt_ui(ref mpfr_t rop, c_ulong op, mpfr_rnd_t rnd);
int mpfr_rec_sqrt(ref mpfr_t rop, ref const mpfr_t op, mpfr_rnd_t rnd);
int mpfr_cbrt(ref mpfr_t rop, ref const mpfr_t op, mpfr_rnd_t rnd);
int mpfr_root(ref mpfr_t rop, ref const mpfr_t op, c_ulong k, mpfr_rnd_t rnd);
int mpfr_pow(ref mpfr_t rop, ref const mpfr_t op1, ref const mpfr_t op2, mpfr_rnd_t rnd);
int mpfr_pow_ui(ref mpfr_t rop, ref const mpfr_t op1, c_ulong op2, mpfr_rnd_t rnd);
int mpfr_pow_si(ref mpfr_t rop, ref const mpfr_t op1, c_long op2, mpfr_rnd_t rnd);
int mpfr_pow_z(ref mpfr_t rop, ref const mpfr_t op1, mpz_t op2, mpfr_rnd_t rnd);
int mpfr_ui_pow_ui(ref mpfr_t rop, c_ulong op1, c_ulong op2, mpfr_rnd_t rnd);
int mpfr_ui_pow(ref mpfr_t rop, c_ulong op1, ref const mpfr_t op2, mpfr_rnd_t rnd);
int mpfr_neg(ref mpfr_t rop, ref const mpfr_t op, mpfr_rnd_t rnd);
int mpfr_abs(ref mpfr_t rop, ref const mpfr_t op, mpfr_rnd_t rnd);
int mpfr_dim(ref mpfr_t rop, ref const mpfr_t op1, ref const mpfr_t op2, mpfr_rnd_t rnd);
int mpfr_mul_2ui(ref mpfr_t rop, ref const mpfr_t op1, c_ulong op2, mpfr_rnd_t rnd);
int mpfr_mul_2si(ref mpfr_t rop, ref const mpfr_t op1, c_long op2, mpfr_rnd_t rnd);
int mpfr_div_2ui(ref mpfr_t rop, ref const mpfr_t op1, c_ulong op2, mpfr_rnd_t rnd);
int mpfr_div_2si(ref mpfr_t rop, ref const mpfr_t op1, c_long op2, mpfr_rnd_t rnd);

// Comparison Functions

int mpfr_cmp(ref const mpfr_t op1, ref const mpfr_t op2);
int mpfr_cmp_ui(ref const mpfr_t op1, c_ulong op2);
int mpfr_cmp_si(ref const mpfr_t op1, c_long op2);
int mpfr_cmp_d(ref const mpfr_t op1, double op2);
int mpfr_cmp_ld(ref const mpfr_t op1, real op2);
int mpfr_cmp_z(ref const mpfr_t op1, mpz_t op2);
int mpfr_cmp_q(ref const mpfr_t op1, mpq_t op2);
int mpfr_cmp_f(ref const mpfr_t op1, mpf_t op2);
int mpfr_cmp_ui_2exp(ref const mpfr_t op1, c_ulong op2, mpfr_exp_t e);
int mpfr_cmp_si_2exp(ref const mpfr_t op1, c_long op2, mpfr_exp_t e);
int mpfr_cmpabs(ref const mpfr_t op1, ref const mpfr_t op2);
int mpfr_nan_p(ref const mpfr_t op);
int mpfr_inf_p(ref const mpfr_t op);
int mpfr_number_p(ref const mpfr_t op);
int mpfr_zero_p(ref const mpfr_t op);
int mpfr_regular_p(ref const mpfr_t op);
int mpfr_greater_p(ref const mpfr_t op1, ref const mpfr_t op2);
int mpfr_greaterequal_p(ref const mpfr_t op1, ref const mpfr_t op2);
int mpfr_less_p(ref const mpfr_t op1, ref const mpfr_t op2);
int mpfr_lessequal_p(ref const mpfr_t op1, ref const mpfr_t op2);
int mpfr_equal_p(ref const mpfr_t op1, ref const mpfr_t op2);
int mpfr_lessgreater_p(ref const mpfr_t op1, ref const mpfr_t op2);
int mpfr_unordered_p(ref const mpfr_t op1, ref const mpfr_t op2);

// Special Functions

int mpfr_log(ref mpfr_t rop, ref const mpfr_t op, mpfr_rnd_t rnd);
int mpfr_log2(ref mpfr_t rop, ref const mpfr_t op, mpfr_rnd_t rnd);
int mpfr_log10(ref mpfr_t rop, ref const mpfr_t op, mpfr_rnd_t rnd);
int mpfr_exp(ref mpfr_t rop, ref const mpfr_t op, mpfr_rnd_t rnd);
int mpfr_exp2(ref mpfr_t rop, ref const mpfr_t op, mpfr_rnd_t rnd);
int mpfr_exp10(ref mpfr_t rop, ref const mpfr_t op, mpfr_rnd_t rnd);
int mpfr_cos(ref mpfr_t rop, ref const mpfr_t op, mpfr_rnd_t rnd);
int mpfr_sin(ref mpfr_t rop, ref const mpfr_t op, mpfr_rnd_t rnd);
int mpfr_tan(ref mpfr_t rop, ref const mpfr_t op, mpfr_rnd_t rnd);
int mpfr_sin_cos(ref mpfr_t sop, ref mpfr_t cop, ref const mpfr_t op, mpfr_rnd_t rnd);
int mpfr_sec(ref mpfr_t rop, ref const mpfr_t op, mpfr_rnd_t rnd);
int mpfr_csc(ref mpfr_t rop, ref const mpfr_t op, mpfr_rnd_t rnd);
int mpfr_cot(ref mpfr_t rop, ref const mpfr_t op, mpfr_rnd_t rnd);
int mpfr_acos(ref mpfr_t rop, ref const mpfr_t op, mpfr_rnd_t rnd);
int mpfr_asin(ref mpfr_t rop, ref const mpfr_t op, mpfr_rnd_t rnd);
int mpfr_atan(ref mpfr_t rop, ref const mpfr_t op, mpfr_rnd_t rnd);
int mpfr_atan2(ref mpfr_t rop, ref mpfr_t y, ref mpfr_t x, mpfr_rnd_t rnd);
int mpfr_cosh(ref mpfr_t rop, ref const mpfr_t op, mpfr_rnd_t rnd);
int mpfr_sinh(ref mpfr_t rop, ref const mpfr_t op, mpfr_rnd_t rnd);
int mpfr_tanh(ref mpfr_t rop, ref const mpfr_t op, mpfr_rnd_t rnd);
int mpfr_sinh_cosh(ref mpfr_t sop, ref mpfr_t cop, ref const mpfr_t op, mpfr_rnd_t rnd);
int mpfr_sech(ref mpfr_t rop, ref const mpfr_t op, mpfr_rnd_t rnd);
int mpfr_csch(ref mpfr_t rop, ref const mpfr_t op, mpfr_rnd_t rnd);
int mpfr_coth(ref mpfr_t rop, ref const mpfr_t op, mpfr_rnd_t rnd);
int mpfr_acosh(ref mpfr_t rop, ref const mpfr_t op, mpfr_rnd_t rnd);
int mpfr_asinh(ref mpfr_t rop, ref const mpfr_t op, mpfr_rnd_t rnd);
int mpfr_atanh(ref mpfr_t rop, ref const mpfr_t op, mpfr_rnd_t rnd);
int mpfr_fac_ui(ref mpfr_t rop, c_ulong op, mpfr_rnd_t rnd);
int mpfr_log1p(ref mpfr_t rop, ref const mpfr_t op, mpfr_rnd_t rnd);
int mpfr_expm1(ref mpfr_t rop, ref const mpfr_t op, mpfr_rnd_t rnd);
int mpfr_eint(ref mpfr_t rop, ref const mpfr_t op, mpfr_rnd_t rnd);
int mpfr_li2(ref mpfr_t rop, ref const mpfr_t op, mpfr_rnd_t rnd);
int mpfr_gamma(ref mpfr_t rop, ref const mpfr_t op, mpfr_rnd_t rnd);
int mpfr_lngamma(ref mpfr_t rop, ref const mpfr_t op, mpfr_rnd_t rnd);
int mpfr_lgamma(ref mpfr_t rop, int* signp, ref const mpfr_t op, mpfr_rnd_t rnd);
int mpfr_digamma(ref mpfr_t rop, ref const mpfr_t op, mpfr_rnd_t rnd);
int mpfr_zeta(ref mpfr_t rop, ref const mpfr_t op, mpfr_rnd_t rnd);
int mpfr_zeta_ui(ref mpfr_t rop, c_ulong op, mpfr_rnd_t rnd);
int mpfr_erf(ref mpfr_t rop, ref const mpfr_t op, mpfr_rnd_t rnd);
int mpfr_erfc(ref mpfr_t rop, ref const mpfr_t op, mpfr_rnd_t rnd);
int mpfr_j0(ref mpfr_t rop, ref const mpfr_t op, mpfr_rnd_t rnd);
int mpfr_j1(ref mpfr_t rop, ref const mpfr_t op, mpfr_rnd_t rnd);
int mpfr_jn(ref mpfr_t rop, c_long n, ref const mpfr_t op, mpfr_rnd_t rnd);
int mpfr_y0(ref mpfr_t rop, ref const mpfr_t op, mpfr_rnd_t rnd);
int mpfr_y1(ref mpfr_t rop, ref const mpfr_t op, mpfr_rnd_t rnd);
int mpfr_yn(ref mpfr_t rop, c_long n, ref const mpfr_t op, mpfr_rnd_t rnd);
int mpfr_fma(ref mpfr_t rop, ref const mpfr_t op1, ref const mpfr_t op2,
        ref const mpfr_t op3, mpfr_rnd_t rnd);
int mpfr_fms(ref mpfr_t rop, ref const mpfr_t op1, ref const mpfr_t op2,
        ref const mpfr_t op3, mpfr_rnd_t rnd);
int mpfr_agm(ref mpfr_t rop, ref const mpfr_t op1, ref const mpfr_t op2, mpfr_rnd_t rnd);
int mpfr_hypot(ref mpfr_t rop, ref mpfr_t x, ref mpfr_t y, mpfr_rnd_t rnd);
int mpfr_ai(ref mpfr_t rop, ref mpfr_t x, mpfr_rnd_t rnd);
int mpfr_const_log2(ref mpfr_t rop, mpfr_rnd_t rnd);
int mpfr_const_pi(ref mpfr_t rop, mpfr_rnd_t rnd);
int mpfr_const_euler(ref mpfr_t rop, mpfr_rnd_t rnd);
int mpfr_const_catalan(ref mpfr_t rop, mpfr_rnd_t rnd);
void mpfr_free_cache();
int mpfr_sum(ref mpfr_t rop, const mpfr_ptr tab, c_long n, mpfr_rnd_t rnd);

// Input and Output Functions

size_t __gmpfr_out_str(FILE* stream, int base, size_t n, ref const mpfr_t op, mpfr_rnd_t rnd);
alias mpfr_out_str = __gmpfr_out_str;

size_t __gmpfr_inp_str(ref mpfr_t rop, FILE* stream, int base, mpfr_rnd_t rnd);
alias mpfr_inp_str = __gmpfr_inp_str;

// Functions

int mpfr_fprintf(FILE* stream, const(char)* tmpl, ...);
int mpfr_vfprintf(FILE* stream, const(char)* tmpl, va_list ap);
int mpfr_printf(const(char)* tmpl, ...);
int mpfr_vprintf(const(char)* tmpl, va_list ap);
int mpfr_sprintf(char* buf, const(char)* tmpl, ...);
int mpfr_vsprintf(char* buf, const(char)* tmpl, va_list ap);
int mpfr_snprintf(char* buf, size_t n, const(char)* tmpl, ...);
int mpfr_vsnprintf(char* buf, size_t n, const(char)* tmpl, va_list ap);
int mpfr_asprintf(char** str, const(char)* tmpl, ...);
int mpfr_vasprintf(char** str, const(char)* tmpl, va_list ap);

// Integer and Remainder Related Functions

int mpfr_rint(ref mpfr_t rop, ref const mpfr_t op, mpfr_rnd_t rnd);
int mpfr_ceil(ref mpfr_t rop, ref const mpfr_t op);
int mpfr_floor(ref mpfr_t rop, ref const mpfr_t op);
int mpfr_round(ref mpfr_t rop, ref const mpfr_t op);
int mpfr_trunc(ref mpfr_t rop, ref const mpfr_t op);
int mpfr_rint_ceil(ref mpfr_t rop, ref const mpfr_t op, mpfr_rnd_t rnd);
int mpfr_rint_floor(ref mpfr_t rop, ref const mpfr_t op, mpfr_rnd_t rnd);
int mpfr_rint_round(ref mpfr_t rop, ref const mpfr_t op, mpfr_rnd_t rnd);
int mpfr_rint_trunc(ref mpfr_t rop, ref const mpfr_t op, mpfr_rnd_t rnd);
int mpfr_frac(ref mpfr_t rop, ref const mpfr_t op, mpfr_rnd_t rnd);
int mpfr_modf(ref mpfr_t iop, ref mpfr_t fop, ref const mpfr_t op, mpfr_rnd_t rnd);
int mpfr_fmod(ref mpfr_t r, ref mpfr_t x, ref mpfr_t y, mpfr_rnd_t rnd);
int mpfr_remainder(ref mpfr_t r, ref mpfr_t x, ref mpfr_t y, mpfr_rnd_t rnd);
int mpfr_remquo(ref mpfr_t r, c_long* q, ref mpfr_t x, ref mpfr_t y, mpfr_rnd_t rnd);
int mpfr_integer_p(ref const mpfr_t op);

// Rounding Related Functions

void mpfr_set_default_rounding_mode(mpfr_rnd_t rnd);
mpfr_rnd_t mpfr_get_default_rounding_mode();
int mpfr_prec_round(ref mpfr_t x, mpfr_prec_t prec, mpfr_rnd_t rnd);
int mpfr_can_round(ref mpfr_t b, mpfr_exp_t err, mpfr_rnd_t rnd1, mpfr_rnd_t rnd2, mpfr_prec_t prec);
mpfr_prec_t mpfr_min_prec(ref mpfr_t x);
const(char)* mpfr_print_rnd_mode(mpfr_rnd_t rnd);

// Miscellaneous Functions

void mpfr_nexttoward(ref mpfr_t x, ref mpfr_t y);
void mpfr_nextabove(ref mpfr_t x);
void mpfr_nextbelow(ref mpfr_t x);
int mpfr_min(ref mpfr_t rop, ref const mpfr_t op1, ref const mpfr_t op2, mpfr_rnd_t rnd);
int mpfr_max(ref mpfr_t rop, ref const mpfr_t op1, ref const mpfr_t op2, mpfr_rnd_t rnd);
// int mpfr_urandomb (ref mpfr_t rop, gmp_randstate_t state);
// int mpfr_urandom (ref mpfr_t rop, gmp_randstate_t state, mpfr_rnd_t rnd);
// int mpfr_grandom (ref mpfr_t rop1, ref mpfr_t rop2, gmp_randstate_t state, mpfr_rnd_t rnd);
mpfr_exp_t mpfr_get_exp(ref mpfr_t x);
int mpfr_set_exp(ref mpfr_t x, mpfr_exp_t e);
int mpfr_signbit(ref const mpfr_t op);
int mpfr_setsign(ref mpfr_t rop, ref const mpfr_t op, int s, mpfr_rnd_t rnd);
int mpfr_copysign(ref mpfr_t rop, ref const mpfr_t op1, ref const mpfr_t op2, mpfr_rnd_t rnd);
const(char)* mpfr_get_version();
const(char)* mpfr_get_patches();
int mpfr_buildopt_tls_p();
int mpfr_buildopt_decimal_p();
int mpfr_buildopt_gmpinternals_p();
const(char)* mpfr_buildopt_tune_case();

// Exception Related Functions

mpfr_exp_t mpfr_get_emin();
mpfr_exp_t mpfr_get_emax();
int mpfr_set_emin(mpfr_exp_t exp);
int mpfr_set_emax(mpfr_exp_t exp);
mpfr_exp_t mpfr_get_emin_min();
mpfr_exp_t mpfr_get_emin_max();
mpfr_exp_t mpfr_get_emax_min();
mpfr_exp_t mpfr_get_emax_max();
int mpfr_check_range(ref mpfr_t x, int t, mpfr_rnd_t rnd);
int mpfr_subnormalize(ref mpfr_t x, int t, mpfr_rnd_t rnd);
void mpfr_clear_underflow();
void mpfr_clear_overflow();
void mpfr_clear_divby0();
void mpfr_clear_nanflag();
void mpfr_clear_inexflag();
void mpfr_clear_erangeflag();
void mpfr_set_underflow();
void mpfr_set_overflow();
void mpfr_set_divby0();
void mpfr_set_nanflag();
void mpfr_set_inexflag();
void mpfr_set_erangeflag();
void mpfr_clear_flags();
int mpfr_underflow_p();
int mpfr_overflow_p();
int mpfr_divby0_p();
int mpfr_nanflag_p();
int mpfr_inexflag_p();
int mpfr_erangeflag_p();

// Compatibility With MPF

void mpfr_set_prec_raw(ref mpfr_t x, mpfr_prec_t prec);
int mpfr_eq(ref const mpfr_t op1, ref const mpfr_t op2, c_ulong op3);
void mpfr_reldiff(ref mpfr_t rop, ref const mpfr_t op1, ref const mpfr_t op2, mpfr_rnd_t rnd);
int mpfr_mul_2exp(ref mpfr_t rop, ref const mpfr_t op1, c_ulong op2, mpfr_rnd_t rnd);
int mpfr_div_2exp(ref mpfr_t rop, ref const mpfr_t op1, c_ulong op2, mpfr_rnd_t rnd);

// Custom Interface

size_t mpfr_custom_get_size(mpfr_prec_t prec);
void mpfr_custom_init(void* significand, mpfr_prec_t prec);
void mpfr_custom_init_set(ref mpfr_t x, int kind, mpfr_exp_t exp,
        mpfr_prec_t prec, void* significand);
int mpfr_custom_get_kind(ref mpfr_t x);
void* mpfr_custom_get_significand(ref mpfr_t x);
mpfr_exp_t mpfr_custom_get_exp(ref mpfr_t x);
void mpfr_custom_move(ref mpfr_t x, void* new_position);
