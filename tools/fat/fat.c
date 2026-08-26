#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

typedef uint8_t bool; 
#define true 1
#define false 0

// Refer to this - https://wiki.osdev.org/FAT
// FAT 12 or FAT 16


typedef struct {
    // --------------------------
    // BPB (Bios Parameter Block)
    // --------------------------
    uint8_t bootJumpInstruction[3];
    uint8_t oemIdentifier[8];
    uint16_t bytesPerSector;
    uint8_t sectorsPerCluster;
    uint16_t reservedSectors;
    uint8_t fatCount;    // # of FAT's on storage media. Often this is 2
    uint16_t dirEntryCount;
    uint16_t totalSectors;
    uint8_t mediaDescriptorType;
    uint16_t sectorsPerFat;
    uint16_t sectorsPerTrack;
    uint16_t heads;
    uint32_t hiddenSectors;
    uint32_t largeSectorCount;

    // --------------------
    // Extended Boot Record
    // ---------------------
    uint8_t driveNumber;
    uint8_t _reserved;
    uint8_t signature;
    uint32_t volumeId;
    uint8_t volumeLabel[11];
    uint8_t systemId[8];
    uint8_t bootCode[448];
    uint16_t bootPartitionSignature;

} __attribute__((packed)) BootSector;

// Search for the FAT 12/FAT 16 Directory Entry structure
typedef struct {
    uint8_t name[11];
    uint8_t attributes; 
    uint8_t _reserved; 
    uint8_t createdTimeTenths;
    uint16_t createdTime;
    uint16_t createdDate; 
    uint16_t accessedDate; 
    uint16_t firstClusterHigh; 
    uint16_t modifiedTime;
    uint16_t modifiedDate;
    uint16_t firstClusterLow;
    uint32_t size;
} __attribute__((packed)) DirectoryEntry;

typedef struct {
    FILE* disk;
    BootSector bootSector;
    uint8_t* fat;
    DirectoryEntry* rootDirectory;
    uint32_t rootDirectoryEnd;
} FatContext;

typedef struct {
    uint32_t fatLba;
    size_t fatSizeBytes;
    uint32_t rootDirLba;
    uint32_t dataRegionLba;
} VolumeGeometry;


// +----------+-----------+-----------+------------+-----------------+
// | Reserved |   FAT 1   |   FAT 2   |  Root Dir  | Data Region...  |
// +----------+-----------+-----------+------------+-----------------+
// ^          ^                       ^
// LBA 0      LBA 4                   LBA 22
//            (fatLba)                (rootDirLba)

//            |<---- 18 sectors ----->|
//             fatCount * secPerFat 
//             (2 FATs  * 9 sectors)

// FAT1 - master map for your disk's data

/**
 * utils
 */

bool validateFatContext(FatContext* context) {
    return context != NULL && context->disk != NULL;
}

bool calculateVolumeGeometry(const BootSector* bpb, VolumeGeometry* geoOut) {
    if (bpb == NULL || geoOut == NULL) {
        return false;
    }

    if (bpb->bytesPerSector == 0 || bpb->sectorsPerFat == 0) {
        return false;
    }

    geoOut->fatLba = bpb->reservedSectors;
    geoOut->fatSizeBytes = (size_t)bpb->sectorsPerFat * bpb->bytesPerSector;
    
    geoOut->rootDirLba = geoOut->fatLba + (bpb->fatCount * bpb->sectorsPerFat);
    uint32_t rootDirSectors;

    geoOut->dataRegionLba = geoOut->rootDirLba + rootDirSectors;
    return true;
}

bool readBootSector(FatContext* context) {
    if (!validateFatContext(context)) {
        return false;
    }

    // Step 1. Read 1 sector of size BootSector from the disk into the 
    // bootSector
    if (fread(&context->bootSector, sizeof(BootSector), 1, 
            context->disk) != 1) {
        return false;
    }
    // Step 2. validate
    if (context->bootSector.bytesPerSector == 0) {
        return false;
    }
    return true;
}

bool readSectors(FatContext* context, uint32_t lba, 
        uint32_t count, void* bufferOut) {
    if (!(validateFatContext(context)) || bufferOut == NULL) {
        return false;
    }

    // Step 1. Convert the LBA to the byte offset
    // LBA means sector number
    // So we should have the byte offset = which translates to
    // #. of sector * byte in each sector
    uint64_t offset = (uint64_t)lba * context->bootSector.bytesPerSector;

    // Step 2. Seek to the offset
    if (fseek(context->disk, (long)offset, SEEK_SET) != 0) {
        return false;
    }

    // Step 3. Read from the offset a given number of sectors

    // From the offset read the count number of sectors in to the buffer
    // and also you have to tell what is the size of each sector. Read will
    // happen from the disk. Validate the number of byte sector read
    if (fread(bufferOut, context->bootSector.bytesPerSector, 
                count, context->disk) != count) {
        return false;
    }

    return true;
}

