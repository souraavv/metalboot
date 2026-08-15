bits 16

section _TEXT class=CODE 

global _x86_Video_WriteCharTeletype

;
; int 10h, ah=0Eh
; args: character, page
;
_x86_Video_WriteCharTeletype:

    ; make a new call frame
    push bp                ; save the old call frame
    mov bp, sp             ; initialize the new call frame

    ; [bp + 0] - old call frame
    ; [bp + 2] - return address (small memory model - 2 bytes)
    ; [bp + 4] - first argument (character); bytes are converted to words
    ;            (you can't push a single byte on the stack)
    ; [bp + 6] - second argument (page)

    mov ah, 0Eh
    mov al, [bp + 4]
    ; save bx
    push bx 
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

