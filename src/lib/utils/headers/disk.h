#pragma once

#include "stdint.h"

// It tells the compiler to strip away all automatic padding bytes
#pragma pack(push, 1)

typedef struct {
    uint8_t  id;
    uint16_t cylinders;
    uint16_t sectors;
    uint16_t heads;
} Disk;

typedef struct {
    uint8_t  drive;
    uint16_t cylinder;
    uint16_t head;
    uint16_t sector;
    uint8_t  count;
    uint8_t far *buffer;
} DiskReadRequest;

typedef struct {
    uint8_t driveNumber;
} DiskResetRequest;

typedef struct {
    uint8_t driveNumber;
} DiskParamRequest;

typedef struct {
    uint8_t  driveType;
    uint16_t cylinders;
    uint16_t sectors;
    uint16_t heads;
} DiskParamResponse;

#pragma pack(pop)

/**
 * Utils
 */

bool initDisk(Disk *disk, uint8_t driveNumber);

bool readDiskSectors(
    Disk *disk,
    uint16_t lba,
    uint8_t count,
    uint8_t far *buffer
);
