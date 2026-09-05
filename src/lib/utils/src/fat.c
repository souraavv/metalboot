#include "ctype.h"
#include "fat.h"
#include "math.h"
#include "memory.h"
#include "memdefs.h"
#include "stdio.h"
#include "stdint.h"
#include "string.h"

// Private helpers
static bool validateFatContext(FatContext* context); 
static bool readBootSector(FatContext* context);
static bool calculateVolumeGeometry(const BootSector* bpb, 
        VolumeGeometry* geometry);
static bool readSector(FatContext* context, uint32_t lba, uint32_t count, 
        void* buffer);
static bool readFat(FatContext* context);
static uint32_t nextCluster(FatContext* context, uint32_t currentCluster);
static uint32_t clusterToLba(FatContext* context, uint32_t clusterNumber);
static DirectoryEntry far* findFile(FatContext* context, const char* name);
static void formatFatName(const char* input, char* output);
static bool validateBootSectorPostRead(BootSector* bootSector);
static int32_t findFreeFileHandle(FatContext* context);
static bool findFileInDirectory(FatContext* context, FatFile* directory,
        const char* name11, DirectoryEntry* outEntry);

// --- Validation ---
bool validateFatContext(FatContext* context) {
    return context != NULL && context->disk != NULL;
}

/**
 * 
 * From the bootsector read the info like - bytePerSector, sectors per fat
 * 
 */
bool calculateVolumeGeometry(const BootSector* bpb, VolumeGeometry* geoOut) {
    uint32_t rootDirBytes;

    if (bpb == NULL || geoOut == NULL) {
        return false;
    }

    // FAT starts immediately after the reserved sector
    geoOut->fatLba = bpb->reservedSectors;

    // One fat occupies = sectors per FAT * bytes in each sector
    geoOut->fatSizeBytes = bpb->sectorsPerFat * bpb->bytesPerSector;
    
    // root directory starts after all FAT copies
    geoOut->rootDirLba = geoOut->fatLba + (bpb->fatCount * bpb->sectorsPerFat);
    
    // Each directory entry is 32 bytes
    rootDirBytes = (uint32_t) bpb->dirEntryCount * sizeof(DirectoryEntry);
    
    // Convert directory bytes into complete sectors
    geoOut->rootDirSectors = divCeil(rootDirBytes, bpb->bytesPerSector);
    
    // Data region begins immediately after the root directory
    geoOut->dataRegionLba = geoOut->rootDirLba + geoOut->rootDirSectors;
    return true;
}

/**
 * Basic validtion of boot sector, post reading into the RAM
 * 
 */
bool validateBootSectorPostRead(BootSector* bootSector) {
    return bootSector->bytesPerSector != 0
        && bootSector->sectorsPerCluster != 0
        && bootSector->reservedSectors != 0
        && bootSector->fatCount != 0
        && bootSector->sectorsPerFat != 0;
}


void formatFatName(const char* input, char* output) {
    int i = 0; // Index for the input string
    int j = 0; // Index for the 11-byte FAT output

    // Fill the output buffer with 11 spaces by default
    memset(output, ' ', 11);

    while (input[i] != '\0' && j < 11) {
        if (input[i] == '.') {
            // A dot means we skip straight to the extension segment
            j = 8; 
        } else {
            // Copy the character and force it to uppercase
            output[j] = toupper((unsigned char)input[i]);
            j++;
        }
        i++;
    }
}

/**
 * Boot sector represents the BPB and extended boot fields
 * 
 * It is not the entire 512-byte boot sector
 * 
 * First read the sector into to a temporary buffer and then we will parse
 * the fields out of that.
 */
bool readBootSector(FatContext* context) {
    uint8_t bootSectorBytes[SECTOR_SIZE];

    if (!validateFatContext(context)) {
        return false;
    }

    // Step 1. Read the boot sector i.e., sector number = 0
    if (!readDiskSectors(context->disk, 0, 1, (uint8_t far*)bootSectorBytes)) {
        printf("Failed to read the boot sector bytes into the RAM\r\n");
        return false;
    }

    // Step 2. Copy the BPB and EBR portion
    memcpy(&context->bootSector, bootSectorBytes, sizeof(BootSector));

    // Step 3. Validate boot sector 
    if (!validateBootSectorPostRead(&context->bootSector)) {
        printf("Corrupted bootsector record. Exiting...\r\n");
        return false;
    }

    printf("bytesPerSector: %u\r\n", context->bootSector.bytesPerSector);
    printf("sectorsPerCluster: %u\r\n", context->bootSector.sectorsPerCluster);
    printf("reservedSectors: %u\r\n", context->bootSector.reservedSectors);
    printf("fatCount: %u\r\n", context->bootSector.fatCount);
    printf("dirEntryCount: %u\r\n", context->bootSector.dirEntryCount);
    printf("sectorsPerFat: %u\r\n", context->bootSector.sectorsPerFat);
    return true;
}

