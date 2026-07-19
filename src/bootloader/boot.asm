org 0x7C00
bits 16

%define ENDL 0x0D, 0x0A

;
; FAT12 header 
; BPB (BIOS parameter block)
; source: https://wiki.osdev.org/FAT
;

; starting offset 0(0x00) to 32 (0x20)
jmp short start                            ; jmpm short <entry-point>
nop                                        ; NOP
bdb_oem_identifier:        db 'MSWIN4.1'   
bdb_bytes_per_sector:      dw 512
bdb_sectors_per_cluster:   db 1
bdb_reserved_sectors:      dw 1
bdb_fat_count:             db 2
bdb_dir_entries_count:     dw 0E0h 
bdb_total_sectors:         dw 2880         ; 2880 * 512 = 1.44MB
bdb_media_descriptor_type: db 0F0h         ; F0 = 3.5' floppy disk 
bdb_sectors_per_fat:       dw 9            ; 9 sector / fat
bdb_sectors_per_track:     dw 18           ; size in byte = 2 
bdb_heads:                 dw 2
bdb_hidden_sectors:        dd 0
bdb_large_sector_count:    dd 0

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
    jmp main           ; ensures the main is still the entry point 

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
; get color
;
get_color:
    push si
    push ax

    xor ax, ax
    mov al, [color_index]

    mov si, colors
    add si, ax

    mov bl, [si]

    inc byte [color_index]
    cmp byte [color_index], 3
    jb .done

    mov byte [color_index], 0

.done:
    pop ax
    pop si
    ret

; 
; set the INT 10h to write character and attribute to 
; at the cursor position 
;    input ax, bx 
; 

setup_in10h_to_write_character: 
    mov ah, 0x09
    mov bh, 0
    ret

;
;  set the cursor position to the next row
;     input 
;
set_position_to_next_row:  
    ; Gets the cursor position
    mov ah, 0x03
    mov bh, 0
    int 0x10           ; dh = row, dl = column
    inc dl             ; increment dl 

    ; set the new position 
    mov ah, 0x02
    mov bh, 0
    int 0x10 
    ret

main:
    ; setup data segment to absolute 0
    xor ax, ax         ; al and ah are higher and lower 8 bits of ax, set ax = 0
    mov ds, ax         ; can't write directly to ds, es. Set the DS to 0
    mov es, ax         ; set es to 0 (Extra segment)

    ; setup stack 
    mov ss, ax         ; setup the stack segment to 0 
    mov sp, 0x7C00     ; stack pointer to the beginning of our program (or below our bootloader address)
                       ; stack grown from 0x7C00 towards 0

    ; read something from the floppy disk 
    ; BIOS should set the DL to driver number 
    mov [ebr_drive_number], dl 
    mov ax, 1          ; LBA = 1, means second sector on the disk or TARGET LBA sector = 1
    mov cl, 1          ; Read 1 sector
    mov bx, 0x7E00     ; Load address directly after bootloader footfrints
                       ; 0x7E00 = 0x7C00 + sector (512byte = 0x0200) 
    call disk_read

    ; print message 
    mov si, msg_hello  ; si holds the start address of msg_hello
    call puts

    cli                ; disable interrupt that way cpu cant' get out of "halt" state
    hlt 

;
; error handlers
;
floppy_error: 
    mov si, msg_read_failed
    call puts 
    jmp wait_key_and_reboot

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

    ; word tells the CPU to read 2 bytes = 16-bit from the memory address of bdb_sector_per_track
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
    int 13h
    jc floppy_error
    popa 
    ret 

msg_hello: 
    db 'Hello world!', ENDL, 0
msg_read_failed:
    db 'Read from disk failed', ENDL, 0

colors:
    db 0x0A, 0x0A, 0x0A, 0x0A

color_index:
    db 0

times 510 - ($ - $$) db 0
dw 0AA55h