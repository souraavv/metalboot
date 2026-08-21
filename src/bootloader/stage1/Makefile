BUILD_DIR  ?= build/
ASM        ?= nasm
STAGE1_BIN ?= $(BUILD_DIR)/stage1.bin

.PHONY: all stage1 clean

all: stage1

stage1: $(STAGE1_BIN)

$(STAGE1_BIN):
	$(ASM) boot.asm -f bin -o $(STAGE1_BIN)

clean:
	rm -f $(STAGE1_BIN)