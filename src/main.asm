org 0x7C00
bits 16

%define ENDL 0x0D, 0x0A

start: 
    jmp main           ; ensures the main is still the entry point 

;
; Print a string to the screen 
; Params:
;     - ds: si points to the string 
;            from the data segment it start reading frmo si 
;
puts: 
    ; save the register we will modify 
    push si
    push ax 

.loop:
    lodsb              ; load next character in al and increment si by # of byte loaded
    and al, al          ; verfiy if next character is null 
    jz .done           ; previous instruction return 0 then jump 
    
    mov ah, 0x0e       ; Bios will use this to know what, kind of function identifier
    mov bh, 0          ; print_char(AL, page=bh), move_cursor
    int 0x10           ; calls BIOS 

    jmp .loop          ; again till there are words

.done:
    pop ax             ; restore the value of ax 
    pop si             ; restore the value of si 
    ret

main:
    ; setup data segment 
    mov ax, 0
    mov ds, ax         ; can't write directly to ds, es 
    mov es, ax 

    ; setup stack 
    mov ss, ax         ; setup the stack segment to 0 
    mov sp, 0x7C00     ; stack pointer to the beginning of our program

    ; print message 
    mov si, msg_hello
    call puts

.halt:
    hlt
    jmp .halt

msg_hello: 
    db 'Hello world!', ENDL, 0

times 510 - ($ - $$) db 0
dw 0AA55h