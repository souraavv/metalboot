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
    push si            ; SI is set to the start address, we will read starting this
    push ax            ; save initial value of ax which is 0
    push bx 
    push cx

.loop:
    lodsb              ; load next character in al and increment si by # of byte loaded
    and al, al         ; verfiy if next character is null
    jz .done           ; previous instruction return 0 then jump 
    
    push ax            ; save the character

    mov cx, 1
    call get_color

    pop dx             ; restore saved AX into DX
    mov al, dl         ; restore only the character

    call setup_in10h_to_write_character

    int 0x10           ; calls BIOS

    call set_position_to_next_row
    jmp .loop          ; again till there are words

.done:
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
    ; setup data segment 
    mov ax, 0          ; al and ah are higher and lower 8 bits of ax
    mov ds, ax         ; can't write directly to ds, es. Set the DS to 0
    mov es, ax         ; set es to 0 (Extra segment)

    ; setup stack 
    mov ss, ax         ; setup the stack segment to 0 
    mov sp, 0x7C00     ; stack pointer to the beginning of our program

    ; print message 
    mov si, msg_hello  ; si holds the start address of msg_hello
    call puts

.halt:
    hlt
    jmp .halt

msg_hello: 
    db 'Hello world!', ENDL, 0

colors:
    db 0x0A, 0x0B, 0x0C, 0x0D

color_index:
    db 0

times 510 - ($ - $$) db 0
dw 0AA55h