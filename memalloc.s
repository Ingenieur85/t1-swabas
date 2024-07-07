# Por Fabiano A. de Sá Filho
# Software Básico - UFPR 1-2024

# Declarações globais aqui, para que o main.c tenha acesso
# Variáveis
.global original_brk
.global heap_end

# Funções
.global setup_brk
.global dismiss_brk
.global memory_alloc
.global memory_free
.global find_worst_fit_block
.global split_block

# SEÇÂO .DATA
.section .data
original_brk:
        .quad 0

heap_end:
        .quad 0

# SEÇÃO .TEXT
.section .text

setup_brk:
        pushq   %rbp
        movq    %rsp, %rbp
        movl    $0, %edi
        call    sbrk
        movq    %rax, original_brk(%rip)
        movq    original_brk(%rip), %rax
        movq    %rax, heap_end(%rip)
        popq    %rbp
        ret

dismiss_brk:
        pushq   %rbp
        movq    %rsp, %rbp
        movq    original_brk(%rip), %rax
        movq    %rax, %rdi
        call    brk
        movq    original_brk(%rip), %rax
        movq    %rax, heap_end(%rip)
        popq    %rbp
        ret

memory_alloc:
        pushq   %rbp
        movq    %rsp, %rbp
        subq    $32, %rsp
        movq    %rdi, -24(%rbp)
        movq    heap_end(%rip), %rax
        testq   %rax, %rax
        jne     .L4
        movl    $0, %edi
        call    sbrk
        movq    %rax, heap_end(%rip)
.L4:
        movq    -24(%rbp), %rax
        movq    %rax, %rdi
        call    find_worst_fit_block
        movq    %rax, -8(%rbp)
        cmpq    $0, -8(%rbp)
        je      .L5
        movq    -8(%rbp), %rax
        movb    $1, (%rax)
        movq    -8(%rbp), %rax
        movq    8(%rax), %rax
        movq    -24(%rbp), %rdx
        addq    $16, %rdx
        cmpq    %rax, %rdx
        jnb     .L6
        movq    -24(%rbp), %rdx
        movq    -8(%rbp), %rax
        movq    %rdx, %rsi
        movq    %rax, %rdi
        call    split_block
.L6:
        movq    -8(%rbp), %rax
        addq    $16, %rax
        jmp     .L7
.L5:
        movq    -24(%rbp), %rax
        addq    $16, %rax
        movq    %rax, %rdi
        call    sbrk
        movq    %rax, -16(%rbp)
        cmpq    $-1, -16(%rbp)
        jne     .L8
        movl    $0, %eax
        jmp     .L7
.L8:
        movq    heap_end(%rip), %rax
        movq    %rax, -8(%rbp)
        movq    -8(%rbp), %rax
        movb    $1, (%rax)
        movq    -8(%rbp), %rax
        movq    -24(%rbp), %rdx
        movq    %rdx, 8(%rax)
        movq    heap_end(%rip), %rax
        movq    -24(%rbp), %rdx
        addq    $16, %rdx
        addq    %rdx, %rax
        movq    %rax, heap_end(%rip)
        movq    -8(%rbp), %rax
        addq    $16, %rax
.L7:
        leave
        ret

memory_free:
        pushq   %rbp
        movq    %rsp, %rbp
        movq    %rdi, -24(%rbp)
        cmpq    $0, -24(%rbp)
        jne     .L10
        movl    $-1, %eax
        jmp     .L11
.L10:
        movq    original_brk(%rip), %rax
        cmpq    %rax, -24(%rbp)
        jb      .L12
        movq    heap_end(%rip), %rax
        cmpq    %rax, -24(%rbp)
        jb      .L13
.L12:
        movl    $-1, %eax
        jmp     .L11
.L13:
        movq    -24(%rbp), %rax
        subq    $16, %rax
        movq    %rax, -8(%rbp)
        movq    -8(%rbp), %rax
        movb    $0, (%rax)
        movl    $0, %eax
.L11:
        popq    %rbp
        ret

find_worst_fit_block:
        pushq   %rbp
        movq    %rsp, %rbp
        movq    %rdi, -24(%rbp)
        movq    $0, -8(%rbp)
        movq    original_brk(%rip), %rax
        movq    %rax, -16(%rbp)
        jmp     .L15
.L18:
        movq    -16(%rbp), %rax
        movzbl  (%rax), %eax
        testb   %al, %al
        jne     .L16
        movq    -16(%rbp), %rax
        movq    8(%rax), %rax
        cmpq    -24(%rbp), %rax
        jb      .L16
        cmpq    $0, -8(%rbp)
        je      .L17
        movq    -16(%rbp), %rax
        movq    8(%rax), %rax
        movq    -8(%rbp), %rdx
        movq    8(%rdx), %rdx
        cmpq    %rax, %rdx
        jnb     .L16
.L17:
        movq    -16(%rbp), %rax
        movq    %rax, -8(%rbp)
.L16:
        movq    -16(%rbp), %rax
        movq    8(%rax), %rax
        addq    $16, %rax
        addq    %rax, -16(%rbp)
.L15:
        movq    heap_end(%rip), %rax
        cmpq    %rax, -16(%rbp)
        jb      .L18
        movq    -8(%rbp), %rax
        popq    %rbp
        ret


split_block:
        pushq   %rbp
        movq    %rsp, %rbp
        movq    %rdi, -24(%rbp)
        movq    %rsi, -32(%rbp)
        movq    -32(%rbp), %rax
        leaq    16(%rax), %rdx
        movq    -24(%rbp), %rax
        addq    %rdx, %rax
        movq    %rax, -8(%rbp)
        movq    -8(%rbp), %rax
        movb    $0, (%rax)
        movq    -24(%rbp), %rax
        movq    8(%rax), %rax
        subq    -32(%rbp), %rax
        leaq    -16(%rax), %rdx
        movq    -8(%rbp), %rax
        movq    %rdx, 8(%rax)
        movq    -24(%rbp), %rax
        movq    -32(%rbp), %rdx
        movq    %rdx, 8(%rax)
        popq    %rbp
        ret
