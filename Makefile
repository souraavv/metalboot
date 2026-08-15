# --- Assembler ----
ASM := nasm
# -- Compiler ----
CC := gcc
# --- OS util ---
MFORMAT := mformat 
DD := dd
MCOPY := mcopy
QEMU := qemu-system-i386

# --- Toolchain Configuration ---
# set the root of watcom
WATCOM_ROOT := /Users/sourav/Downloads/open-watcom-v2/rel

WATCOM_BIN  := $(WATCOM_ROOT)/armo64
CC16 := $(WATCOM_BIN)/wcc
LD16 := $(WATCOM_BIN)/wlink

# --- Compiler Flags ---
CFLAGS16 = -4 -d3 -ms -wx -zl -zq -s

# -- Directories --
SRC_DIR := src
BUILD_DIR := build
TOOLS_DIR := tools
BOOTLOADER_DIR := $(SRC_DIR)/bootloader
STAGE1_DIR := $(BOOTLOADER_DIR)/stage1 
STAGE2_DIR := $(BOOTLOADER_DIR)/stage2 
KERNEL_DIR := $(SRC_DIR)/kernel

# -- Source code --
STAGE1_SRC := $(STAGE1_DIR)/boot.asm
STAGE2_SRC := $(STAGE2_DIR)/main.asm
KERNEL_SRC := $(KERNEL_DIR)/main.asm

# --- Binary paths --
STAGE1_BIN := $(BUILD_DIR)/stage1.bin
STAGE2_BIN := $(BUILD_DIR)/stage2.bin
KERNEL_BIN := $(BUILD_DIR)/kernel.bin
BOOTLOADER_BIN := $(BUILD_DIR)/bootloader.bin

# --- Image ---
FLOPPY_IMAGE  := $(BUILD_DIR)/floppy_boot.img


# -- Consants ---
FLOPPY_SIZE := 1440 # 2880 sectors in real floopy
FLOPPY_SECTOR_SIZE := 512
FLOPPY_BLOCKS := 2880 
FAT_12 := 12

.PHONY: run all clean always floppy_image stage1 stage2

all: floppy_image tools_fat 

# 
# Spawn the QEMU with the image
# 
run: floppy_image
	$(QEMU) -drive file=$(FLOPPY_IMAGE),if=floppy,format=raw

#
# Floppy image
# 
floppy_image: $(FLOPPY_IMAGE)

# 1. Create an empty floppy image
# 2. Write a fat12 filesystem 
# 3. Copy the stage1.binary to the floppy image 
# 4. Although now we can mount and copy files, but that just move your image generation
#    to require elivated privledge.  A simple way is use mcopy command
$(FLOPPY_IMAGE): bootloader kernel 
	$(DD) if=/dev/zero of=$(FLOPPY_IMAGE) bs=$(FLOPPY_SECTOR_SIZE) count=$(FLOPPY_BLOCKS)
	$(MFORMAT) -i $(FLOPPY_IMAGE) -f $(FLOPPY_SIZE) -v BOOT ::
	$(DD) if=$(STAGE1_BIN) of=$(FLOPPY_IMAGE) conv=notrunc
	$(MCOPY) -i $(FLOPPY_IMAGE) $(STAGE2_BIN) "::stage2.bin"
	$(MCOPY) -i $(FLOPPY_IMAGE) $(KERNEL_BIN) "::kernel.bin"
	$(MCOPY) -i $(FLOPPY_IMAGE) test.txt "::test.txt"

# ----------
# Bootloader
# ----------
bootloader: stage1 stage2 

stage1: $(STAGE1_BIN)

$(STAGE1_BIN): always 
	$(MAKE) -C $(STAGE1_DIR) BUILD_DIR=$(abspath $(BUILD_DIR)) \
			STAGE1_BIN=$(abspath $(STAGE1_BIN))

stage2: $(STAGE2_BIN)

$(STAGE2_BIN): always 
	$(MAKE) -C $(STAGE2_DIR) BUILD_DIR=$(abspath $(BUILD_DIR)) \
			STAGE2_BIN=$(abspath $(STAGE2_BIN)) \
			STAGE2_DIR=$(abspath $(STAGE2_DIR)) \
			WATCOM_ROOT=$(abspath $(WATCOM_ROOT)) \
			WATCOM_BIN=$(abspath $(WATCOM_BIN)) \
			CFLAGS16="$(CFLAGS16)"

tools_fat: $(BUILD_DIR)/tools/fat

$(BUILD_DIR)/tools/fat: always $(TOOLS_DIR)/fat/fat.c
	mkdir -p $(BUILD_DIR)/tools
	$(CC) -g -o $@ $(TOOLS_DIR)/fat/fat.c

# ----------
# Kernel
# ----------
kernel: $(KERNEL_BIN) 

$(KERNEL_BIN): always
	$(MAKE) -C $(KERNEL_DIR) BUILD_DIR=$(abspath $(BUILD_DIR)) \
			KERNEL_BIN=$(abspath $(KERNEL_BIN))

# ----------
# Always
# ----------
always: 
	mkdir -p $(BUILD_DIR)

# ----------
# Clean
# ----------
clean:
	$(MAKE) -C $(STAGE1_DIR) BUILD_DIR=$(abspath $(BUILD_DIR)) STAGE1_BIN=$(STAGE1_BIN) clean 
	$(MAKE) -C $(STAGE2_DIR) BUILD_DIR=$(abspath $(BUILD_DIR)) clean 
	$(MAKE) -C $(KERNEL_DIR) BUILD_DIR=$(abspath $(BUILD_DIR)) clean
	rm -rf $(BUILD_DIR)/*
	rm -rf $(BUILD_DIR)