bool readFat(FatContext* context) {
    if (!validateFatContext(context)) {
        return false;
    }

    // Step 1. Compute the FAT size
    // First get the sectors per FAT and then bytes in each sector
    size_t fatSize = (size_t)context->bootSector.sectorsPerFat 
            * context->bootSector.bytesPerSector;
    
    if (fatSize == 0) {
        return false;
    }

    // Step 2. To read that allocate the size in bytes
    uint8_t* newFat = (uint8_t*)malloc(fatSize);
    if (newFat == NULL) {
        return false;
    }

    // Step 3. And then read those many sectors into the newFat, starting
    // from the reservedSector (i.e. lba = reservedSector)
    // the read sector consumes the number of sector it can read
    if (!readSectors(context, context->bootSector.reservedSectors, 
                context->bootSector.sectorsPerFat, newFat)) {
        free(newFat);
        return false;
    }

    if (context->fat != NULL) {
        free(context->fat);
    }
    context->fat = newFat;

    return true;
}

bool readRootDirectory(FatContext* context) {
    if (!validateFatContext(context)) {
        return false;
    }

    // Step 1. Get the LBA / sector # of the root directory
    uint32_t lbaOfRootDirectory = context->bootSector.reservedSectors
            + context->bootSector.sectorsPerFat * context->bootSector.fatCount;
    
    // Step 2. Get the size of the total directory entires
    uint32_t size = sizeof(DirectoryEntry) * context->bootSector.dirEntryCount;
    
    // Step 3. Get the total sector that will occuply that much space
    uint32_t sectorsOccupiedRootDirectory = 
            (size + context->bootSector.bytesPerSector - 1) 
                    / context->bootSector.bytesPerSector;

    // Step 4. Get the Last LBA/Sector # of the root diretory

    // rootDirectoryEnd basically stores the last LBA (or last sector#)
    // of the root directory, this will help us how much we should read
    // to get all the files in the root directory
    context->rootDirectoryEnd = lbaOfRootDirectory 
            + sectorsOccupiedRootDirectory;
    
    DirectoryEntry* newDir = (DirectoryEntry*)malloc(
            sectorsOccupiedRootDirectory * context->bootSector.bytesPerSector
        );

    if (newDir == NULL) {
        return false;
    }

    if (!readSectors(context, lbaOfRootDirectory, sectorsOccupiedRootDirectory, 
            newDir)) {
        free(newDir);
        return false;
    }

    if (context->rootDirectory != NULL) {
        free(context->rootDirectory);
    }
    context->rootDirectory = newDir;

    return true;
}


