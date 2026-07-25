org 0x7C00                    ; directive to tell the use this as base address to address this 
bits 16                       ; directive to tell that generate 16 bit instructions

; symbol = new line
%define ENDL 0x0D, 0x0A      

;
; FAT12 header 
; BPB (BIOS parameter block)
; source: https://wiki.osdev.org/FAT
;

; starting offset 0(0x00) to 32 (0x20)

;
; db, dw are the directives
; db means define byte, size = 8 bits
; dw means define word, size = 16 bits
; dd means double word, size = 32 bits
; dq means quad word, size = 64 bits
;
jmp short start 
nop                        ; 3 bytes jmpm short <entry-point> 
bdb_oem_identifier:        db 'MSWIN4.1'   ; 8 byte -  If the string is less than 8 bytes, it is padded with spaces.
bdb_bytes_per_sector:      dw 512          ; 2 bytes
bdb_sectors_per_cluster:   db 1            ; 1 bytes
bdb_reserved_sectors:      dw 1            ; 1 bytes
bdb_fat_count:             db 2            ; 2 bytes
bdb_dir_entries_count:     dw 0E0h         ; 2 bytes (17 offset)
bdb_total_sectors:         dw 2880         ; size = 2 bytes, 2880 * 512 = 1.44MB
bdb_media_descriptor_type: db 0F0h         ; size = 1 byte, F0 = 3.5' floppy disk 
bdb_sectors_per_fat:       dw 9            ; size = 2 bytes, 9 sector / fat
bdb_sectors_per_track:     dw 18           ; size in byte = 2 
bdb_heads:                 dw 2            ; 2 bytes
bdb_hidden_sectors:        dd 0            ; 4 bytes
bdb_large_sector_count:    dd 0            ; 4 bytes

;
; source: https://wiki.osdev.org/FAT
; extended boot sector 
; starting offset 36 to 510 
; 0x03E + 448 bytes = boot code 
; 510 + 2 bytes bootable paritition signature 0xAA55 
; 
ebr_drive_number:          db 0             ; 0x00 floppy, 0x80 hdd
                           db 0             ; reserved 
ebr_signature:             db 29h
ebr_volume:                db 12h, 34h, 56h, 78h
ebr_volume_label:          db 'SOURAVSH OS' ; 11 bytes
ebr_system_id:             db 'FAT12   '    ; 8 bytes


