[bits 32]

; boot-time page table, throw away later

; page need alignment
align 4096
PML4:
times 512 dq 0

align 4096
PDPT:
times 512 dq 0

align 4096
PD:
times 512 dq 0

align 4096
