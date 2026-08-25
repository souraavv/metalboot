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
;   
;   [bp + 0]  saved BP
;   [bp + 2]  return address
;   [bp + 4]  resetRequest pointer
;   -- High address ---
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
;   [bp + 2] return address (address of the next instruction after this call)
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
    push bx        ; Stack grows towards the lower address (bp - 2)
    push cx        ; bp - 4
    push dx        ; bp - 6
    push es        ; bp - 8

    ; BX = diskReadRequest
    mov bx, [bp + 4]

    ; ------
    ; Load drive 
    ; ------

    mov dl, [bx + 0]

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

    ; Load sector count 
    mov al, [bx + 7]

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

    mov es, [bx + 10]   ; ES 
    mov bx, [bx + 8]    ; BX

    ; ------------------------------------------------------------------------
    ; BIOS disk read - This read the sector in the memory
    ; It write to the data buffer which is essentially es:bx
    ; IN the disk.h fille you can see the far* translates to the
    ; es:bx pair
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
;     DiskParamRequest *diskParamRequest,
;     DiskParamResponse *diskParamResponse
; );
; 
; DiskParamRequest:
;   +0 uint8_t driveNumber
;
; DiskParamResponse
; +0   uint8_t  driveType
; +1   uint16_t cylinders
; +3   uint16_t sectors
; +5   uint16_t heads
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
;   ES:DI = 0000:0000
;
; Output:
;   BL = drive type
;   CH = maximum cylinder bits 0-7
;   CL = maximum sector bits 0-5
;        maximum cylinder bits 8-9 in bits 6-7
;   DH = maximum head
;   DL = number of drives
;
; Return:
;   AX = 1 -> success
;   AX = 0 -> failure
;

global _x86_Disk_GetDriveParameter
_x86_Disk_GetDriveParameter:
    ; Remember the calle convention 
    ; already added the args to the stack
    ; And it also added the return pointers
    ; Now after that its up to us

    ; We start to create the new stack frame by adjusting the 
    ; basepointer to point to the current stack pointer, and 
    ; then we will push the register which we can to save

    ; ----------------
    ; create call stack frame
    ; ----------------

    push bp          ; save the current BP
    mov bp, sp       ; And mark the BP to the new base of the stack

    ; ----------------
    ; Save callee register
    ; ----------------
    push bx 
    push cx 
    push dx 
    push si 
    push di 
    push es 

    ; ----------------
    ; Load request pointer
    ; ----------------

    mov bx, [bp + 4]

    ; Dl = request->driveNumber
    mov dl, [bx]

    ; ----------------
    ; ES:DI = 0000:0000
    ; ----------------
    xor di, di
    xor ax, ax
    mov es, ax

    ; BIOS get driver parameter
    mov ah, 08h
    int 13h

    ; BIOS set cf on failure
    jc .paramterfailure 

    ; At this point:
    ;
    ; BL = drive type
    ; CH = cylinder low 8 bits
    ; CL = cylinder high 2 bits + sector
    ; DH = maximum head
    ; DL = number of drives

    ; ----------------
    ; Load response pointer
    ; ----------------

    mov si, [bp + 6]

    ; driveType
    mov [si + 0], bl
    
    ; ----------------
    ; Reconstruct maximum cylinder
    ;
    ; CH = cylinder bits 0-7
    ; CL bits 6-7 = cylinder bits 8-9
    ; CL >> 6 keep the top 2 bits only
    ; And the move those back there place 
    ; maxCylinder =
    ;                      CH | ((CL >> 6) << 8)
    ; or maximumCylinder = CH | ((CL & 0xC0) << 2)
    ; ----------------
    xor ax, ax
    mov al, ch
    mov di, cx             ; preserve CL and do operation on di 
    and di, 00C0h          ; keep CL bits 6-7
    shr di, 6              ; move them to bits 0-1
    shl di, 8              ; move them to bits 8-9
    or ax, di 
    mov [si + 1], ax       ; Save the cylinder

    ; ----------------
    ; sectors
    ;
    ; CL bits 0-5 = maximum sector number
    ; ----------------

    mov al, cl     ; hold lower bits 
    and al, 3Fh    ; 0011 1111  (keep the 0 - 5)
    xor ah, ah     ; unset the higher bits
    mov [si + 3], ax

    ; --------
    ; heads
    ; DH = maximum head number
    ; ----------
    xor ax, ax 
    mov al, dh 
    mov [si + 5], ax 

    ; -- Success ---
    xor ax, ax 
    mov ax, 1 
    jmp .parameterdone

.paramterfailure:
    xor ax, ax 

.parameterdone:
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    
    ; restore the stack frame
    mov sp, bp 
    pop bp 
    ret