bool readFat(FatContext* context) {
    uint32_t fatSize;

    if (!validateFatContext(context)) {
        return false;
    }

    fatSize = context->geometry.fatSizeBytes;

    if (fatSize == 0) {
        return false;
    }

    context->fat = (uint8_t far*) MEMORY_FAT_ADDR;

    if (fatSize > MEMORY_FAT_SIZE) {
        printf("FAT is too large\r\n");
        context->fat = NULL;
        return false;
    }

    // Read FAT #1
    if (!readDiskSectors(context->disk, 
            context->geometry.fatLba,
            context->bootSector.sectorsPerFat,
            (uint8_t far*)context->fat)) {
        return false;
    }
    return true;
}

/**
 * Root directory is stored immediately after the FAT
 */
bool readRootDirectory(FatContext* context) {
    uint32_t rootDirectorySizeInBytes;
    uint32_t rootDirectoryOffset;

    if (!validateFatContext(context)) {
        return false;
    }

    // Step 1. Validate if root directory fits in the defined range
    rootDirectorySizeInBytes =
            context->bootSector.bytesPerSector 
                * context->geometry.rootDirSectors;

    // Relate to the FAT base address (or from the fat base)
    rootDirectoryOffset = context->geometry.fatSizeBytes;

    if (rootDirectoryOffset + rootDirectorySizeInBytes > MEMORY_FAT_SIZE) {
        printf("FAT root directory is too big\r\n");
        return false;
    }

    context->rootDirectory = (DirectoryEntry far*) (context->fat +  
            rootDirectoryOffset);
    
    // Step 2. Read the root directory
    if (!readDiskSectors(context->disk, 
            context->geometry.rootDirLba,
            (uint8_t) context->geometry.rootDirSectors,
            (uint8_t far*) context->rootDirectory)) {
        printf("Failed to read the root directory sector\r\n");
        context->rootDirectory = NULL;
        return false;
    }
    return true;
}

/**
 * Geometry knows the base LBA of data region.
 * The data region starts with cluster# 2
 * 
 * Each cluster constitute of a given number of sectors (BPB)
 * 
 */
static uint32_t clusterToLba(FatContext* context, uint32_t clusterNumber) {
    if (!validateFatContext(context) || clusterNumber < 2) {
        printf("Invalid cluster number of corrupted FAT context in memory\r\n");
        return 0;
    }

    return context->geometry.dataRegionLba + 
            ((clusterNumber - 2) * context->bootSector.sectorsPerCluster);
}

/**
 * This is FAT 12
 * Each entry in the root directory is 12 bits wides
 * Each entry contains details for a given cluster
 * 
 * to get the metadata of a given cluster - first we need to locate that cluster
 * i.e., FAT index of that cluster
 * 
 * So index in the FAT table = cluster number * 1.5
 * From that index we have to now read 2 bytes (as this span)
 * 
 */
static uint32_t nextCluster(FatContext* context, uint32_t currentCluster) {
    uint32_t fatIndex;
    uint16_t entry;

    if (!validateFatContext(context) || currentCluster < 2) {
        printf("Invalid cluster number of corrupted FAT context in memory\r\n");
        return 0x0FFF;
    }
    
    // Step 1. Get the FAT index of the current cluster
    fatIndex = currentCluster * 3 / 2;

    // Step 2. Validate as we need to read two bytes
    if (fatIndex + 1 >= context->geometry.fatSizeBytes) {
        return 0x0FFF;
    }

    // Read 2 bytes (16 bits) - Little Endian System
    entry = context->fat[fatIndex] 
            | ((uint16_t) context->fat[fatIndex + 1] << 8);
    
    return isEven(currentCluster) ? (entry & 0x0FFF) : (entry >> 4);
}

/**
 * Scan a directory for a matching 11-byte FAT name.
 *
 * A directory - whether it's the root or a subfolder - is just a stream
 * of 32-byte records.
 *
 * directory - an already-open FatFile representing the folder to search
 * name11    - fixed 11-byte FAT name, output of formatFatName
 * outEntry  - filled with a copy of the entry on success
 *
 * Returns false once the directory is exhausted with no match.
 */
