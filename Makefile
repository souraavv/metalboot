# assembler
ASM := nasm

# OS util
MFORMAT := mformat 
DD := dd
MCOPY := mcopy

# directory
SRC_DIR=src
BUILD_DIR=build
BOOTLOADER_DIR := $(SRC_DIR)/bootloader
KERNEL_DIR := $(SRC_DIR)/kernel
BOOTLOADER_SRC := $(BOOTLOADER_DIR)/boot.asm
KERNEL_SRC := $(KERNEL_DIR)/main.asm 
BOOTLOADER_BIN := $(BUILD_DIR)/bootloader.bin
KERNEL_BIN := $(BUILD_DIR)/kernel.bin
FLOPPY_IMAGE  := $(BUILD_DIR)/floppy_boot.img

# consants
FLOPPY_SIZE := 1440 # 2880 sectors in real floopy
FLOPPY_SECTOR_SIZE := 512
FLOPPY_BLOCKS := 2880 
FAT_12 := 12

.PHONY: run all clean always floppy_image

run: floppy_image
	qemu-system-i386 -drive file=build/floppy_boot.img,if=floppy,format=raw

floppy_image: $(FLOPPY_IMAGE)

# 1. Create an empty floppy image
# 2. Write a fat12 filesystem 
# 3. Copy the bootloader.bin to the floppy image 
# 4. Although now we can mount and copy files, but that just move your image generation
#    to require elivated privledge.  A simple way is use mcopy command
$(FLOPPY_IMAGE): bootloader kernel 
	$(DD) if=/dev/zero of=$(FLOPPY_IMAGE) bs=$(FLOPPY_SECTOR_SIZE) count=$(FLOPPY_BLOCKS)
	$(MFORMAT) -i $(FLOPPY_IMAGE) -f $(FLOPPY_SIZE) -v BOOT ::
	$(DD) if=$(BOOTLOADER_BIN) of=$(FLOPPY_IMAGE) conv=notrunc
	$(MCOPY) -i $(FLOPPY_IMAGE) $(KERNEL_BIN) ::kernel.bin

bootloader: $(BOOTLOADER_BIN)

$(BOOTLOADER_BIN): $(BOOTLOADER_SRC) always
	$(ASM) -f bin $< -o $@

kernel: $(KERNEL_BIN) 

$(KERNEL_BIN): $(KERNEL_SRC) always
	$(ASM) -f bin $< -o $@

clean:
	rm -f $(BUILD_DIR)/*
