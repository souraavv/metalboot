#include "stdint.h"
#include "stdio.h"
#include "disk.h"
#include "fat.h"

FatContext fatContext; 
Disk disk;

void _cdecl cstart_(uint16_t bootDrive) {
    FatFile* fd;
    FatFile* rootDir;
    DirectoryEntry entry;
    uint32_t readBytes;
    uint8_t far buffer[100];
    uint32_t i;
    char nameBuf[12];

    printf("Boot Drive: %x\r\n", bootDrive);
    
    if (!initDisk(&disk, (uint8_t)bootDrive)) {
        printf("ERROR: Disk init failed\r\n");
        goto end;
    }

    fatContext.disk = &disk;
    if (!fatInitialize(&fatContext)) {
        printf("ERROR: FAT init failed\r\n");
        goto end;
    }

    printf("\r\n--- ROOT DIR LISTING ---\r\n");
    rootDir = &fatContext.rootDirectoryFile.public;
    
    while (read(&fatContext, rootDir, sizeof(DirectoryEntry), 
            (uint8_t far*)&entry) == sizeof(DirectoryEntry)) {
        
        if (entry.name[0] == 0x00) break; 
        if (entry.name[0] == 0xE5 || entry.attributes == FAT_ATTRIBUTE_LFN 
                || (entry.attributes & FAT_ATTRIBUTE_VOLUME_ID)) {
            continue;
        }

        for (i = 0; i < 11; i++) nameBuf[i] = entry.name[i];
        nameBuf[11] = '\0';

        printf(" [%s] %s | %lu bytes\r\n", 
            (entry.attributes & FAT_ATTRIBUTE_DIRECTORY) ? "DIR " : "FILE",
            nameBuf, entry.size);
    }
    printf("------------------------\r\n");

    printf("\r\n--- DOCS DIR LISTING ---\r\n");
    fd = open(&fatContext, "docs");
    if (fd == NULL) {
        printf("ERROR: Could not find 'docs' dir\r\n");
    } else {
        while (read(&fatContext, fd, sizeof(DirectoryEntry), 
                (uint8_t far*)&entry) == sizeof(DirectoryEntry)) {
            
            if (entry.name[0] == 0x00) break; 
            if (entry.name[0] == 0xE5 || entry.attributes == FAT_ATTRIBUTE_LFN 
                    || (entry.attributes & FAT_ATTRIBUTE_VOLUME_ID)) {
                continue;
            }

            for (i = 0; i < 11; i++) nameBuf[i] = entry.name[i];
            nameBuf[11] = '\0';

            printf(" [%s] %s | %lu bytes\r\n", 
                (entry.attributes & FAT_ATTRIBUTE_DIRECTORY) ? "DIR " : "FILE",
                nameBuf, entry.size);
        }
        close(&fatContext, fd);
    }
    printf("------------------------\r\n");

    printf("\r\nOpening 'docs/nested/deep.txt'...\r\n");
    fd = open(&fatContext, "docs/nested/deep.txt");
    
    if (fd == NULL) {
        printf("ERROR: Could not find deep.txt\r\n");
    } else {
        while ((readBytes = read(&fatContext, fd, sizeof(buffer), 
                buffer)) > 0) {
            for (i = 0; i < readBytes; i++) {
                putc(buffer[i]);
            }
        }
        printf("\r\n------------------------\r\n");
        close(&fatContext, fd);
    }

    destroy(&fatContext);

end:
    for (;;);
}