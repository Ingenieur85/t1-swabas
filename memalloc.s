
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

# SECTION .DATA
.section .data
original_brk:
        .quad 0

heap_end:
        .quad 0

# SECTION .TEXT
.section .text

# Implementações de brk e sbrk, aos moldes da unistd.h
# Input: %rdi = novo brk do programa
# Output: %rax = 0 em sucesso, -1 em caso de erro
custom_brk:
        movq    $12, %rax         # brk syscall (12)
        syscall                   # Perform the syscall
        cmpq    $-1, %rax         # Check return value for failure
        je      .brk_failed       # Jump to error handling if failed
        ret                       # Return if successful
.brk_failed:
        movq    $-1, %rax         # Return -1 if there was an error
        ret


# Input: %rdi = incremento em bytes
# Output: %rax = último brk, ou -1 se erro
custom_sbrk:
    movq    %rdi, %rdx        # Move incremento em %rdx
    movq    $12, %rax         # brk syscall (12)
    movq    $0, %rdi          # Inicialmente, brk é setado para 0 para obter o endereço atual do heap
    syscall                   
    cmpq    $-1, %rax         # Checa retorno do syscall
    je      .sbrk_failed      
    addq    %rdx, %rax        # Soma incremento ao endereço atual do heap
    movq    %rax, %rdi        # Coloca novo brk em %rdi
    movq    $12, %rax         # brk syscall (12)
    syscall                   
    cmpq    $-1, %rax         # Checa retorno do syscall
    je      .sbrk_failed      
    subq    %rdx, %rax        # Retorna o último endereço de brk
    ret                       
.sbrk_failed:
    movq    $-1, %rax         # Retorna -1 se deu erro
    ret


setup_brk:
        pushq   %rbp
        movq    %rsp, %rbp
        movl    $0, %edi                        # Chama sbrk(0) para obter o endereço atual de brk
        call    custom_sbrk                     
        movq    %rax, original_brk(%rip)        # Armazena o endereço atual do brk em original_brk
        movq    original_brk(%rip), %rax        # Carrega o valor de original_brk em %rax
        movq    %rax, heap_end(%rip)            # Inicializa heap_end com o endereço atual do break
        popq    %rbp
        ret

dismiss_brk:
        pushq   %rbp
        movq    %rsp, %rbp                      
        movq    original_brk(%rip), %rax        # Carrega o valor de original_brk em %rax
        movq    %rax, %rdi                      # Move original_brk para %rdi, o argumento para custom_brk
        call    custom_brk                      # Chama custom_brk(original_brk) para restaurar valor original
        movq    original_brk(%rip), %rax
        movq    %rax, heap_end(%rip)            # Atualiza heap_end com o valor de original_brk
        popq    %rbp
        ret

memory_alloc:
        pushq   %rbp                    # Salva o base pointer na pilha
        movq    %rsp, %rbp              # Define o base pointer atual
        subq    $32, %rsp               # Aloca espaço na pilha para variáveis locais
        movq    %rdi, -24(%rbp)         # Armazena o número de bytes solicitados em uma variável local

        # Inicializa o heap_end se ainda não foi feito
        movq    heap_end(%rip), %rax    # Carrega heap_end em %rax
        testq   %rax, %rax              # Testa se heap_end é zero
        jne     .is_initialized            # Se não for zero, pula para o label inicializado
        movl    $0, %edi                # Prepara argumento para custom_sbrk
        call    custom_sbrk             # Chama custom_sbrk para inicializar heap_end
        movq    %rax, heap_end(%rip)    # Armazena o resultado em heap_end

