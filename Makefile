# assembler
ASM := nasm

# directory
SRC_DIR=src
BUILD_DIR=build
BOOTLOADER_SRC := $(SRC_DIR)/main.asm
BOOTLOADER_BIN := $(BUILD_DIR)/bootloader.bin
FLOPPY_IMAGE  := $(BUILD_DIR)/boot.img
FLOPPY_SIZE := 1440k # 2880 sectors in real floopy

run: all
	qemu-system-i386 -fda $(FLOPPY_IMAGE)

all: $(FLOPPY_IMAGE)

$(BOOTLOADER_BIN): $(BOOTLOADER_SRC)
	$(ASM) -f bin $< -o $@

$(FLOPPY_IMAGE): $(BOOTLOADER_BIN)
	cp $< $@
	truncate -s $(FLOPPY_SIZE) $@

clean:
	rm -f $(BUILD_DIR)/*
