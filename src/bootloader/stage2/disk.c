#pragma once 

#include "disk.h"
#include "stdint.h"
#include "x86_disk.h"

/**
 * 
 * C89 Declaration Order - The Watcom compiler is strictly enforcing the C89
 * standard, which dictates that all variables must be declared at 
 * the very top of their enclosing block, prior to any executable statements
 */

bool initDisk(Disk *disk, uint8_t driveNumber) {
    DiskResetRequest resetRequest;
    DiskParamRequest diskParamRequest;
    DiskParamResponse diskParamResponse;
    
    if (disk == NULL) {
        return false;
    }

    resetRequest.driveNumber = driveNumber;

    if (!x86_Disk_Reset(&resetRequest)) {
        return false;
    }

    diskParamRequest.driveNumber = driveNumber;
    if (!x86_Disk_GetDriveParameter(&diskParamRequest, &diskParamResponse)) {
        return false;
    }

    // diskParamResponse is on stack, thus using '.' to access
    disk->id = driveNumber; 
    disk->cylinders = diskParamResponse.cylinders + 1;
    disk->sectors = diskParamResponse.sectors;
    disk->heads = diskParamResponse.heads + 1;

    return true;
}

static bool lbaToChs(
    Disk *disk,
    uint16_t lba,
    uint16_t *cylinder,
    uint16_t *head,
    uint16_t *sector
) {
    uint16_t sectorsPerCylinder;
    uint16_t remainder;

    if (disk == NULL || cylinder == NULL 
            || head == NULL || sector == NULL) {
        return false;
    }

    if (disk->sectors == 0 || disk->heads == 0) {
        return false;
    }

    sectorsPerCylinder = disk->sectors * disk->heads;
    
    *cylinder = (lba / sectorsPerCylinder);

    remainder = lba % sectorsPerCylinder;

    *head = (remainder / disk->sectors);
    *sector = (remainder % disk->sectors) + 1;
    
    return true;
}

bool readDiskSectors(
    Disk *disk,
    uint16_t lba,
    uint8_t count,
    uint8_t far *buffer
) {
    uint16_t cylinder;
    uint16_t head; 
    uint16_t sector;
    DiskReadRequest request;

    if (disk == NULL || buffer == NULL) {
        return false;
    }

    if (!lbaToChs(disk, lba, &cylinder, &head, &sector)) {
        return false;
    }

    // request is on the stack
    request.drive = disk->id;
    request.cylinder = cylinder;
    request.head = head;
    request.sector = sector;
    request.count = count;
    request.buffer = buffer;

    return x86_Disk_Read(&request);
}