.is_initialized:
        # Procura o pior bloco que se encaixe
        movq    -24(%rbp), %rax         # Carrega o número de bytes solicitados em %rax
        movq    %rax, %rdi              # Move o número de bytes solicitados para %rdi
        call    find_worst_fit_block    # Chama a função para encontrar o pior bloco que se encaixe
        movq    %rax, -8(%rbp)          # Armazena o bloco encontrado em uma variável local
        cmpq    $0, -8(%rbp)            # Compara o bloco encontrado com zero
        je      .alloc_new_block       # Se não encontrou um bloco, pula para alocar um novo bloco

        # Marca o bloco encontrado como usado
        movq    -8(%rbp), %rax          # Carrega o bloco encontrado em %rax
        movb    $1, (%rax)              # Define o bloco como usado
        movq    -8(%rbp), %rax          # Carrega o bloco encontrado em %rax
        movq    8(%rax), %rax           # Carrega o tamanho do bloco em %rax
        movq    -24(%rbp), %rdx         # Carrega o número de bytes solicitados em %rdx
        addq    $16, %rdx               # Adiciona o tamanho do cabeçalho ao número de bytes solicitados
        cmpq    %rax, %rdx              # Compara o tamanho do bloco com o tamanho solicitado mais o cabeçalho
        jnb     .return_block          # Se o bloco for grande o suficiente, pula para retornar o bloco

        # Divide o bloco se sobrar espaço suficiente
        movq    -24(%rbp), %rdx         # Carrega o número de bytes solicitados em %rdx
        movq    -8(%rbp), %rax          # Carrega o bloco encontrado em %rax
        movq    %rdx, %rsi              # Move o número de bytes solicitados para %rsi
        movq    %rax, %rdi              # Move o bloco encontrado para %rdi
        call    split_block             # Chama a função para dividir o bloco

.return_block:
        movq    -8(%rbp), %rax          # Carrega o bloco encontrado em %rax
        addq    $16, %rax               # Adiciona o tamanho do cabeçalho para retornar o ponteiro de dados
        jmp     .memalloc_end                     # Pula para o fim

.alloc_new_block:
        # Tenta alocar um novo bloco de memória
        movq    -24(%rbp), %rax         # Carrega o número de bytes solicitados em %rax
        addq    $16, %rax               # Adiciona o tamanho do cabeçalho ao número de bytes solicitados
        movq    %rax, %rdi              # Move o tamanho total para %rdi
        call    custom_sbrk                    # Chama sbrk para alocar memória
        movq    %rax, -16(%rbp)         # Armazena o ponteiro do novo bloco em uma variável local
        cmpq    $-1, -16(%rbp)          # Compara o resultado da alocação com -1
        jne     .successful_alloc        # Se a alocação foi bem-sucedida, pula para alocacao_sucesso
        movl    $0, %eax                # Define o valor de retorno como 0 (falha)
        jmp     .memalloc_end                     # Pula para o fim

.successful_alloc:
        # Inicializa o novo bloco alocado
        movq    heap_end(%rip), %rax    # Carrega heap_end em %rax
        movq    %rax, -8(%rbp)          # Armazena heap_end em uma variável local
        movq    -8(%rbp), %rax          # Carrega o ponteiro do novo bloco em %rax
        movb    $1, (%rax)              # Define o novo bloco como usado
        movq    -8(%rbp), %rax          # Carrega o ponteiro do novo bloco em %rax
        movq    -24(%rbp), %rdx         # Carrega o número de bytes solicitados em %rdx
        movq    %rdx, 8(%rax)           # Define o tamanho do novo bloco
        movq    heap_end(%rip), %rax    # Carrega heap_end em %rax
        movq    -24(%rbp), %rdx         # Carrega o número de bytes solicitados em %rdx
        addq    $16, %rdx               # Adiciona o tamanho do cabeçalho ao número de bytes solicitados
        addq    %rdx, %rax              # Atualiza heap_end com o novo fim do heap
        movq    %rax, heap_end(%rip)    # Armazena o novo fim do heap em heap_end
        movq    -8(%rbp), %rax          # Carrega o ponteiro do novo bloco em %rax
        addq    $16, %rax               # Adiciona o tamanho do cabeçalho para retornar o ponteiro de dados

.memalloc_end:
        leave                           # Restaura o stack frame anterior
        ret                             # Retorna da função


