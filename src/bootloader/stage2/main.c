#include "stdint.h"
#include "stdio.h"

void _cdecl cstart_(uint16_t bootDrive) {
    printf("Boot Drive: %x, OS: %s, Grade: %c\r\n", bootDrive, "NanoByte", 'A');
    
    for (;;);
}