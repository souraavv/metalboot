bits 16

section _TEXT class=CODE 

;
; x86_Disk_Reset
; --------------
; bool _cdecl x86_Disk_Reset(DiskResetRequest *resetRequest);
;
; DiskResetRequest:
;   +0  uint8_t driveNumber
;
; Stack:
;   [bp + 0]  saved BP
;   [bp + 2]  return address
;   [bp + 4]  resetRequest pointer
;
; BIOS INT 13h / AH=00h
;
; Input:
;   AH = 00h
;   DL = drive number
;
; Return:
;   AX = 1 -> success
;   AX = 0 -> failure
;
global _x86_Disk_Reset
_x86_Disk_Reset:
    ; create call frame
    push bp 
    mov bp, sp 

    ; save the register modified by this function 
    push bx 

    ; bx = resetRequest 
    mov bx, [bp + 4]

    ; DL = resetRequest->driveNumber
    mov dl, [bx] 

    ; BIOS disk reset
    mov ah, 00h
    int 13h 

    ; BIOS set CF (carry flag on failure)
    jc .reset_failure

.reset_success:
    mov ax, 1 
    jmp .reset_done 

.reset_failure:
    xor ax, ax 

.reset_done: 
    pop bx 

    ; restore call frame 
    mov sp, bp 
    pop bp 
    ret

;
;
; x86_Disk_Read
; ---------------
;
; bool _cdecl x86_Disk_Read(DiskReadRequest *diskReadRequest);
;
; DiskReadRequest:
;
;   +0  uint8_t  drive
;   +1  uint16_t cylinder
;   +3  uint16_t head
;   +5  uint16_t sector
;   +7  uint8_t  count
;   +8  uint8_t far *buffer
;
; Far pointer: Segment # is also used in the far pointer, unlike near, where
;               only offset matters
;
;   +8  uint16_t offset
;   +10 uint16_t segment
; 
; Stack
;   [bp + 0] saved BP 
;   [bp + 2] return address
;   [bp + 4] diskReadResquest pointer 
; 
; BIOS INT 13h/ AH = 02h
; 
; Input
;  AH = 02
;  AL = number of sectors
;  CH (total 10 bits) = cylinder bits 0 - 7
;  CL (total 6 bits)  = sector bits  0 - 5, the 6-7 are teh cylinder bit 8-9
;  DH = head
;  DL = drive
;  ES:BX = destination buffer
;
; Return
;  AX = 1 (sucess)
;  AX = 0 (failure)
; 
global _x86_Disk_Read
_x86_Disk_Read:
    ; create call frame
    push bp 
    mov bp, sp 

    ; Save register modified by this func 
    push bx 
    push cx 
    push dx 
    push es 

    ; BX = diskReadRequest
    mov bx, [bp + 4] 


    ; ------
    ; Load drive 
    ; ------

    mov dl, [bx + 0]

    ; Load sector count 
    mov al, [bx + 7]

    ; ----------------------------
    ; Load cylinder
    ;
    ; cylinder is uint16_t:
    ;
    ;   bits 0-7  -> CH
    ;   bits 8-9  -> CL bits 6-7
    ; ----------------------------


    mov ax, [bx + 1]   ; ax = ah:al

    ; low 8-bit cylinder -> CH 
    mov ch, al         ; ch (15-8) contains (7-0) bits of ax
    ; There are two more bits remainig 
    ; let get them from ah 
    mov cl, ah        ; Get cylinder bits 8-15
    and cl, 03h       ; keep only bits 8-9, 03h = 0000 0011

    shl cl, 6         ; and shift those 8-9 bits to the 

    ; ------------------------
    ; Load sector
    ;
    ; BIOS uses only bits 0-5 of CL for the sector number.
    ; So we have to extract the 6 bits of the sector number and put
    ; that to the cl 
    ; -------------------------

    mov ax, [bx + 5]  ; [bx + 5] contains the sector 
    and al, 3Fh       ; keep the lower 0011 1111 from al which is sector
    or cl, al         ; cl = cl or al 

    ; Load head

    mov ax, [bx + 3]
    mov dh, al 

    ; ------------------------------------------------------------------------
    ; Load far buffer pointer
    ;
    ; buffer:
    ;   +8  offset
    ;   +10 segment
    ;
    ; BIOS expects:
    ;   ES:BX = buffer
    ; ------------------------------------------------------------------------

    mov bx, [bx + 8]    ; Bx now points to the buffer offset
    mov es, [bp + 4]    ; only placeholder (read next para)

    ;
    ; We cannot use BX here to obtain the segment because BX now
    ; contains the buffer offset.
    ;
    ; Therefore reload the request pointer through another register.
    ; Remember this note:
    ; ---------------------
    ; Far pointer: Segment # is also used in the far pointer, unlike near, where
    ;               only offset matters
    ;
    ;   +8  uint16_t offset
    ;   +10 uint16_t segment
    ; 
    mov si, [bp + 4]    ; si points to the disk read request
    mov es, [si + 10]   ; at the 10th offset we have the ES 

    ; ------------------------------------------------------------------------
    ; BIOS disk read
    ; ------------------------------------------------------------------------
    mov ah, 02h
    int 13h

    ; BIOS set CF on failure, else not
    jc .read_failure