static bool findFileInDirectory(FatContext* context, FatFile* directory,
        const char* name11, DirectoryEntry* outEntry) {
    DirectoryEntry entry;
    uint32_t bytesRead;
    uint8_t firstByte;

    if (!validateFatContext(context) || directory == NULL
            || name11 == NULL || outEntry == NULL) {
        return false;
    }

    while ((bytesRead = read(context, directory, sizeof(DirectoryEntry),
            (uint8_t far*) &entry)) == sizeof(DirectoryEntry)) {

        firstByte = entry.name[0];

        // No more active entries beyond this point
        if (firstByte == 0x00) {
            printf("End of active entries in directory\r\n");
            break;
        }

        // Deleted entry
        if (firstByte == 0xE5) {
            continue;
        }

        if (entry.attributes == FAT_ATTRIBUTE_LFN) {
            continue;
        }

        if (entry.attributes & FAT_ATTRIBUTE_VOLUME_ID) {
            continue;
        }

        /*
         * FAT filenames are strictly 11-byte fixed-width fields
         * padded with spaces. They are not null terminated C strings.
         * memcmp bounds the read strictly to 11 bytes.
         */
        if (memcmp(name11, entry.name, 11) == 0) {
            printf("Found the match .....\r\n");
            *outEntry = entry;
            return true;
        }
    }

    return false;
}

bool fatInitialize(FatContext* context) {
    uint8_t i;

    if (!validateFatContext(context)) {
        printf("Correputed fat context\r\n");
        return false;
    }

    // Step 1. Read the boot sector
    printf("Reading boot sector...\r\n");
    if (!readBootSector(context)) {
        printf("Failed to read boot sector\r\n");
        return false;
    }
    printf("done\r\n");

    // Step 2. Load volume geo into memory
    printf("Loading Volume geometry into memory...\r\n");
    if (!calculateVolumeGeometry(&context->bootSector, &context->geometry)) {
        printf("Failed to read the volue geomtery into memory\r\n");
        return false;
    }
    printf("done\r\n");


    // Step 3. Read FAT12 Table
    printf("Reading FAT12 table into the memory...\r\n");
    if (!readFat(context)) {
        printf("Failed to read the FAT\r\n");
        return false;
    }
    printf("done\r\n");

    // Step 4. Read root directory
    printf("Reading root directory...\r\n");
    if (!readRootDirectory(context)) {
        printf("Failed to read the root directory\r\n");
        return false;
    }
    printf("done\r\n");

    // Step 5. INit the root directory

    // Step 5.1 Init it with all 0's
    memset(&context->rootDirectoryFile, 0, sizeof(FatFileData));

    // Public fields
    context->rootDirectoryFile.public.handle = ROOT_DIRECTORY_HANDLE;
    context->rootDirectoryFile.public.isDirectory = true; 
    context->rootDirectoryFile.public.position = 0;
    context->rootDirectoryFile.public.size =
            (uint32_t)context->bootSector.dirEntryCount 
                    * sizeof(DirectoryEntry);
    // Info
    context->rootDirectoryFile.info.firstCluster = 0;
    context->rootDirectoryFile.info.isDirectory = true;
    context->rootDirectoryFile.info.size =
            context->rootDirectoryFile.public.size;

    // Iterator
    context->rootDirectoryFile.cursor.currentCluster =
            context->geometry.rootDirLba;
    context->rootDirectoryFile.cursor.currentSectorInCluster = 0;

    // Read first directory sector in to cache
    if (context->geometry.rootDirSectors > 0) {
        if (!readDiskSectors(context->disk, 
                context->geometry.rootDirLba, 
                1, 
                (uint8_t far*) context->rootDirectoryFile.cursor.buffer)) {
            printf("root directory read failed\r\n");
            return false;
        }
    }
    context->rootDirectoryFile.opened = true;
    
    // Step 6. Reset the File handlers
    for (i = 0; i < MAX_FILE_HANDLES; ++i) {
        context->openedFiles[i].opened = false;
    }
    return true;
}

int32_t findFreeFileHandle(FatContext* context) {
    int32_t handle = -1;
    uint8_t i;

    for (i = 0; i < MAX_FILE_HANDLES; ++i) {
        if (!context->openedFiles[i].opened) {
            handle = i;
            break;
        }
    }
    return handle;
}