memory_free:
        pushq   %rbp                   # Salva o valor atual do base pointer na pilha
        movq    %rsp, %rbp             # Atualiza o base pointer para o valor atual do stack pointer
        movq    %rdi, -24(%rbp)        # Armazena o argumento (ponteiro) em uma variável local

        # Verifica se o ponteiro é NULL
        cmpq    $0, -24(%rbp)          
        jne     .not_null_pointer      # Se não for NULL, pula para .not_null_pointer
        movl    $-1, %eax              # Se for NULL, retorna -1 indicando erro
        jmp     .end_memory_free       # Pula para o final da função

.not_null_pointer:
        # Verifica se o ponteiro está dentro do intervalo válido do heap
        movq    original_brk(%rip), %rax  # Carrega o valor de original_brk em %rax
        cmpq    %rax, -24(%rbp)           # Compara o ponteiro com original_brk
        jb      .invalid_pointer          # Se o ponteiro estiver abaixo de original_brk, é inválido

        movq    heap_end(%rip), %rax      # Carrega o valor de heap_end em %rax
        cmpq    %rax, -24(%rbp)           # Compara o ponteiro com heap_end
        jb      .valid_pointer            # Se o ponteiro estiver abaixo de heap_end, é válido

.invalid_pointer:
        # Se o ponteiro for inválido, retorna -1
        movl    $-1, %eax                 # Retorna -1 indicando erro
        jmp     .end_memory_free          # Pula para o final da função

.valid_pointer:
        # Marca o bloco como livre
        movq    -24(%rbp), %rax           # Carrega o valor do ponteiro em %rax
        subq    $16, %rax                 # Ajusta o ponteiro para o início do cabeçalho do bloco
        movq    %rax, -8(%rbp)            # Armazena o início do cabeçalho em uma variável local
        movq    -8(%rbp), %rax            # Carrega o início do cabeçalho em %rax
        movb    $0, (%rax)                # Marca o bloco como não usado (0)
        movl    $0, %eax                  # Retorna 0 indicando sucesso

.end_memory_free:
        popq    %rbp                      # Restaura o valor original do base pointer
        ret                               # Retorna da função

find_worst_fit_block:
        pushq   %rbp                   # Salva o valor atual do base pointer na pilha
        movq    %rsp, %rbp             # Atualiza o base pointer para o valor atual do stack pointer
        movq    %rdi, -24(%rbp)        # Armazena o argumento (bytes) em uma variável local
        movq    $0, -8(%rbp)           # Inicializa o pior ajuste (worst fit) com NULL
        movq    original_brk(%rip), %rax  # Carrega o valor de original_brk em %rax
        movq    %rax, -16(%rbp)        # Inicializa o ponteiro de bloco atual para o início do heap
        jmp     .check_end_of_heap     # Pula para a verificação do fim do heap

.check_next_block:
        # Verifica se o bloco atual está livre
        movq    -16(%rbp), %rax        # Carrega o ponteiro do bloco atual em %rax
        movzbl  (%rax), %eax           # Carrega o valor de "used" do cabeçalho do bloco
        testb   %al, %al               # Testa se o bloco está usado (1) ou livre (0)
        jne     .next_block            # Se estiver usado, pula para .next_block

        # Verifica se o bloco atual tem tamanho suficiente
        movq    -16(%rbp), %rax        # Carrega o ponteiro do bloco atual em %rax
        movq    8(%rax), %rax          # Carrega o tamanho do bloco atual em %rax
        cmpq    -24(%rbp), %rax        # Compara o tamanho do bloco com os bytes requisitados
        jb      .next_block            # Se o bloco for menor que o requisitado, pula para .next_block

        # Verifica se é o primeiro bloco adequado ou um melhor ajuste (pior ajuste)
        cmpq    $0, -8(%rbp)           # Verifica se já existe um pior ajuste registrado
        je      .update_worst_fit      # Se não houver, atualiza para o bloco atual

        # Compara o tamanho do bloco atual com o tamanho do pior ajuste atual
        movq    -16(%rbp), %rax        # Carrega o ponteiro do bloco atual em %rax
        movq    8(%rax), %rax          # Carrega o tamanho do bloco atual em %rax
        movq    -8(%rbp), %rdx         # Carrega o ponteiro do pior ajuste atual em %rdx
        movq    8(%rdx), %rdx          # Carrega o tamanho do pior ajuste atual em %rdx
        cmpq    %rax, %rdx             # Compara os tamanhos dos blocos
        jnb     .next_block            # Se o bloco atual não for maior, pula para .next_block

