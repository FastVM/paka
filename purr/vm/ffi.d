module pur.vm.ffi;

enum ffi_type: double {
    void_ = 0,
    bool_,
    char_,
    schar,
    uchar,
    int8,
    uint8,
    int16,
    uint16,
    int32,
    uint32,
    int64,
    float32,
    float64,
    uint64,
    string_,
}

enum double[string] ffi_data = [
    "FFI_TYPE_VOID": ffi_type.void_,
    "FFI_TYPE_BOOL": ffi_type.bool_,
    "FFI_TYPE_CHAR": ffi_type.char_,
    "FFI_TYPE_SCHAR": ffi_type.schar,
    "FFI_TYPE_UCHAR": ffi_type.uchar,
    "FFI_TYPE_INT8": ffi_type.int8,
    "FFI_TYPE_UINT8": ffi_type.uint8,
    "FFI_TYPE_INT16": ffi_type.int16,
    "FFI_TYPE_UINT16": ffi_type.uint16,
    "FFI_TYPE_INT32": ffi_type.int32,
    "FFI_TYPE_UINT32": ffi_type.uint32,
    "FFI_TYPE_INT64": ffi_type.int64,
    "FFI_TYPE_FLOAT32": ffi_type.float32,
    "FFI_TYPE_FLOAT64": ffi_type.float64,
    "FFI_TYPE_UINT64": ffi_type.uint64,
    "FFI_TYPE_STRING": ffi_type.string_,
];