start:
    ; setup data segment to absolute 0
    ; can set directy ds, es, ss to 0, thus doing it via ax,
    ; xor ax, ax always guarantee to set the value of ax to 0 (bitwise xor)
    xor ax, ax         ; al and ah are higher and lower 8 bits of ax, set ax = 0
    mov ds, ax         ; can't write directly to ds, es. Set the DS to 0
    mov es, ax         ; set es to 0 (Extra segment)

    ; setup stack 
    mov ss, ax         ; setup the stack segment to 0 
    mov sp, 0x7C00     ; stack pointer to the beginning of our program (or below our bootloader address)
                       ; stack grown from 0x7C00 towards 0

    ; Some BIOS might start up at 0x7C00:0000 i.e., CS:IP (check notes)
    ; But we want IP = 0x7C00 and CS = 0
    ; We can't manipulate the code segment register directly, we have to perform
    ; push offset and segment to the stack and then use retf (https://pushbx.org/ecm/doc/insref.pdf)
    ; and then performing a far return. The retf instruction pop the two values
    ; from the stack to these two register first value to the IP and last value to the CS
    ; So our desired state is CS = 0 and IP = 0x7C00. The both are 16 bit. So that's why 
    ; we will push the address as a word (i.e. 2 byte = 16 bit)

    push es            ; push an 0
    push word .after   ; push a 2 byte (i.e., a word) .after is resolved by the assember
    retf 

.after:
    ; read something from the floppy disk 
    ; BIOS should set the DL to driver number 
    mov [ebr_drive_number], dl 

    ; Show loading message
    mov si, msg_loading  ; si holds the start address of msg_loading
    call puts

    ; read driver parameters
    push es 

    ; We will use the BIOS routine int13 (disk service)
    ; https://www.ctyme.com/intr/int-13.htm 
    ; Int 13/AH=08h - DISK - GET DRIVE PARAMETERS (PC,XT286,CONV,PS,ESDI,SCSI)
    ; https://www.ctyme.com/intr/rb-0621.htm 
    push es 
    mov ah, 08h        ; util: get drive parameters
    int 13h            ; disk service routine
    jc floppy_error
    pop es
    
    ; CL = maximum sector number (bits 5-0)
    ; high two bits of maximum cylinder number (bits 7-6)
    ; We need first 6 bits (0-5) = 0011 1111 = 0x3F
    ;
    and cl, 0x3F       ; remove top 2 bits - cl contains the maximum sector number i.e., last
    xor ch, ch         ; safer way to set 0 in assembely. You need not to worry about how many bits are used by ch

    ; persist the value of cx i.e. ch, cl = 0000 0000 00<number of sector>
    ; into the BIOS parameter Block (BPB)
    mov [bdb_sectors_per_track], cx 
    
    ; DH = maximum head number (base = 0), thus +1
    inc dh            
    ; persist in to the BPB
    mov [bdb_heads], dh 
    ; There are four section in a floppy disk. The following is the order
    ;;;     first section  - Reserved Bootloader (512 byte) = 1 sector ;;;

    ;;;     second section - FAT table (sector per FAT * number of FAT) ;;;


    ;;;     third section   ;;;
    ; read FAT root directory
    ; The base of this start after first two sections = first section + second 
    ; section

    ; This is kind of fix thus we can refere to BDB ? I believe..  may be specification set already ?
    mov ax, [bdb_sectors_per_fat]  ; the bdb_sectors_per_fat was dw i.e., 2 bytes thus it will take ah, al (8 bits each)
    mov bl, [bdb_fat_count]        ; Notice BL was populated by BL = drive type (AT/PS2 floppies only)
                                   ; but didn't saved bl (push bl) because we dont' need that info..
                                   ; note that dbb_fat_count was db (1 byte) and bl is also 8 bits 
    
    ; formula lba = bootsector.reservedSectors + sector_per_fat * count_fat
    xor bh, bh

    ; after mul the ax will have = sector_per_fat * count_fat
    mul bx                         ; mul instruction has 2 operand; one is specified and other is implicit i.e., ax
                                   ; ax = ax * bx
    add ax, [bdb_reserved_sectors]
    push ax                        ; save the value of LBA of root directory

    ; 
    ; Compute the size of root directory  = 
    ; size = (32 bit * number of entries) / bytes_per_sector 
    ; because you need a produce thus we are saving ax 
    ; bdb_dir_entries_count:     dw 0E0h         ; 2 bytes (17 offset) 
    ; https://wiki.osdev.org/FAT#FAT_12
    ; FAT entry is 32 byte so to conver this into the unit sector
    mov ax, [bdb_dir_entries_count]
    shl ax, 5                         ; multiply by 32
    xor dx, dx                        ; dx = 0
    div word [bdb_bytes_per_sector]   ; DX = remainder, AX = Quotient (number of sector)

    ; is a way to check if dx == 0.. if dx = 0, then only dx, dx i.e, bitwise of dx & dx = 0
    test dx, dx 
    jz .root_dir_after
    inc ax                            ; division remainder != 0, add 1

.root_dir_after:

    ; read root directory
    ; https://www.ctyme.com/intr/rb-0607.htm 
    ; routine 13h, method: 02h, ah = 02h

    ; 
    ; now we will call the disk read, so setup the parameters for that 
    ; method we have implemented: disk_read
    mov cl, al                      ; div contains the number of sector in AX, so move that value to the CL
                                    ; cl = number of sector to read = size of root directory
    pop ax                          ; get back the value of LBA of root directory
    mov dl, [ebr_drive_number]      ; driver number
    mov bx, buffer                  ; es:bx = buffer (es:bx: memory address where to store read data)
                                    ; in the ES section at the offset bx ES:BX -> data buffer (see the link)
                                    ; bx = buffer, bx point to the buffer ?

    call disk_read

    ; search for kernel.bin file in the directory 
    ; di = current directory entry and bx how many entry scanned

    xor bx, bx 
    mov di, buffer                  ; di point the address where the we have read root directory section
    ; as file name is the first field in the structure thus the di will also point to the same



.search_kernel:
    mov si, file_kernel_bin
    mov cx, 11                      ; length of file_kernel_bin name i.e. 11 char
    push di                         ; save the value of di, which points toth eroot director start 
    ; note that di point to the begin of entry which is essentially the file name which
    ; is fixed 11 byte
    ; repeat while equal or until cx reach to the 0, cx is decremented on each iteration

    ; this will incremente di = di + 1, and si = si + 1 until we iterate to the length of si, i.e, cx 
    ; each iteration cx = cx - 1
    ; for (int i = cx - 1; i >= 0 ; --i) { if (si == di), then si++, di++}
    repe cmpsb                      ; compare string byte (compare two byte, si and di )
                                    ; ds:si, es:di
                                    ; si and di are incremented when direction flag = 0, else =1 then decremented
    pop di 
    ; if both string are same
    je .found_kernel                ; move to the kernel label
    ; point di to the next entry in the root directory and repeat again, until when ? until bx reach the number of entry cont
    add di, 32                      ; di = di + 32 (size of each entry in the root directory)

    inc bx 
    cmp bx, [bdb_dir_entries_count]
    jl .search_kernel

    ; kernel not found
    jmp kernel_not_found_error

.found_kernel:

    ; di now have the address of the entry
    ; now we will locate the lower cluster field which is at the 26 offset 
    ; 26 offset in an 32 byte entry in the root file. so check the current i.e., di 
    ; starting entry and read the value 
    mov ax, [di + 26]               ; to get the first cluster, you read 2 byte i.e, 26, 27 into the ax 
                                    ; which is the staring cluster number, now go for the chain
    mov [kernel_cluster], ax        ; store the value, mov 2 byte (ax) to a word (2byte) location kernel_cluster
    
    ; now to read all the cluster we need to iterate through the FAT
    ;;; Load the file allocation table ;;;

    ; base of FAT = reserved sector 
    mov ax, [bdb_reserved_sectors]
    mov bx, buffer                  ; es:bx, es = 0, bx = buffer, means disk_read will write to es:bx
    mov cl, [bdb_sectors_per_fat]
    mov dl, [ebr_drive_number]
    call disk_read 

    ; read kernel and process FAT chain
    ; where to put file into the memory ?
    ; since we are in 16-bit, we can't access memory = 2^16 = 640KiB RAM ("lower memory")
    ; We have a contigous are between bootloader 07C00 + 512 Byte = 0x7DFF and extended BIOS Data area

    ; 0x[0000 0000] - 0x[0000 03FF]
    ;       1KiB - Interrupt vector table (IVT) - Unusable in read mode 
    ; 0x[0000 0400] - 0x[0000 04FF]
    ;       256 Byte - BDA (BIOS data area) - Unusable in real mode
    ; ---------- Low memory begin 16-bit (2^16 = 640KiB RAM) -----------------
    ; -------- usable memory begin ------------
    ; 0x[0000 0500] - 0x[0000 7BFF]
    ;       30KiB Conventional memory - 30KiB. If you notice we use this for the stack 
    ; 0x[0000 7C00] - 0x[0000 7DFF]
    ;       512Byte - OS boot sector
    ; 0x[0000 7E00] - 0x[0007 FFFF]
    ;       480.5KiB                       <-------------- 
    ; --------- usable memory ends -------------
    ; 0x[0008 0000] - 0x[0009 FFFF] 
    ;       128KiB - EBDA (Extended BIOS data area)
    ; 0x[000A 0000] - 0x[000B FFFF] 
    ;       128KiB - video display memory Hardware mapped
    ; ------------ Upper memory begin (348KiB) (Reserved) ---------------
    ; And upper 384KiB / Reserved memory ("upper memory")
    ;    video BIOS, BIOS expansion, Motherboard BIOS
    

    ; since we are using some memory at the end of bootloader for FAT 
    ; we should leave some room there; so we will pick 20000 in hex 
    ; remaining = 380KiB
    mov bx, KERNEL_LOAD_SEGMENT   ; bx = 20000 address
    mov es, bx                    ; extra segment, starting from es:bx
    mov bx, KERNEL_LOAD_OFFSET    ; bx = 0

.load_kernel_loop:
    ; read next cluster
    ; convert from cluster number to the sector
    mov ax, [kernel_cluster]        ; fetch the saved value of first cluster

    ; 31 hardcoded for now 
    add ax, 31                      ; first_cluster = (cluster_number - 2) * sectors_per_cluster + start_sector
                                    ; start_sector = reserved + fat + root directory size = 1 + 18 + 13 = 32

    mov cl, 1                       ; read one sector
    mov dl, [ebr_drive_number]
    call disk_read 

    add bx, [bdb_bytes_per_sector] 

    ; compute location of next cluster
    mov ax, [kernel_cluster]        ; fetch the saved value of first cluster (index of first cluster in the fat)
    mov cx, 3                       ; 3/2 as 1.5 byte each entry i.e., 12 bit in FAT 12 table
    mul cx                          ; ax = ax * cx (cx = 3)
    mov cx, 2                       ; cx = 2
    div cx                          ; ax = ax / cx, and ax = quotient, dx = remainder
                                    ; ax = index of entry in the FAT 
                                    ; dx = cluster index mod 2 (cx = 2)
    
    ; It is reading a FAT entry from the FAT table already loaded into buffer
    ; si + ax = buffer_base + current_cluster 
    mov si, buffer                  ; mark si to the begin the buffer region, where disk_read has written
    add si, ax                      ; si = si + source index (offset) = FAT_OFFSET
    mov ax, [ds:si]                 ; read entry from FAT table at index ax 
                                    ; si = buffer, and ds = 0; Physical address = ds * 16 + si 
                                    ; thus mov ax, [0:]

;
; e.g.,
;  0x23 (first 8 bits),  (0x61) (next 8 bit),  (0x45) (next 8 bit)
;  for even we have to pick 
;  The number in little endian = 0x6123
;  for even we have to read 0x6123 -> 0x123 : Keep last three i.,e 0x0FFF
;  for odd we have to read  0x4561 -> 0456 : Transformation func: >> 4
;
.odd:
    shr ax, 4
    jmp .next_cluster_after

.even:
    and ax, 0x0FFF

.next_cluster_after:
    cmp ax, 0x0FF8                  ; end of chain
    jae .read_finish                ; exit the loop, done

    mov [kernel_cluster], ax
    jmp .load_kernel_loop

.read_finish:
    ; jump to the kernel
    mov dl, [ebr_drive_number]      ; boot device in the dl
    mov ax, KERNEL_LOAD_SEGMENT     ; set segment register
    mov ds, ax                      ;
    mov es, ax                      ; 
    
    jmp KERNEL_LOAD_SEGMENT:KERNEL_LOAD_OFFSET

    jmp wait_key_and_reboot
    cli                             ; disable interrupt that way cpu cant' get out of "halt" state
    hlt 
;
; Print a string to the screen
; Params:
;     - ds: si points to the string
;            from the data segment it start reading from si
;
puts:
    ; save the register we will modify
    push si            ; SI is set to the start address, we will read starting this
    push ax            ; save initial value of ax which is 0
    push bx

.loop:
    lodsb              ; load next character in al and increment si by # of byte loaded
    and al, al         ; verfiy if next character is null
    jz .done           ; previous instruction return 0 then jump

    mov ah, 0x0E       ; BIOS teletype output
    mov bh, 0          ; display page
    int 0x10           ; calls BIOS

    jmp .loop          ; again till there are words

.done:
    pop bx
    pop ax             ; restore the value of ax
    pop si             ; restore the value of si
    ret

;
; error handlers
;
floppy_error: 
    mov si, msg_read_failed
    call puts 
    jmp wait_key_and_reboot

kernel_not_found_error:
    mov si, msg_kernel_not_found 
    call puts 
    jmp wait_key_and_reboot

; Int 16/AH=00h - KEYBOARD - GET KEYSTROKE
; https://www.ctyme.com/intr/rb-1754.htm
wait_key_and_reboot:
    mov ah, 0 
    int 16h         ; wait for key press
    jmp 0FFFFh:0    ; jump to the beginning of the BIOS, should reboot 
    
.halt:
    cli             ; disable interrupt, this way we can't get out of "halt" state
    hlt
;
; Disk routines
;

; 
; convert an LBA to CHS address
; we will store the result exactly like bios function expect us to
; 
; Parameters:
;   - ax: LBA address
; Returns: 
;   - cx [bits 0-5] : sector number
;   - cx [bits 6-15]: cylinder
;                      CX = -- CH --  -- CL --
;                 cyliner = 76543210  98
;                 sector  =             543210          
;
;   - dh            : head
;
lba_to_chs:
    ; save the register value at the top of the stack
    ; which will get pollute by the end
    push ax 
    push dx

    xor dx, dx             ; we reset dx
                           ; reading few next line will justify the reason of this
                           ; dx is first used during division i.e., dx:ax / <2-byte-number>
                           ; and finally used to store the quotient

    ; word tells the CPU to read 2 bytes = 16-bit from the memory address of bdb_sectors_per_track
    ;      why 2 byte read -  https://wiki.osdev.org/FAT 
    ;         (24	0x18	2	Number of sectors per track.)
    ; this divides the 32-bit value in DX:AX by that 16-bit value 
    ; after execution of this statement dx will hold the remainder and 
    ; ax will hold the quotient
    div word [bdb_sectors_per_track]     ; ax = LBA / sectorpertrack
                                         ; dx = LBA % sectorpertrack
                                         ; 
    inc dx                               ; (LBA % sectorpertrack) + 1 = sector
    mov cx, dx                           ; cx = sector 

    xor dx, dx
    div word [bdb_heads]                 ; ax = (LBA / sectorpertrack) / heads = cylinder
                                         ; dx = (LBA / sectorpertrack) % heads = head 

    mov dh, dl                           ; dh = head 
    mov ch, al                           ; ch = cylinder (lower 8 bits)
    shl ah, 6                            ; shift left (bring bits from last 2 
                                         ; to front 2 so that we can do bitwise OR in the 
                                         ; next step)
    or cl, ah

    pop ax                               ; temporary pop the dx to ax, and then we will only take al to dl 
    mov dl, al
    pop ax
    ret 

;
; Read sector from the disk
; Parameters - 
;    - ax: LBA address
;    - cl: number of sector to read
;    - dl: driver number
;    - es:bx: memory address where to store read data
; reference method: https://stanislavs.org/helppc/int_13-2.html 
;     standard bios INT 13h, function 0x02 (read sectors)
; 
disk_read: 

    push ax 
    push bx 
    push cx 
    push dx 
    push di 

    push cx                     ; save CL, because call to the lba_to_chs override cx
    call lba_to_chs             ; LBA -> CHS, see the return contract
    pop ax                      ; AL = number of sector to read (the top of the stack which was cx)
                                ; pop the top of stack to the ax i.e., original cl value
    
    mov ah, 0x02                ; BIOS read_sector function code

    ; reading file systems off magentic media requires a fault tolerant 
    ; read loop because mechanical hardware is prone to intermittent read failures
    ; thus we will retry three time, set the di to 3
    mov di, 3                   ; init retry count to 3 

.retry:
    pusha                       ; save all the register (layer 2), we don't know what bios modifies
    stc                         ; Failsafe: set the carry flag manually, some BIOS doesn't set it
    int 0x13                    ; CAll bios disk service, if carry flag cleared (0) = success
    jnc .done                   ; jump if carry is not set(1) - (which mean it is 0) 

    ; read failed 
    popa                        ; clear layer 2 push 

    call disk_reset             ; reset the physical disk controller 
    
    dec di                      ; decrement attempt couter
    test di, di                 ; check if attempts hit 0
    jnz .retry                  ; If DI > 0, the retry

.fail: 
    ; after all attempts are exhausted
    jmp floppy_error

.done:
    popa                        ; clear layer 2 register
    
    pop di 
    pop dx 
    pop cx 
    pop bx 
    pop ax 

    ret                         

;
; reset disk controller
; Parameters:
;   dl: driver number 
; 
disk_reset:
    pusha 
    mov ah, 0 
    stc
    int 0x13
    jc floppy_error
    popa 
    ret 

msg_loading:              db 'Loading...', ENDL, 0
msg_read_failed:        db 'Read from disk failed', ENDL, 0
msg_kernel_not_found:   db 'KERNEL.BIN file not found', ENDL, 0
file_kernel_bin:        db 'KERNEL  BIN'
kernel_cluster:         dw 0 

KERNEL_LOAD_SEGMENT     equ 0x2000     ; equ means no memory allocate for the constant, kind of #define
KERNEL_LOAD_OFFSET      equ 0

times 510 - ($ - $$) db 0
dw 0AA55h

; temporary area in RAM 
buffer:
