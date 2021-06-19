// https://gist.github.com/s-macke/6dd78c78be46214d418454abb667a1ba

typedef unsigned short uint16_t;
typedef unsigned int uint32_t;

typedef long size_t;
typedef uint16_t __wasi_errno_t;
typedef uint32_t __wasi_fd_t;

typedef struct __wasi_ciovec_t {
    const void *buf;
    size_t buf_len;
} __wasi_ciovec_t;

#define __WASI_SYSCALL_NAME(name) \
    __attribute__((__import_module__("wasi_unstable"), __import_name__(#name)))

__wasi_errno_t __wasi_fd_write(
    __wasi_fd_t fd,
    const __wasi_ciovec_t *iovs,
    size_t iovs_len,
    size_t *nwritten
) __WASI_SYSCALL_NAME(fd_write) __attribute__((__warn_unused_result__));

int putchar(int code)
{
    const __wasi_fd_t stdout = 1;
    size_t nwritten;
    __wasi_errno_t error;
    __wasi_ciovec_t iovec;
    
    char chr = (char) code;
    
    iovec.buf = &chr;
    iovec.buf_len = 1;
    error = __wasi_fd_write(stdout, &iovec, 1, &nwritten);
    return 0;
}
