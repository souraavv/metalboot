#pragma once

#include "stdint.h"

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
} DriveParamRequest;

typedef struct {
    uint8_t  *driveType;
    uint16_t *cylinders;
    uint16_t *sectors;
    uint16_t *heads;
} DriveParamResponse;

bool initDisk(Disk *disk, uint8_t driveNumber);

bool readDiskSectors(
    Disk *disk,
    uint16_t lba,
    uint8_t count,
    uint8_t far *buffer
);