FatFile* open(FatContext* context, const char* path) {
    char nameBuffer[12];
    char fatFileName[12];
    DirectoryEntry entry;
    int32_t freeFileHandle;
    FatFileData* fileData;
    uint32_t lbaOfFirstCluster;
    FatFile* currentDir;
    int i;
    bool isLastToken;

    if (!validateFatContext(context) || path == NULL) {
        printf("Corrupted context of invalid file name\r\n");
        return NULL;
    }

    currentDir = &context->rootDirectoryFile.public;

    while (*path != '\0') {
        i = 0;
        while (*path != '\0' && *path != '/' && i < 11) {
            nameBuffer[i++] = *path;
            path++;
        }
        nameBuffer[i] = '\0';
        
        if (*path == '/') {
            path++;
            isLastToken = false;
        } else {
            isLastToken = true;
        }

        // Step 1. Sanitize file name
        formatFatName(nameBuffer, fatFileName);
        fatFileName[11] = '\0'; 

        // Rewind the directory cursor before searching
        if (currentDir->handle == ROOT_DIRECTORY_HANDLE) {
            fileData = &context->rootDirectoryFile;
            fileData->cursor.position = 0;
            fileData->cursor.currentCluster = context->geometry.rootDirLba;
            fileData->cursor.currentSectorInCluster = 0;
            readDiskSectors(context->disk, context->geometry.rootDirLba, 1, 
                    (uint8_t far*)fileData->cursor.buffer);
        } else {
            fileData = &context->openedFiles[currentDir->handle];
            fileData->cursor.position = 0;
            fileData->cursor.currentCluster = fileData->info.firstCluster;
            fileData->cursor.currentSectorInCluster = 0;
            lbaOfFirstCluster = clusterToLba(context, 
                    fileData->info.firstCluster);
            readDiskSectors(context->disk, lbaOfFirstCluster, 1, 
                    (uint8_t far*)fileData->cursor.buffer);
        }

        // Step 2. Locate the file in the directory
        if (!findFileInDirectory(context, currentDir, fatFileName, &entry)) {
            printf("Failed to get the directory for file %s\r\n", fatFileName);
            return NULL;
        }

        // Step 3. Find a free file handler
        freeFileHandle = findFreeFileHandle(context);
        if (freeFileHandle < 0) {
            printf("No free file handler available\r\n");
            return NULL;
        }

        fileData = &context->openedFiles[freeFileHandle];

        // Reset
        memset(fileData, 0, sizeof(FatFileData));

        // Public info
        fileData->public.handle = freeFileHandle;
        fileData->public.isDirectory = 
                (entry.attributes & FAT_ATTRIBUTE_DIRECTORY) != 0;
        fileData->public.position = 0;
        fileData->public.size = entry.size;

        // Stable file info
        fileData->info.firstCluster = entry.firstClusterLow 
                | ((uint32_t) entry.firstClusterHigh << 16);
        fileData->info.size = entry.size;
        fileData->info.isDirectory = fileData->public.isDirectory;

        // Cursor
        fileData->cursor.position = 0;
        fileData->cursor.currentCluster = fileData->info.firstCluster;
        fileData->cursor.currentSectorInCluster = 0;

        // Empty file
        if (fileData->info.size > 0 || fileData->public.isDirectory) {
            if (fileData->info.firstCluster >= 2) {
                // Read first sector
                lbaOfFirstCluster = clusterToLba(context, 
                        fileData->cursor.currentCluster);
                if (!readDiskSectors(context->disk, lbaOfFirstCluster, 
                        1, (uint8_t far*) fileData->cursor.buffer)) {
                    printf("first sector read failed for file %s\r\n", 
                            fatFileName);
                    return NULL;
                }
            }
        }

        fileData->opened = true;
        currentDir = &fileData->public;

        if (isLastToken) {
            return currentDir;
        } else if (!currentDir->isDirectory) {
            printf("Invalid path: %s is not a directory\r\n", fatFileName);
            return NULL;
        }
    }

    return NULL;
}

// Byte Array:  [ Byte 0 ] [ Byte 1 ] [ Byte 2 ] | [ Byte 3 ] [ Byte 4 ] 
//              |________| |____|____| |________| | |________| |____|____| 
// Bits:          8 bits    4b    4b     8 bits  |    8 bits    4b    4b     
//              |________|__|__| |__|___________| | |________|__|__| |__|
//              |                |                | |                |   
// Clusters:    [  Cluster 0   ] [  Cluster 1   ] | [  Cluster 2   ] [  Cluster3

/**
 * 
 * A File is stored as chain of clusters
 * DirectoryEntry gives you the first cluster
 * 
 * Internally we maintain - currentCluster, currentSectorInCluster, buffer
 *  and position (logical byte position in file)
 * 
 * 
 */
