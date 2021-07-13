li    t1, 0x00234500 
    mtc0  t1, c0_entrylo0
    li    t2, 0x00789a00 
    mtc0  t2, c0_entrylo1
    li    v0 , 0
    li    v1 , 13
    li    t0, 0xbfc00010 
mtc0  t0, c0_entryhi
    mtc0  v0, c0_index
    tlbwi
    li   t3, 0xffffffff
    mtc0 t3, c0_entryhi
    mtc0 t3, c0_entrylo0
    mtc0 t3, c0_entrylo1
    tlbr
    mfc0 a0, c0_entryhi
    mfc0 a1, c0_entrylo0
    mfc0 a2, c0_entrylo1
    nop
    bne a0, t0, inst_error
    nop
    bne a1, t1, inst_error
    nop
    bne a2, t2, inst_error
    nop
    addiu v0, v0, 1
    addiu t0, t0, 1<<13
    bne  v0, v1, 1b
    nop