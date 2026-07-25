- [Assembly](#assembly)
  - [How a computer startup ?](#how-a-computer-startup-)
  - [How BIOS find the OS ?](#how-bios-find-the-os-)
  - [Directive vs Instruction](#directive-vs-instruction)
  - [Memory segmentation](#memory-segmentation)
  - [How to reference a memory location in assembly ?](#how-to-reference-a-memory-location-in-assembly-)
- [Bootloader](#bootloader)
  - [Floppy disk](#floppy-disk)
- [FileSystem](#filesystem)
- [References](#references)

## Assembly 

### How a computer startup ? 
- BIOS is copied from ROM to RAM
- BIOS start executing code
  - initialize the hardware
  - runs some test (POST)
- BIOS search for an operating system to load into the memory

### How BIOS find the OS ?
- Legacy booting
  - BIOS loads first sector of each bootable device into the memory at the location `0x7C00`
  - Check for a `0xAA55` signature
  - If found, then jumps to the first insturction in the loaded block
- EFI 
  - BIOS looks into specific EFI partitions
  - OS must be compiled using as an EFI programs

### Directive vs Instruction
- Directive
  - Gives a clue to the assembler that will affect how the program gets compiled. 
  - A directive is not translated to a machine code
- Instruction
  - Translates to a machine code instruction 
- `ORG` origin directive
  - Tells assembler where we expect our code to be loaded
  - It is not a CPU instruction - it only affect how assembler calculate addresses and labels. So it doesn't tell CPU where to execute the code
  - The assembler uses this information to calculate the label addresses 
- `bits` directive
  - Tell essembler to emit 16-bit code
  - It doesn't mean that processor will run in 16-bit or 32 or 64 
- `main` label
  - Entry point for the code
- `hlt` instruction
  - Stops CPU from executing
  - It can be resume by an interrupt
- `jmp label`
  - jumps to a given label
- `DB byte1 byte2 byte3` directive
  - Stand for define byte(s)
  - Write given bytes to the assembled binary file
  - bios require the last two sector are `0xAA55`
- `TIMES number of instruction/data` directive
  - Repeat given insturction or piece of data a number of times
- `$`
  - Special symbol which is equal to the memory offset of current line
- `$$`
  - Special symbol which is equal to the memory offset of the beginning of the current section (in our case, program)
- `$ - $$` 
  - Gives the size of our program so far in bytes
- `DW word1 word2 word3` directive
  - Define word(s)
  - Write given word(s) 2 byte value, encoded in little endian to the assembled binary file
- Why `510 - ($ - $$)` ?
  - total = 512 byte = 1 sector
  - Last 2 byte are for the signature
  - So remaining is 510
  - How many we have already filled ?
    - Start = `$$`
    - Current = `$`
    - Current - Start
  - So we have to fill `0` in `510 - ($ - $$)` bytes

### Memory segmentation
  - Segment:offset
  - Each segment can contains 64KB of memory
  - Segment overlap at 16 bytes
    - Segment i start = Segment i - 1 start + 2 byte
  - `real_address` = `segment# * 16` (4 bit shift left) + `offset`
  - There are multiple ways to name same address in the memory, because of different segment_#
- As mentioned Physical address = segment * 16 + offset
  - Ex. `mov al, [0x0020]` the CPU doesn't read from physical address `0x0020`. It first choose the default segment DS, then compute the physical address. 
    - DS * 16 + offset
    - 0x1000 * 16 + 0x0020
    - 0x10000 + 0x0020
    - 0x10020
  - So the actual address from where byte is read is 0x10020
  - Different kinds of instructions have different default segment register. The notation is segment_base:offset
    - `mov al, [var]` DS:var
    - `push ax`  SS:SP
    - `pop bx`   SS:SP (Stack Segment: Stack Pointer)
    - intruction fetch  CS:IP (Code segment: Instruction Pointer)
    - `movsb` destination ES:DI
  - You can override default if you want
    - `mov al, [0x020]` -> `mov al, [es:0x020]`
- There are special register to specify the current active segment
  - **CS**: currently running code segment
    - **IP** gives the offset
  - **DS**: Data segment
    - 
  - **SS**: stack segment
  - **ES**, **FS**, **GS** - extra data segments

### How to reference a memory location in assembly ?
- Memory location 
  - `segment: [base + index * scale + displacement]`
  - segment: CS, DS, ES, FS, GS, SS (DS if not specified)
  - base: 16 bit BP/BX (limitation), 32/64 bits any general purpose register
  - index: 16 bit SI/DI (limitation), 32/64 bits any general purpose register
  - scale: (32, 64 bit only) 1, 2, 4, 8
  - displacement: a signed constant value
- `mov destination, source` 
  - Copies data from source (register, memory reference, constant) to destination (register or memory reference)
- The stack
  - Memory access in a FIFO (first in, first out) manner using `push` and `pop` 
  - Used to save the return address when calling functions
  - It grows downwards
  - That's why we will setup our sp to the `0x7C00` becuase it will grow downwards towards 0 from `0x7C00` (safe spot)
- `LODSB`, `LODSW`, `LODSD`
  - These instruction loads a byte/word/double word from DS:SI into the AL/AX/EAX, then increment SI by the number of bytes loaded
    - `AL = [DS:SI]`
    - `SI = SI + 1`
- `jz destination`
  - Jumps to the destination if zero flag is set
- BIOS can help us to print the character on the screen
  - This we can achieve using the interrupts
  - A signal which makes the processor stop what it is doing, in order to handle the signal
  - Three way to trigger an interrupt 
    - An exception (e.g., divide by zero, segmentation fault, page fault)
    - Hardware (e.g., keyboard, timer ticks, disk controller finish some operation)
    - Sofware, through the INT instruction 
      - INT [0 to 255]
  - BIOS has interrupt handler for us, so that we can use this functionality 
    - INT 10h : video
    - INT 11h : Equipment check 
    - INT 12h : memory size 
    - INT 13h : Disk I/O
    - INT 14h : Serial communication 
    - INT 16h : Keyboard I/O 
- BIOS INT 10h, h represent hexadecima
  - By setting AH = 0Eh we can write character in TTY mode 
  - Read more here [INT 10H/0x10](https://en.wikipedia.org/wiki/INT_10H) and the list of supported function 
  - The function that we will use is 0x0e
  - To tell which function to use we will `ah` register
  - And the page number = 0, using `bh`
  - Check the wiki page to understand the argument it takes
  - It reads `al` register and the same is written by `lodsb`
  - When your raise the interrupt. The handler is dispatch which in this case is the teletype function which reads the register you have setup and simply print onto the screen and move the cursor to the next.

## Bootloader
- loads basic components into memory
- puts system in expected state
- collects information about system 
- Modern operating system expect bootloader to make a switch to 32-bit protected mode and also collect some information
- Some of the fuction which are only applicable for 16bit are no more use in the 32 bit
- So bootloader responsiblity to collect all the information before it start the main kernel 

### Floppy disk
- ease to use 
- universal support by all BIOS
- FAT12 file system one of the simplest file system
- Simplest way we can use disk is 1st sector = boot sector and rest of operating system start from sector 2

- When we attempted to copy the bootloader to the first sector it wiped out the parameters which are used by the FAT12 which we created in the previous step 
    ```bash
    $(FLOPPY_IMAGE): bootloader kernel 
      $(DD) if=/dev/zero of=$(FLOPPY_IMAGE) bs=$(FLOPPY_SECTOR_SIZE) count=$(FLOPPY_BLOCKS)
      $(MFORMAT) -i $(FLOPPY_IMAGE) -f $(FLOPPY_SIZE) -v BOOT ::
      $(DD) if=$(BOOTLOADER_BIN) of=$(FLOPPY_IMAGE) conv=notrunc
      $(MCOPY) -i $(FLOPPY_IMAGE) $(KERNEL_BIN) ::kernel.bin
    ```
- By overriding we have broken the file system
    ```bash
    mformat  -i build/floppy_boot.img -f 1440  -v BOOT ::
    dd if=build/bootloader.bin of=build/floppy_boot.img conv=notrunc
    1+0 records in
    1+0 records out
    512 bytes transferred in 0.000043 secs (11906977 bytes/sec)
    mcopy -i build/floppy_boot.img build/kernel.bin ::kernel.bin
    init :: non DOS media
    Cannot initialize '::'
    ::kernel.bin: Undefined error: 0
    make: *** [build/floppy_boot.img] Error 1
    ```
- Solution is to add these to our bootloader
  - Check this [FAT-12](https://wiki.osdev.org/FAT)
  - You can name the variable anything of your choice, but you have to ensure the actual byte your are writing matching the spec using `db` directive
- Disk layout
  - Track/Cylinder
  - Sector 
  - Head (each side of platter)
- To read/write, we need to tell the disk controller
  - Cyliner number, Head number, Sector number (CHS scheme)
- Logical Block Addressing schemed:
  - Instead of triplet of number, we only need one single number to reference a block on the disk. 
  - Unfortunately the BIOS function we wil use only support CHS addressing
- LBA to CHS conversion
  - sector per track/cylinder (on a single side)
  - heads per cylinder (or just heads)
  - sector = (LBA % sector per track) + 1  (sector is base 1)
  - head = (LBA / sector per track) % heads
  - cylinder = (LBA / sector per track) / heads

## FileSystem
- Organizing peices of data on a disk 
- We will understand FAT 12 
- A FAT disk is organized in to four region
  - Reserved (Boot loader + additional metadata)
  - File Allocation Table (FAT)
    - Look up table to get the next block of data
  - Root directory
    - Table of content of disk
  - Data region
- How to find the location of root directory (third region) ?
  - Lets caculate the size of first two : Reserved and FAT 
  - Mostly reserved in 1 sector
  - 2nd region: FAT count * Sector per FAT 
- Root directory size (in number of sectors)?
  - ceil (Number of directory entry count * size of each entry) / size of each sector in byte
  - This is what we will read into the memory
- "The root directory"
  - Lets now go through these directory entries and see how we can find out the file we are looking for ?
    - Each entry (Filename, Attr, Creation time, Creation date, Access date, First cluster (high), Modified time, Modified date, First cluster (low), Size)
    - The low and high 'first cluster' signifies the. Together they for 32 bit number which is useful in FAT32, but in our case we using FAT12, so we need lower 16 bits 
    - File name is max up to the 11 char long
      - We need to compare with this
- So what are these cluster exactly ? 
  - Just like disk uses blocks called 'sector'
  - FAT called blocks called as 'cluster'
  - The conversion is defined in the field in the boot sector named as 'sector per cluster'
- Since we know where is the first cluster of the file is located, we can already read the first block of file in the memory
  - The cluster number (first cluster (high + low)) gives us the location in the data region. 
  - And this cluster number start from 2 (i.e., start index is 2)
  - So to convert it to the sector number
    - Size of first 3 region = bootsector + FAT table + root. Let say this as data_region_begin
    - So formulation is = data_region_begin + (cluster - 2) * sector_per_cluster;
  - Now that is the first cluster. How to get the next cluster ? This is where FAT will come into the play
    - This is simple lookup table, where the index of an entry corresponds to the cluster number and the entry indicate the next cluster
    - The size of each entry depends on the FAT type
    - FAT 12 each entry is 12 bits
  - The last cluster ?
    - FFF
- What if the file we are trying to find is not in the root directory ? And it may be inside some folder ?
  1. Split path into components parts (and convert to the FAT file naming scheme)
    - Foo\bar\hello.txt -> "Foo         ", "Bar        ", "Hello      txt" 
  2. Read the first directory from the root directory, using same procedure as reading files. Directories have same structure as the root directory, and can be read just like ordinary file
  3. Search the next component from the path in the directory, and read it
  4. Repeat until reach the file

- Some BIOS might start with 07C0:0000 instead of 0000:07C0
  - We can use returnf to alter the CS and IP [RETF](https://pushbx.org/ecm/doc/insref.pdf)
    - Execute a far return: after popping IP/EIP, it then pops CS, and then increments the stack pointer by the optional argument if present

- ![Boot from disk](./misc/images/boot-from-disk.png)


## References
- [int 13 and BIOS routines](https://www.ctyme.com/intr/int-13.htm)
  - BIOS provides some routines, which you can call. To call those you have to set the appropriate register. 
    - We need to specify the function, args (if any), and returns
    - If any of you current args will get used during the function call, then you should push those value to the stack and at the end you recover those in the reverse order of push by using pop instruction
- [RETF](https://pushbx.org/ecm/doc/insref.pdf)
- [FAT-12](https://wiki.osdev.org/FAT)
- [INT 10H/0x10](https://en.wikipedia.org/wiki/INT_10H)