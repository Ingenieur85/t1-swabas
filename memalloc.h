#ifndef MEMALLOC_H
#define MEMALLOC_H

#include <stdint.h>
#include <unistd.h>

// Block structure
typedef struct {
    uint8_t used;           // 0 = free, 1 = used
    uint64_t size;          // size of the block in bytes
} BlockHeader;


void setup_brk();
void dismiss_brk();
void* memory_alloc(unsigned long int bytes);
int memory_free(void *pointer);
BlockHeader* find_worst_fit_block(unsigned long int bytes);
void split_block(BlockHeader* block, unsigned long int bytes);

#endif /* MEMALLOC_H */