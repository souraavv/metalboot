#pragma once 

// ---------------------------
// Real mode address space 'usable' address space is < 1MiB
// when a x86 boots it start in 16-bit real mode
// 
// ----------------------------

// ---------
// We will use this file to manage the memory
// Ref. https://wiki.osdev.org/Memory_Map_(x86)
//      https://wiki.osdev.org/Real_Mode
// 
// (Memory_min)
// 0x00000500   0x00007BFF  29.75 KiB   Conventional memory	-usable memory
// 0x00007C00   0x00007DFF  512 bytes   Your OS BootSector  -usable memory
// 0x00007E00   0x0007FFFF  480.5 KiB   Conventional memory -usable memory
//              (memory_max)
// ---------

// 0x00000000 - 0x000003FF - interrupt vector table (IVT - 256 interrupts)
// Ref. https://wiki.osdev.org/Interrupt_Vector_Table

// 0x00000400 - 0x000004FF - BIOS data area (BDA)
#define MEMORY_MIN          0x00000500
#define MEMORY_MAX          0x00080000

// 0x00000500 - 0x00010500 - FAT driver
#define MEMORY_FAT_ADDR     ((void far*)0x00500000) // segment:offset (SSSSOOOO)
#define MEMORY_FAT_SIZE     0x00010000

// 0x00020000 - 0x00030000 - stage2

// 0x00030000 - 0x00080000 - free

// 0x00080000 - 0x0009FFFF - Extended BIOS data area (EBDA)
// 0x000A0000 - 0x000C7FFF - Video
// 0x000C8000 - 0x000FFFFF - BIOS