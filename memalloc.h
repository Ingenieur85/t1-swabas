#ifndef MEMALLOC_H
#define MEMALLOC_H

void setup_brk();
void dismiss_brk();
void* memory_alloc(unsigned long int bytes);
int memory_free(void *pointer);

#endif /* MEMALLOC_H */