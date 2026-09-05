#include "stdint.h"
#include "stdio.h"
#include "disk.h"
#include "fat.h"

void _cdecl cstart_(uint16_t bootDrive) {
    FatFile* fd;
    FatContext fatContext; 
    Disk disk;
    uint32_t readBytes;
    uint8_t far buffer[100];
    uint32_t i;

    printf("Boot Drive: %x, OS: Souravsh\r\n", bootDrive);
    
    // init disk 
    if (!initDisk(&disk, (uint8_t)bootDrive)) {
        printf("ERROR: Disk initialization failed!\r\n");
        goto end;
    }

    // 1. init
    printf("Mounting FAT12...\r\n");
    fatContext.disk = &disk;
    if (!fatInitialize(&fatContext)) {
        printf("ERROR: FAT initialization failed!\r\n");
        goto end;
    }

    // 2. open the file
    printf("Opening 'test.txt'...\r\n");
    fd = open(&fatContext, "test.txt");
    if (fd == NULL) {
        printf("ERROR: Could not find 'test.txt' on disk!\r\n");
        goto end;
    }

    printf("File opened! Size: %lu bytes\r\n", fd->size);
    printf("--- FILE CONTENTS ---\r\n");

    // 3. read the file in chunks
    while ((readBytes = read(&fatContext, fd, sizeof(buffer),
            buffer)) > 0) {

        for (i = 0; i < readBytes; i++) {
            putc(buffer[i]);
        }
    }

    printf("\r\n--- END OF FILE ---\r\n");

    // 4. cleanup
    close(&fatContext, fd);
    destroy(&fatContext);

end:
    for (;;);
}