.update_worst_fit:
        movq    -16(%rbp), %rax        # Carrega o ponteiro do bloco atual em %rax
        movq    %rax, -8(%rbp)         # Atualiza o pior ajuste com o bloco atual

.next_block:
        # Move para o próximo bloco no heap
        movq    -16(%rbp), %rax        # Carrega o ponteiro do bloco atual em %rax
        movq    8(%rax), %rax          # Carrega o tamanho do bloco atual em %rax
        addq    $16, %rax              # Adiciona o tamanho do cabeçalho do bloco
        addq    %rax, -16(%rbp)        # Atualiza o ponteiro do bloco atual para o próximo bloco

.check_end_of_heap:
        movq    heap_end(%rip), %rax   # Carrega o valor de heap_end em %rax
        cmpq    %rax, -16(%rbp)        # Compara o ponteiro do bloco atual com o fim do heap
        jb      .check_next_block      # Se não chegou ao fim do heap, verifica o próximo bloco

        # Retorna o ponteiro do pior ajuste encontrado
        movq    -8(%rbp), %rax         # Carrega o pior ajuste em %rax
        popq    %rbp                   # Restaura o valor original do base pointer
        ret                            # Retorna da função

split_block:
        pushq   %rbp                   # Salva o valor atual do base pointer na pilha
        movq    %rsp, %rbp             # Atualiza o base pointer para o valor atual do stack pointer
        movq    %rdi, -24(%rbp)        # Armazena o ponteiro do bloco a ser dividido em uma variável local
        movq    %rsi, -32(%rbp)        # Armazena o tamanho do novo bloco em uma variável local

        movq    -32(%rbp), %rax        # Carrega o tamanho do novo bloco em %rax
        leaq    16(%rax), %rdx         # Adiciona o tamanho do cabeçalho (16 bytes) ao tamanho do novo bloco e armazena em %rdx
        movq    -24(%rbp), %rax        # Carrega o ponteiro do bloco a ser dividido em %rax
        addq    %rdx, %rax             # Move o ponteiro do bloco a ser dividido para a posição do novo bloco
        movq    %rax, -8(%rbp)         # Armazena o ponteiro do novo bloco em uma variável local

        movq    -8(%rbp), %rax         # Carrega o ponteiro do novo bloco em %rax
        movb    $0, (%rax)             # Define o campo "used" do novo bloco como 0 (livre)

        movq    -24(%rbp), %rax        # Carrega o ponteiro do bloco original em %rax
        movq    8(%rax), %rax          # Carrega o tamanho do bloco original em %rax
        subq    -32(%rbp), %rax        # Subtrai o tamanho do novo bloco do tamanho do bloco original
        leaq    -16(%rax), %rdx        # Ajusta o tamanho restante do bloco original subtraindo o tamanho do cabeçalho (16 bytes)
        movq    -8(%rbp), %rax         # Carrega o ponteiro do novo bloco em %rax
        movq    %rdx, 8(%rax)          # Define o tamanho do novo bloco com o valor calculado em %rdx

        movq    -24(%rbp), %rax        # Carrega o ponteiro do bloco original em %rax
        movq    -32(%rbp), %rdx        # Carrega o tamanho do novo bloco em %rdx
        movq    %rdx, 8(%rax)          # Define o tamanho do bloco original com o tamanho do novo bloco

        popq    %rbp                   # Restaura o valor original do base pointer
        ret                            # Retorna da função

