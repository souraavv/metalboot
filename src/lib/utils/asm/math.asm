bits 16

section .text

global __U4M
global __U4D

; ----------------------------------------------------
; __U4M: Unsigned 32-bit Multiplication (DX:AX * CX:BX)
; Result stored in DX:AX
; ----------------------------------------------------
__U4M:
    ; 1. Load 32-bit operand 1 into EAX
    shl edx, 16
    mov dx, ax
    mov eax, edx

    ; 2. Load 32-bit operand 2 into ECX
    shl ecx, 16
    mov cx, bx

    ; 3. Perform 32-bit multiply (EAX = EAX * ECX)
    mul ecx

    ; 4. Unpack 32-bit result from EAX back into DX:AX
    mov edx, eax
    shr edx, 16
    ret

; ----------------------------------------------------
; __U4D: Unsigned 32-bit Division (DX:AX / CX:BX)
; Quotient stored in DX:AX, Remainder stored in CX:BX
; ----------------------------------------------------
__U4D:
    ; 1. Load 32-bit dividend into EAX
    shl edx, 16
    mov dx, ax
    mov eax, edx

    ; 2. Load 32-bit divisor into EBX
    shl ecx, 16
    mov cx, bx
    mov ebx, ecx

    ; 3. Perform 32-bit division
    xor edx, edx      ; Clear high 32 bits for division
    div ebx           ; EAX = Quotient, EDX = Remainder

    ; 4. Unpack Remainder from EDX into CX:BX
    mov ebx, edx
    mov ecx, ebx
    shr ecx, 16

    ; 5. Unpack Quotient from EAX into DX:AX
    mov edx, eax
    shr edx, 16
    ret