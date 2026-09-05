#pragma once 

#include "stdio.h"
#include "stdint.h"
#include "disk.h"

/**
 * References
 * 1. https://wiki.osdev.org/FAT
 * 
 * Disk structure:
 * ---------------------------------------------------------------------
 * | Reserved |   FAT 1   |   FAT 2   |  Root Dir  | Data Region...  |
 *  -------------------------------------------------------------------
 * ^          ^                       ^
 * LBA 0      LBA 4                   LBA 22
 *            (fatLba)                (rootDirLba)
 *
 *            |<---- 18 sectors ----->|
 *             fatCount * secPerFat 
 *             (2 FATs  * 9 sectors)
 * FAT1 - master map for your disk's data
 * 
 *   
*/

// ------ Constants ---------
#define SECTOR_SIZE             512
#define MAX_PATH_SIZE           256
#define MAX_FILE_HANDLES        10
#define ROOT_DIRECTORY_HANDLE   -1

#pragma pack(push, 1)
/**
 * Overall story:
 * 
 * A FAT12 disk is organized like this:
 *  BootSector | Reserved | FAT#1  | FAT#2 | Root directory -> DataRegion
 * 
 * Data Region constitute of clusters starting index 2 (Custer 2, Cluster 3, ..)
 * 
 * The boot sector tells us how the rest of filesystem is laid out
 * and it make sense that info should be in the bootsector and that should 
 * be the owner of that metadata. It contains info about the bytePerSector
 * sectorsPerCluster, reservedSectors, fatCount, sectorsPerFat, directoryEntry
 * count
 * 
 * So bootsector tells use the volume geometry
 * 
 * The FAT (File Allocation Table) is also metadata - about where the next
 * cluster belong to this file (The chain of clusters associated with a file)
 * 
 * Then we have entries in that - like Directory Entry - metadata describing
 * one file or directory 
 * 
 * The actual file is in the data region. To scan and communicate in data
 * region we use 'cluster' terminology. But when to read from the disk,
 * we have to use LBA. So we need a conversion layer which converts the
 * cluster to LBA = DataRegionLBA + (cluster - 2) * sector in each cluster
 * 
 * LBA number directly translate to the sector # - that is the basic unit to 
 * read
 * 
 * When reading the disk, we want to keep few things loaded in to the RAM.
 * So we willl create Data structures which will hold that
 * 
 * One of them with be FATContext 
 *   - It is a center place which holds every thing, we will refer to this
 *     in our code 
 *   - it contains the volume geometry, FAT, boot sector info, openedFile
 *     info and may be many more.. Single place to refer every thing.
 * 
 * why we need the volume geometry ?
 *   The boot sector gives us the basic units like - how many sectors each
 *   cluster contains, how many sectors are taken by each FAT table, and how
 *   many FAT tables are present. We translate these values in to something
 *   which is more meaningful for the other utilities like LBA of these 
 *   - e.g., LBA of root directory, FAT LBA, root directory size, data region
 *           LBA. That is more meaningful to use
 * 
 * The root directory is basically an array of 32 byte records
 *  - each entry describes one file or directory
 *     We are calling it as DirectoryEntry (name, attributes, firstcluster,
 *     size, timestamps)
 * 
 * Directory entry is persistent file system metadata
 *    -e.g., it says there is a file named : test.txt with first cluster at 5
 *           and size is 12bytes
 * 
 * When we open that file, we need additional runtime information
 *  - Where am i currently reading ?
 *  - Which cluster am I currenly in ?
 *  - Which sector inside that cluster am I reading ?
 *  - What sector is currently cached ?
 *  
 * what is FAT File ? An object exposed to the caller
 *  - The caller doesn't need to know about: 
 *     - FAT12's 12-bit entries
 *     - current FAT cluster
 *     - sector cached
 *     - FAT table layout
 * 
 * The caller needs an abstraction: handle, isDirectory, position and size
 * 
 * - InitFAT 
 *   - readBootSector(), calcuateVolumeGeometry, readFat(), readRootDirectory
 */


/**
 * FAT 12, 16 BIOS Parameter block + Extended boot record
 * 
 */
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

    // ingore remaning...

} BootSector;

/**
 * Represents the 32-byte record that exists on the FAT file system
 * 
 * Ref.  https://wiki.osdev.org/FAT
 *  Search for the FAT 12/FAT 16 Directory Entry structure
 */
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


/**
 * These values are derived from the metadata present in the bootsector
 * BPB Block 
 * 
 * We need things in term of LBA.
 */
typedef struct {
    uint32_t fatLba;
    uint32_t fatSizeBytes;
    
    uint32_t rootDirLba;
    uint32_t rootDirSectors;

    uint32_t dataRegionLba;
} VolumeGeometry;


/**
 * FAT Attributes
 */
enum FAT_Attributes
{
    FAT_ATTRIBUTE_READ_ONLY = 0x01,
    FAT_ATTRIBUTE_HIDDEN = 0x02,
    FAT_ATTRIBUTE_SYSTEM = 0x04,
    FAT_ATTRIBUTE_VOLUME_ID = 0x08,
    FAT_ATTRIBUTE_DIRECTORY = 0x10,
    FAT_ATTRIBUTE_ARCHIVE = 0x20,
    FAT_ATTRIBUTE_LFN = 
            FAT_ATTRIBUTE_READ_ONLY |
            FAT_ATTRIBUTE_HIDDEN |
            FAT_ATTRIBUTE_SYSTEM |
            FAT_ATTRIBUTE_VOLUME_ID
};

/**
 *  Object exposed to the consumers
 *  
 *  It describe the logical file, not FAT implementation details. this is
 *  what a caller will recieve when they open the file to read
 */
typedef struct  {
    uint32_t handle;
    bool isDirectory;
    uint32_t position;  // Logical byte position in file
    uint32_t size;
} FatFile;

// ------ Internal file system details


/**
 * This describes WHAT the opened file is.
 * 
 * These values do not change as the file is read.
 */
typedef struct {
    uint32_t firstCluster; 
    uint32_t size; 
    bool isDirectory;
} FatFileInfo;

/**
 * This describes WHERE we currently are while reading the file.
 */
typedef struct {
    uint32_t position; 
    uint32_t currentCluster;
    uint32_t currentSectorInCluster; 

    uint8_t buffer[SECTOR_SIZE];
} FatFileCursor;

/**
 * This is the complete internal state of one opened file.
 */
typedef struct {
    FatFile public; 
    FatFileInfo info; 
    FatFileCursor cursor;
    bool opened;
} FatFileData; 


/**
 * State of a mounted FAT filesystem.
 * - The state holds the bootSector, which contains lot of useful
 *   information, some of those are populated by the BIOS
 * - A pointer holding the location of root directory
 * - Open file stream pointer to the disk image (File object)
 */
typedef struct {
    Disk* disk;
    
    BootSector bootSector;
    
    VolumeGeometry geometry;
    
    uint8_t far* fat;

    DirectoryEntry far* rootDirectory;
    
    FatFileData rootDirectoryFile; 
    FatFileData openedFiles[MAX_FILE_HANDLES];

} FatContext;


// Public APIs
bool fatInitialize(FatContext* context);
FatFile* open(FatContext* context, const char* name);
uint32_t read(FatContext* context, FatFile* file, uint32_t byteCount,
        uint8_t far* outputBuffer);
void close(FatContext* context, FatFile* file);
void destroy(FatContext* context);
