bits 16

section _TEXT class=CODE 

;
; Algo = high/divisor; quot_high, rem_high
;      = (rem_high:low)/divisor; quot_low, rem_low
; where high = highest 32 bits of divident
;        low = lowest  32 bits of divident
; 
; final_remainder = rem_low
; final_quotient  = quot_high:quot_low
;
global _x86_div64_32
_x86_div64_32:
    ; make a new call frame
    push bp                ; save the old call frame
    mov bp, sp             ; initialize the new call frame

    ; --- save the register bx --
    push bx            ; save caller's bx
    
    ; [bp]      - saved BP
    ; [bp + 2]  - return address (small memory model - 2 bytes)
    ; [bp + 4]  - first arg  : (8 byte total): divident low 32 bits
    ; [bp + 8]  - first arg  : (8 byte total): divident high 32 bits
    ; [bp + 12] - second arg : divisor (4 byte)
    ; [bp + 16] - third arg  : final_quotient (pointer to the address)
    ; [bp + 18] - fourth arg : final_remainder (pointer to the address)

    ; --- Divide upper 32 bits --- 
    mov eax, [bp + 8]  ; upper 32 bit of the divident into EAX (little endian)
                       ; So the upper 32 bits are at the higher half of the 
                       ; memory  - eax <- upper 32 bit of divident
                       ; divisor is 8 bytes longs (64 bit), thus 
                       ; we have to do +8 
    mov ecx, [bp + 12] ; ecx <- divisor 
    xor edx, edx       ; Divident = edx:eax (64-bit), edx = 0 
    div ecx            ; quo in eax and remainder in edx (rem_high)

    ; store upper 32 bits of quotient 
    mov bx, [bp + 16]  ; get the address of the quotient and let bx point to 
                       ; that
    mov [bx + 4], eax  ; Now because points to that, we will write
                       ; the higher bits (little endian) at the bx + 4
                       ; Note that bx is small memory, so first 4 bytes are skip
                       ; and we will write at bx + 4 address
                       ; this will store the quotient higher part

    ; ---- divide the lower 32 bits ------
    mov eax, [bp + 4]   ; eax <- lower 32 bit of divident 
    div ecx             ; Divident = edx:eax, note that edx contains rem_high
                        ; quo in eax and remainder in edx

    ; store result 
    mov [bx], eax       ; The base address of the quotient we will store 
                        ; the lower bits of the quotient
    mov bx, [bp + 18]   ; Mark the bx to the address of the remainder
    mov [bx], edx       ; store teh value of edx in the address bx points to

    pop bx              ; restore caller's bx

    ; restore old call frame
    mov sp, bp 
    pop bp 
    ret
;
; int 10h, ah=0Eh
; args: character, page
;
global _x86_Video_WriteCharTeletype
_x86_Video_WriteCharTeletype:

    ; make a new call frame
    push bp                ; save the old call frame
    mov bp, sp             ; initialize the new call frame

    ; save bx
    push bx 
    ; [bp + 0] - old call frame
    ; [bp + 2] - return address (small memory model - 2 bytes)
    ; [bp + 4] - first argument (character); bytes are converted to words
    ;            (you can't push a single byte on the stack)
    ; [bp + 6] - second argument (page)

    mov ah, 0Eh
    mov al, [bp + 4]

    mov bh, [bp + 6] 

    int 10h 

    ; restore bx  (note: - Registers:
    ; EAX, ECX, EDX are saved by the caller
    ; All other saved by callee)
    pop bx 

    ; restore old call frame
    mov sp, bp 
    pop bp 
    ret

