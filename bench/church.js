let U = f => f(f);
let I = x => x;
let TRUE = x => y => x;
let FALSE = x => y => y;
let IF = b => t => f => b(t)(f);
let num = n => n(x => x + 1)(0);
let SUCC = n => f => z => f(n(f)(z));
let ZERO = f => z => z;
let nat = n => {
    let ret = ZERO;
    while (n > 0) {
        --n;
        ret = SUCC(ret);
    }
    return ret;
}
let PRED = n => f => x => n(g => h => h(g(f)))(u => x)(u => u);
let ONE = SUCC(ZERO);
let TWO = SUCC(ONE);
let ADD = n => m => f => z => n(f)(m(f)(z));
let MUL = n => m => f => z => n(m(f))(z);
let ISZERO = n => n(u => FALSE)(TRUE);
let CFACT = a =>
    U(s => n =>
        IF(ISZERO(n))
            (u => ONE)
            (u => MUL(n)(s(s)(PRED(n))(I))))
        (a)(I);

console.log(num(CFACT(nat(8))));