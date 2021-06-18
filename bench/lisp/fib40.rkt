#lang racket

(define (fib n)
    (if (< n 2)
        n
        (+ (fib (- n 1)) (fib (- n 2)))))

(display (fib 40))
(newline)