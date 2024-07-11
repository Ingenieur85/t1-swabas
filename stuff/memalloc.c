#include <unistd.h>
#include <stdint.h>
#include <stddef.h>

void *original_brk;  // Variable declared by the program using the API

// Block structure
typedef struct {
    uint8_t used;           // 0 = free, 1 = used
    uint64_t size;          // size of the block in bytes
} BlockHeader;

// Function prototypes
void setup_brk();
void dismiss_brk();
void* memory_alloc(unsigned long int bytes);
int memory_free(void *pointer);

// Static variable for the end of the heap
static void* heap_end = NULL;

// Helper functions
BlockHeader* find_worst_fit_block(unsigned long int bytes);
void split_block(BlockHeader* block, unsigned long int bytes);

void setup_brk() {
    original_brk = sbrk(0);
    heap_end = original_brk;
}

void dismiss_brk() {
    brk(original_brk);
    heap_end = original_brk;
}

void* memory_alloc(unsigned long int bytes) {
    // Initialize heap_end if it hasn't been done yet
    if (!heap_end) {
        heap_end = sbrk(0);
    }

    BlockHeader* block = find_worst_fit_block(bytes);

    if (block) {
        block->used = 1;
        if (block->size > bytes + sizeof(BlockHeader)) {
            split_block(block, bytes);
        }
        return (void*)(block + 1);
    } else {
        // Allocate new block at the end of the heap
        void* new_end = sbrk(sizeof(BlockHeader) + bytes);
        if (new_end == (void*)-1) {
            return NULL; // Not enough memory
        }

        block = (BlockHeader*)heap_end;
        block->used = 1;
        block->size = bytes;

        heap_end = (uint8_t*)heap_end + sizeof(BlockHeader) + bytes;

        return (void*)(block + 1);
    }
}

int memory_free(void *pointer) {
    if (!pointer) {
        return -1; // Invalid pointer
    }

    // Check if the pointer is within the heap range
    if ((uint8_t*)pointer < (uint8_t*)original_brk || (uint8_t*)pointer >= (uint8_t*)heap_end) {
        return -1; // Pointer not in heap
    }

    BlockHeader* block = (BlockHeader*)pointer - 1;
    block->used = 0;
    return 0;
}

BlockHeader* find_worst_fit_block(unsigned long int bytes) {
    BlockHeader* worst_fit = NULL;
    BlockHeader* current = (BlockHeader*)original_brk;

    while ((uint8_t*)current < (uint8_t*)heap_end) {
        if (!current->used && current->size >= bytes) {
            if (!worst_fit || current->size > worst_fit->size) {
                worst_fit = current;
            }
        }
        current = (BlockHeader*)((uint8_t*)current + sizeof(BlockHeader) + current->size);
    }

    return worst_fit;
}

void split_block(BlockHeader* block, unsigned long int bytes) {
    BlockHeader* new_block = (BlockHeader*)((uint8_t*)block + sizeof(BlockHeader) + bytes);
    new_block->used = 0;
    new_block->size = block->size - bytes - sizeof(BlockHeader);
    block->size = bytes;
}