DirectoryEntry* findFile(FatContext* context, const char* name) {
    if (!validateFatContext(context) || name == NULL) {
        return NULL;
    }

    for (uint32_t i = 0; i < context->bootSector.dirEntryCount; ++i) {
        uint8_t firstByte = context->rootDirectory[i].name[0];

        if (firstByte == 0x00) {
            printf("End of active entries at index %u.\n", i);
            // end of directory
            break;
        }

        if (firstByte == 0xE5) {
            // when a file is deleted in FAT, the OS doesn't erase
            // 32 byte entry. It simply change the first byte to 0xE5
            continue;
        }

        /*
         * FAT filenames are strictly 11-byte fixed-width fields 
         * padded with spaces.
         * They are not null terminated C strings ('\0'). 
         * Using string functions (strcmp, strcpy) is a critical 
         * vulnerability here; 
         * they will overrun the 11-byte boundary and 
         * read adjacent struct fields until a random 0x00 is found. 
         * memcmp bounds the read strictly to 11 bytes.
         */
        printf("Found entry on disk: [%.11s]\n", 
                context->rootDirectory[i].name);
        if (memcmp(name, context->rootDirectory[i].name, 11) == 0) {
            printf("Found the match ..... ");
            return &context->rootDirectory[i];
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

bool readFile(DirectoryEntry* fileEntry, FatContext* context, 
        uint8_t* outputBuffer) {

    if (!validateFatContext(context) || fileEntry == NULL 
            || outputBuffer == NULL) {
        return false;
    }

    bool ok = true; 
    // Numbering start from 3, 4. ... 
    uint16_t currentCluster = fileEntry->firstClusterLow;
    
    const uint8_t sectorsPerCluster = context->bootSector.sectorsPerCluster;
    const uint16_t bytesPerSector = context->bootSector.bytesPerSector;

    do {
        const uint32_t lba = context->rootDirectoryEnd 
                + (currentCluster - 2) * sectorsPerCluster;
        // Step 1. Read the sectorsPerCluster starting the lba into the
        //         outputBuffer
        ok = ok && readSectors(context, lba, sectorsPerCluster, outputBuffer);
        // Step 2. Advance the output buffer by the size it read (jumps in byte)
        outputBuffer += sectorsPerCluster * bytesPerSector;

        // Step 3. FAT 12 is not FAT 16 (there is some GAP to reach multiple
        // of 8) 
        // If you see two 12-bit value shareds exactly three 8-bytes
        // So multily by 1.5 (3/2) gives you exact byte offset where your
        // 12-bit entry begins
        // Now even and odd also comes into the play, one start with the 
        // 0 bit of each byte and other start with the 4th bit of each byte

        // Even cluster vs Odd Cluster

        uint32_t fatIndex = currentCluster * 3 / 2;
        // What is the content in these FAT sectors ?
        // What if I jump to a fatIndex within the fat sector
        // As this is fat 12 we can do fatArray[currentCluster]
        // we have to translate the current cluster to the fat index
        // each index is 8 byte, so the 2nd cluster 
        uint16_t entry = context->fat[fatIndex] | 
                ((uint16_t)context->fat[fatIndex + 1] << 8);
        if (currentCluster % 2 == 0) {
            // First 12 bytes
            currentCluster = entry & 0x0FFF;
        } else {
            // Ignore the lower 4 bits
            currentCluster = entry >> 4;
        }

    } while (ok && currentCluster < 0x0FF8);

    return ok; 
}
 
void formatFatName(const char* input, char* output) {
    // Fill the output buffer with 11 spaces by default
    memset(output, ' ', 11);
    
    int i = 0; // Index for the input string
    int j = 0; // Index for the 11-byte FAT output

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

int main(int argc, char** argv) {
    if (argc < 3) {
        printf("Syntax: %s <disk image> <file name>\n", argv[0]);
        return -1;
    }

    FILE* disk = fopen(argv[1], "rb");
    if (!disk) {
        fprintf(stderr, "Cannot open disk image %s!\n", argv[1]);
        return -1;
    }

    FatContext context;
    memset(&context, 0, sizeof(FatContext));
    context.disk = disk;

    if (!readBootSector(&context)) {
        fprintf(stderr, "Could not read boot sector!\n");
        fclose(disk);
        return -2;
    }

    if (!readFat(&context)) {
        fprintf(stderr, "Could not read FAT!\n");
        fclose(disk);
        return -3;
    }

    if (!readRootDirectory(&context)) {
        fprintf(stderr, "Could not read root directory!\n");
        free(context.fat);
        fclose(disk);
        return -4;
    }

    char formattedName[11];
    formatFatName(argv[2], formattedName);

    DirectoryEntry* fileEntry = findFile(&context, formattedName);
    if (!fileEntry) {
        fprintf(stderr, "Could not find file %s!\n", argv[2]);
        free(context.fat);
        free(context.rootDirectory);
        fclose(disk);
        return -5;
    }

    uint8_t* buffer = (uint8_t*) malloc(fileEntry->size + 
            context.bootSector.bytesPerSector);
    
    if (!buffer) {
        fprintf(stderr, "Failed to allocate memory for file buffer!\n");
        free(context.fat);
        free(context.rootDirectory);
        fclose(disk);
        return -6;
    }

    if (!readFile(fileEntry, &context, buffer)) {
        fprintf(stderr, "Could not find file '%.11s'!\n", formattedName);
        free(buffer);
        free(context.fat);
        free(context.rootDirectory);
        fclose(disk);
        return -7;
    }

    for (size_t i = 0; i < fileEntry->size; i++) {
        if (isprint(buffer[i])) {
            fputc(buffer[i], stdout);
        } else {
            printf("<%02x>", buffer[i]);
        }
    }
    printf("\n");

    free(buffer);
    free(context.fat);
    free(context.rootDirectory);
    fclose(disk);
    
    return 0;
}