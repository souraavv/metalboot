org 0x0
bits 16

%define ENDL 0x0D, 0x0A

start: 
    mov si, msg_hello  ; si holds the start address of msg_hello
    call puts

.halt:
    cli 
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


msg_hello: 
    db 'Hello world from KERNEL!', ENDL, 0

