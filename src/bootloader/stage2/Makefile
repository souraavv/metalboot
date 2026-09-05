BUILD_DIR    ?= build
ASM          ?= nasm
ASM_FLAG     ?= -f obj
STAGE2_BIN   ?= $(BUILD_DIR)/stage2.bin
WATCOM_ROOT  ?= /Users/sourav/Downloads/open-watcom-v2/rel
WATCOM_BIN   ?= $(WATCOM_ROOT)/armo64
CC16         ?= $(WATCOM_BIN)/wcc
LD16         ?= $(WATCOM_BIN)/wlink
CFLAGS16     ?= -4 -d3 -ms -wx -zl -zq -s -za99 -zp1 -i=$(abspath $(UTIL_DIR)/headers)

BUILD_STAGE2 := $(BUILD_DIR)/stage2
BUILD_C      := $(BUILD_STAGE2)/c
BUILD_ASM    := $(BUILD_STAGE2)/asm

# 1. Dynamically find all .c and .asm files in the stage2 directory
SOURCES_C   := $(wildcard *.c)
OBJECTS_C   := $(patsubst %.c, $(BUILD_DIR)/stage2/c/%.obj, $(SOURCES_C))

SOURCES_ASM := $(wildcard *.asm)
OBJECTS_ASM := $(patsubst %.asm, $(BUILD_DIR)/stage2/asm/%.obj, $(SOURCES_ASM))

# 2. Define the paths to the utility objects
UTILS_C_DIR   := $(BUILD_DIR)/lib/utils/c
UTILS_ASM_DIR := $(BUILD_DIR)/lib/utils/asm

.PHONY: all stage2 clean always

all: stage2

stage2: $(STAGE2_BIN)

# 3. The Linker Target
$(STAGE2_BIN): $(OBJECTS_C) $(OBJECTS_ASM) always
	WATCOM="$(WATCOM_ROOT)" $(LD16) NAME $@ \
		FILE { $(OBJECTS_C) $(OBJECTS_ASM) $(UTILS_C_DIR)/*.obj $(UTILS_ASM_DIR)/*.obj } \
		OPTION MAP=$(BUILD_DIR)/stage2.map @linker.lnk 

# 4. The Compilation Rules for Stage 2
$(BUILD_DIR)/stage2/c/%.obj: %.c | always 
	WATCOM="$(WATCOM_ROOT)" $(CC16) $(CFLAGS16) -fo=$@ $<

$(BUILD_DIR)/stage2/asm/%.obj: %.asm | always 
	$(ASM) -f obj -o $@ $<

always:
	mkdir -p $(BUILD_C)
	mkdir -p $(BUILD_ASM)

clean:
	rm -f $(STAGE2_BIN)
	rm -rf $(BUILD_STAGE2)