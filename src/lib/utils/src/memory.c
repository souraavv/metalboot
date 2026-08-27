#include "memory.h"

void far* memcpy(void far* dst, const void far* src, uint16_t num) {
    uint8_t far* u8Dst = (uint8_t far *)dst;

    const uint8_t far* u8Src = (const uint8_t far *) src; 

    for (uint16_t i = 0; i < num; ++i) {
        u8Dst[i] = u8Src[i];
    }

    return dst;
}

void far* memset(void far* ptr, int value, uint16_t num) {
    uint8_t far* u8ptr = (uint8_t far* )ptr;

    for (uint16_t i = 0; i < num; ++i) {
        u8ptr[i] = (uint8_t) value;
    }
    return ptr; 
}


int memcmp(const void far* ptr1, const void far* ptr2, uint16_t num) {

    uint8_t far* u8ptr1 = (uint8_t far*) ptr1; 
    uint8_t far* u8ptr2 = (uint8_t far*) ptr2; 

    for (uint16_t i = 0; i < num; ++i) {
        if (u8ptr1[i] != u8ptr2[i]) {
            return u8ptr1[i] - u8ptr2[i];
        }
    }
    return 0;
}
