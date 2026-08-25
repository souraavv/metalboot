#include "stdint.h"
#include "stdio.h"
#include "disk.h"

void _cdecl cstart_(uint16_t bootDrive) {
    Disk disk; 
    uint8_t buffer[512]; // Buffer to hold our read sector

    printf("Boot Drive: %x, OS: %s, Grade: %c\r\n", bootDrive, "Souravsh", 'A');
    
    if (!initDisk(&disk, (uint8_t)bootDrive)) {
        printf("ERROR: Disk initialization failed!\r\n");
        goto end;
    }

    printf("Disk Init Success! CHS: %d Cylinders, %d Heads, %d Sectors\r\n", 
           disk.cylinders, disk.heads, disk.sectors);

    // Read LBA 0 (The Bootloader Sector)
    if (!readDiskSectors(&disk, 0, 1, buffer)) {
        printf("ERROR: Disk read failed!\r\n");
        goto end;
    }

    // Verify the boot signature at the end of the sector
    printf("Read Success! Boot signature: %x %x\r\n", buffer[510], buffer[511]);

end:
    for (;;);
}