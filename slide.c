#include <unistd.h>

void *brk_original;

int main() {
    brk_original = sbrk(0);
    return 0;
}