uint32_t read(FatContext* context, FatFile* file, uint32_t bytesCount, 
        uint8_t far* output) {
    uint32_t fileHandle;
    FatFileData* fileData; 
    uint32_t remaining;
    uint32_t bytesRead = 0;
    uint32_t offsetInSector;
    uint32_t left;
    uint32_t bytesToCopy;
    uint32_t nextClus;
    uint32_t lba;
    bool isRootDirectory;

    // Step 1. Validate
    if (!validateFatContext(context) || file == NULL || bytesCount == 0
            || output == NULL) {
        return 0;
    }

    // Step 2. Find runtime details of this file
    fileHandle = file->handle;
    isRootDirectory = (fileHandle == ROOT_DIRECTORY_HANDLE);

    if (isRootDirectory) {
        fileData = &context->rootDirectoryFile;
    } else {
        if (fileHandle >= MAX_FILE_HANDLES) {
            printf("Invalid file handle\r\n");
            return 0;
        }
        fileData = &context->openedFiles[fileHandle];
    }

    if (!fileData->opened) {
        printf("File is not opened\r\n");
        return 0;
    }

    // Enforce size limits only for standard files, subdirectories bypass this
    if (!fileData->info.isDirectory) {
        if (fileData->cursor.position >= fileData->info.size) {
            return 0;
        }
        remaining = fileData->info.size - fileData->cursor.position;
        bytesCount = min(bytesCount, remaining);
    }

    while (bytesCount > 0) {
        uint8_t far* srcPtr;
        uint8_t far* dstPtr;
        // Find byte offset inside the current sector
        offsetInSector = fileData->cursor.position 
                % context->bootSector.bytesPerSector;
        
        // How much left ? 
        left = context->bootSector.bytesPerSector - offsetInSector;

        // How much to copy 
        bytesToCopy = min(left, bytesCount);

        srcPtr = (uint8_t far*)fileData->cursor.buffer;
        srcPtr += offsetInSector;
        
        dstPtr = output;
        dstPtr += bytesRead;
        // read the thing in the output buffer
        memcpy(dstPtr, srcPtr, (uint16_t)bytesToCopy);
        
        bytesRead += bytesToCopy;
        fileData->cursor.position += bytesToCopy;
        bytesCount -= bytesToCopy;

        // Did we finish the current sector ?
        // Are we still in the same sector ??
        if (bytesToCopy < left) {
            continue;
        }

        if (isRootDirectory) {
            uint32_t rootDirEndLba;

            rootDirEndLba = context->geometry.rootDirLba
                    + context->geometry.rootDirSectors;

            fileData->cursor.currentCluster++;

            if (fileData->cursor.currentCluster >= rootDirEndLba) {
                break;
            }

            if (!readDiskSectors(context->disk, fileData->cursor.currentCluster,
                    1, (uint8_t far*) fileData->cursor.buffer)) {
                printf("Failed to read next root directory sector\r\n");
                return bytesRead;
            }
            continue;
        }

        // Current sector done
        fileData->cursor.currentSectorInCluster++;

        // Is there any other sector in this cluster ?
        if (fileData->cursor.currentSectorInCluster 
                < context->bootSector.sectorsPerCluster) {
            
            lba = clusterToLba(context, fileData->cursor.currentCluster)
                    + fileData->cursor.currentSectorInCluster;
            
            if (!readDiskSectors(context->disk, lba, 
                    1, (uint8_t far*) fileData->cursor.buffer)) {
                printf("Failed to read next file sector\r\n");
                return bytesRead; 
            }
            continue;
        }

        // Cluster is done; move to the next 
        fileData->cursor.currentSectorInCluster = 0;
        nextClus = nextCluster(context, fileData->cursor.currentCluster);

        // Check if it is end of chain 
        if (nextClus >= 0xFF8) {
            break;
        }

        fileData->cursor.currentCluster = nextClus; 
        
        // read sector 0 
        lba = clusterToLba(context, fileData->cursor.currentCluster);

        if (!readDiskSectors(context->disk, lba, 1, 
                    (uint8_t far*)fileData->cursor.buffer)) {
            printf("Failed to read next cluster\r\n");
            return bytesRead;
        }
    }
    return bytesRead;
}
 
void close(FatContext* context, FatFile* file) {
    if (context == NULL || file == NULL) {
        return;
    }
    
    if (file->handle == ROOT_DIRECTORY_HANDLE) {
        context->rootDirectoryFile.opened = false;
        return;
    }
    
    if (file->handle < MAX_FILE_HANDLES) {
        context->openedFiles[file->handle].opened = false;
    }
}

void destroy(FatContext* context) {
    if (context == NULL) {
        return;
    }
    memset(context, 0, sizeof(FatContext));
}