BUILD_DIR    ?= build
ASM          ?= nasm
ASM_FLAG     ?= -f obj
STAGE2_BIN   ?= $(BUILD_DIR)/stage2.bin
WATCOM_ROOT  ?= /Users/sourav/Downloads/open-watcom-v2/rel
WATCOM_BIN   ?= $(WATCOM_ROOT)/armo64
CC16         ?= $(WATCOM_BIN)/wcc
LD16         ?= $(WATCOM_BIN)/wlink
CFLAGS16     ?= -4 -d3 -ms -wx -zl -zq -s

BUILD_STAGE2 := $(BUILD_DIR)/stage2
BUILD_C      := $(BUILD_STAGE2)/c
BUILD_ASM    := $(BUILD_STAGE2)/asm

SOURCE_C     := $(wildcard *.c)
SOURCE_ASM   := $(wildcard *.asm)

OBJECT_C     := $(patsubst %.c, $(BUILD_C)/%.obj, $(SOURCE_C))
OBJECT_ASM   := $(patsubst %.asm, $(BUILD_ASM)/%.obj, $(SOURCE_ASM))

.PHONY: all stage2 clean always

all: stage2

stage2: $(STAGE2_BIN)

$(STAGE2_BIN): $(OBJECT_C) $(OBJECT_ASM)
	WATCOM="$(WATCOM_ROOT)" $(LD16) NAME $@ FILE \{ $^ \} \
			OPTION MAP=$(BUILD_DIR)/stage2.map @linker.lnk 

$(BUILD_C)/%.obj: %.c | always 
	WATCOM="$(WATCOM_ROOT)" $(CC16) $(CFLAGS16) -fo=$@ $<

$(BUILD_ASM)/%.obj: %.asm | always 
	$(ASM) $(ASM_FLAG) -o $@ $<

always:
	mkdir -p $(BUILD_C)
	mkdir -p $(BUILD_ASM)

clean:
	rm -f $(STAGE2_BIN)
	rm -rf $(BUILD_STAGE2)