.read_success:
    mov ax, 1
    jmp .read_done
.read_failure:
    xor ax, ax      ; set ax = 0, remember the safest way to do that is xor

.read_done:
    pop es 
    pop dx 
    pop cx 
    pop bx 

    ; restore call frame 
    mov sp, bp 
    pop bp 
    ret 

;
;
; x86_Disk_GetDriveParameter
; --------------------------
;
; bool _cdecl x86_Disk_GetDriveParameter(
;     DriveParamRequest *diskParamRequest,
;     DriveParamResponse *diskParamResponse
; );
; 
; DriveParamRequest:
;   +0 uint8_t driveNumber
;
; DriveParamResponse:
;   +0 uint8_t  *driveType
;   +2 uint16_t *cylinders
;   +4 uint16_t *sectors
;   +6 uint16_t *heads
;
; Stack:
;
;   [bp + 0]  saved BP
;   [bp + 2]  return address
;   [bp + 4]  diskParamRequest
;   [bp + 6]  diskParamResponse
; 
; BIOS INT 13h / AH=08h
;
; Input:
;   AH = 08h
;   DL = drive number
;
; Output:
;   CH = cylinder low 8 bits
;   CL = sector bits 0-5
;        cylinder bits 8-9 in bits 6-7
;   DH = maximum head number
;   DL = number of drives
;
; Return:
;   AX = 1 -> success
;   AX = 0 -> failure
;

global _x86_Disk_GetDriveParameter
_x86_Disk_GetDriveParameter:

    ; create call frame
    push bp 
    mov bp, sp 

    ; Save registers modified by this function 
    push bx 
    push cx 
    push dx 
    push si 
    push di 
    push es 

    ; Load request pointer
    mov bx, [bp + 4]

    ; Dl = request->driveNumber
    mov dl, [bx]

    ; BIOS get driver parameter
    mov ah, 08h
    int 13h

    ; BIOS set cf on failure
    jc . paramterfailure 

    ; save BIOS result before using registers for C pointers

    ;
    ; Cylinder:
    ;
    ;   CH     = cylinder bits 0-7
    ;   CL 7-6 = cylinder bits 8-9
    ;
    ; Reconstruct:
    ;
    ;   cylinder = CH | ((CL >> 6) << 8)
    ;
    mov al, ch 
    xor ah, ah 

    mov si, ax       ; SI is now low bit of cyliner 

    mov al, cl 
    and al, 0C0h     ; 1100000
    mov cl, 6 
    shr al, cl 
    
    xor ah, ah 
    shl ax, 8

    or ax, si        ; AX = cylinder 
    push ax          ; save cylinder 



.paramterfailure:



