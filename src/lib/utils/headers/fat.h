#pragma once 

#include "stdint.h"
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

#pragma pack(push, 1)
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

} BootSector;

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
} DirectoryEntry;

#pragma pack(pop)

// State of a mounted FAT filesystem.
// 1. The state holds the bootSector, which contains lot of useful
//    information, some of those are populated by the BIOS
// 2. A pointer holding the location of root directory
// 3. Open file stream pointer to the disk image (File object)
typedef struct {
    FILE* disk;
    BootSector bootSector;
    uint8_t* fat;
    DirectoryEntry* rootDirectory;
    uint32_t rootDirectoryEnd;
} FatContext;

// Stores the calculated locations and sizes of imp FAT regions on Disk
// the boot sector gives you the raw parameters, the VolumeGeometry holds
// those in a format which we can use directly
typedef struct {
    uint32_t fatLba;
    size_t fatSizeBytes;
    uint32_t rootDirLba;
    uint32_t dataRegionLba;
} VolumeGeometry;

enum FAT_Attributes
{
    FAT_ATTRIBUTE_READ_ONLY         = 0x01,
    FAT_ATTRIBUTE_HIDDEN            = 0x02,
    FAT_ATTRIBUTE_SYSTEM            = 0x04,
    FAT_ATTRIBUTE_VOLUME_ID         = 0x08,
    FAT_ATTRIBUTE_DIRECTORY         = 0x10,
    FAT_ATTRIBUTE_ARCHIVE           = 0x20,
    FAT_ATTRIBUTE_LFN               = FAT_ATTRIBUTE_READ_ONLY 
                                        | FAT_ATTRIBUTE_HIDDEN 
                                        | FAT_ATTRIBUTE_SYSTEM 
                                        | FAT_ATTRIBUTE_VOLUME_ID
};

bool readBootSector(FatContext* context);
bool readSectors(FatContext* context, uint32_t lba, 
        uint32_t count, void* bufferOut);
bool readFat(FatContext* context);
bool readRootDirectory(FatContext* context);
DirectoryEntry* findFile(FatContext* context, const char* name);
bool readFile(DirectoryEntry* fileEntry, FatContext* context, 
        uint8_t* outputBuffer);
