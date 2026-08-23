#pragma once

#include "disk.h"

bool _cdecl x86_Disk_Reset(
    DiskResetRequest *resetRequest
);

bool _cdecl x86_Disk_Read(
    DiskReadRequest *diskReadRequest
);

bool _cdecl x86_Disk_GetDriveParameter(
    DriveParamRequest *diskParamRequest,
    DriveParamResponse *diskParamResponse
);