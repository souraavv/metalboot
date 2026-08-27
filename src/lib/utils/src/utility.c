#include "utility.h"

uint32_t align(uint32_t number, uint32_t alignTo)
{
    if (alignTo == 0) {
        return number;
    }
    // Pure bitwise math: No division, no __U4D dependency.
    // Note: alignTo MUST be a power of 2 (e.g., 512, 4096)
    return (number + alignTo - 1) & ~(alignTo - 1);
}
