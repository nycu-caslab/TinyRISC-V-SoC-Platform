# =========================================================================
# hw/boot/Makefile
# =========================================================================
TARGET_PREFIX := riscv64-unknown-elf
CC      = $(TARGET_PREFIX)-gcc
OBJCOPY = $(TARGET_PREFIX)-objcopy

BUILD_DIR ?= ../../build/boot

ARCH_FLAGS   := -march=rv32imf -mabi=ilp32f
COMMON_FLAGS := $(ARCH_FLAGS) -Os -g -ffunction-sections -fdata-sections -fno-builtin
LDFLAGS      := $(ARCH_FLAGS) -T linker_bram.ld -nostartfiles -Wl,--gc-sections

SRCS := start.s 
OBJS := $(patsubst %.s,$(BUILD_DIR)/%.o,$(filter %.s,$(SRCS)))
OBJS += $(patsubst %.c,$(BUILD_DIR)/%.o,$(filter %.c,$(SRCS)))

all: $(BUILD_DIR)/boot.hex $(BUILD_DIR)/bootloader.coe

$(BUILD_DIR)/boot.hex: $(BUILD_DIR)/bootloader.bin
	@python3 -c "import struct; data=open('$<','rb').read(); data += b'\x00' * ((4 - len(data) % 4) % 4); words=[struct.unpack('<I', data[i:i+4])[0] for i in range(0, len(data), 4)]; print('\n'.join(['%08x'%w for w in words]))" > $@
	@echo ">> HEX file generated at $@"

$(BUILD_DIR)/bootloader.coe: $(BUILD_DIR)/bootloader.bin
	@python3 -c "import struct; data=open('$<','rb').read(); data += b'\x00' * ((4 - len(data) % 4) % 4); words=[struct.unpack('<I', data[i:i+4])[0] for i in range(0, len(data), 4)]; print('memory_initialization_radix=16;\nmemory_initialization_vector=\n' + ',\n'.join(['%08x'%w for w in words]) + ';')" > $@
	@echo ">> COE file generated at $@"

$(BUILD_DIR)/bootloader.bin: $(BUILD_DIR)/bootloader.elf
	$(OBJCOPY) -O binary $< $@

$(BUILD_DIR)/bootloader.elf: $(OBJS) linker_bram.ld
	$(CC) $(LDFLAGS) -o $@ $(OBJS)

$(BUILD_DIR)/%.o: %.c
	@mkdir -p $(dir $@)
	$(CC) $(COMMON_FLAGS) -I. -c $< -o $@

$(BUILD_DIR)/%.o: %.s
	@mkdir -p $(dir $@)
	$(CC) $(ARCH_FLAGS) -c $< -o $@

clean:
	rm -rf $(BUILD_DIR)

.PHONY: all clean


