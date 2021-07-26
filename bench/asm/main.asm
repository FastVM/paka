
    mov r0, 0
    jmp [redo]

[redo]:

    add r0, r0, 1
    println r0
    jmp [redo]
    