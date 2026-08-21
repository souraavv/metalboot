BUILD_DIR  ?= build/
ASM        ?= nasm 
KERNEL_BIN ?= $(BUILD_DIR)/kernel.bin

.PHONY: all kernel clean 

all: kernel 

kernel: $(KERNEL_BIN)

$(KERNEL_BIN):
	$(ASM) main.asm -f bin -o $@

clean:
	rm -f $(KERNEL_BIN)
