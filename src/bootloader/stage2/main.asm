bits 16                        ; tells assembler that we are writing 16-bit code

section _ENTRY class=CODE      ; tell nasm to place the stuff we will write 
                               ; next in the _ENTRY section
                               ; In general, all the binary files have headers
                               ; which is refer by OS to figure the place
                               ; where entry of code will start.. and many more
                               ; we are generting raw binary, thus we have to
                               ; specify the linker script to explicity command
                               ; the linker - Take every thing from the
                               ; _ENTRY section and glue it at the absolute
                               ; begin of the final .bin file, before anything
                               ; else. This gaurantees your assembly setup
                               ; routine is the very first thing CPU execute

extern _cstart_                ; external symbol which will be the entry point
                               ; in C. The keyword 'extern' tells the NASM
                               ; Do not worry about calculating the memory
                               ; address for this call right now (call _cstart_)
                               ; I promise that linker will find `_cstart_`
                               ; in another file and fill the correct address
                               ; for you
global entry                   ; export the entry symbol so that it is visible
                               ; outside this file using global directive 
                               ; when NASM generate the object file. Inside
                               ; the object file there is a Symbol table - a
                               ; list of all memory addresses (labels) and 
                               ; their names 
                               ; By default any label you write in assembly
                               ; e.g., entry: is strictly private to that file
                               ; We need to make this global, because we need
                               ; to tell the linker where the program is suppose
                               ; to start executing (e.g., START entry) 
                               ; the linker looks at the compiled C files and
                               ; assembled files and searches for this symbol
                               ; It searches the their public symbol table, if
                               ; you don't use the global, then it won't be able
                               ; to find the symbol.

entry:
    ; ------------------------------------------------------------------------
    ; Step 1. Clear all the interrupts
    ; Step 2. Setup the ds and ss (data segment and stack segment at same)
    ; Step 3. Reset the stack pointer used by ss, and bp used by ds
    ; Step 4. Trigger the cstart symbol; This method also expect the args
    ;         so ensure the dl contains the value (stage 1 must ensure that)
    ; Step 5. Halt
    ; ------------------------------------------------------------------------
    cli                        ; clear the interrupt flag - disable hardware
                               ; interrupts, this prevent CPU to interrupt
                               ; during critical piece of code 
    mov ax, ds                 ; we are using small memory model, so data 
                               ; and stack segment should be same, as they are
                               ; already setup by the stage1, we simply copy 
                               ; the ds address to the ss
    mov ss, ax                 ; stack segment register now points same as ds
    mov sp, 0                  ; Rest the based and stack pointer to 0 (used by 
                               ; ss) Since they grow downwards, they will wrap 
                               ; at the end of the segment (64kB = 16bit)
                               ; so we will keep our stage2 < 60KB
    mov bp, sp                 ; set base pointer to 0 (used by the ds)
    sti                        ; again setup the interrupt flag instruction
    
    xor dh, dh 
    push dx                    ; expect boot drive in dl, send it arg to cstart
                               ; function 
    call _cstart_

    cli 
    hlt                        ; halt the system, if we return from the C 

                              
