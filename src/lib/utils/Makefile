BUILD_DIR    ?= ../../../build
WATCOM_ROOT  ?= /Users/sourav/Downloads/open-watcom-v2/rel
WATCOM_BIN   ?= $(WATCOM_ROOT)/armo64
CC16         ?= $(WATCOM_BIN)/wcc
ASM          ?= nasm

CFLAGS16     ?= -4 -d3 -ms -wx -zl -zq -s -za99 -i=$(abspath $(UTIL_DIR)/headers)
ASMFLAGS     ?= -f obj

BUILD_UTILS  := $(BUILD_DIR)/lib/utils
BUILD_C      := $(BUILD_UTILS)/c
BUILD_ASM    := $(BUILD_UTILS)/asm

SOURCE_C     := $(wildcard src/*.c)
OBJECT_C     := $(patsubst src/%.c, $(BUILD_C)/%.obj, $(SOURCE_C))

SOURCE_ASM   := $(wildcard asm/*.asm)
OBJECT_ASM   := $(patsubst asm/%.asm, $(BUILD_ASM)/%.obj, $(SOURCE_ASM))

.PHONY: all utils always clean

all: utils 

utils: $(OBJECT_C) $(OBJECT_ASM)

$(BUILD_C)/%.obj: src/%.c | always 
	WATCOM="$(WATCOM_ROOT)" $(CC16) $(CFLAGS16) -fo=$@ $<

$(BUILD_ASM)/%.obj: asm/%.asm | always 
	$(ASM) $(ASMFLAGS) -o $@ $<

always:
	mkdir -p $(BUILD_C)
	mkdir -p $(BUILD_ASM)

clean: 
	rm -rf $(BUILD_UTILS)