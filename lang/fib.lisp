(define (fib n)
    (if (< n 2)
        n
        (+ (rec (- n 1)) (rec (- n 2)))))

(fib 35)
