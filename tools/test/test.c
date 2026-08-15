void _cdecl cstart(void) {
    volatile unsigned char *vga = (unsigned char *)0xB8000;
    *vga = 'X';
}
