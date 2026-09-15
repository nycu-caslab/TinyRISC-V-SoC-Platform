# Makefile
ROOT_DIR    := $(shell pwd)
BUILD_DIR   := $(ROOT_DIR)/build
SW_DIR      := $(ROOT_DIR)/sw
BOOT_DIR    := $(ROOT_DIR)/hw/boot

VIVADO_JUNK := *.str *.debug *.log *.jou *.pb vivado*.backup.* .Xil/

.PHONY: prog run sw_build clean all_clean sw_clean hw_clean clean_logs kill_server

prog: kill_server clean_logs
	@echo ">> [BOOT] Building Bootloader (HEX for Custom CPU)..."
	$(MAKE) -C $(BOOT_DIR) all BUILD_DIR=$(BUILD_DIR)/boot
	@echo ">> [HW] Running Hardware Pipeline..."
	bash ./hw/run_hw.sh
	@$(MAKE) clean_logs

kill_server:
	@echo ">> [SERVER] Cleaning up background Vivado processes..."
	-@killall -9 vivado hw_server 2>/dev/null || true

run: kill_server
	@echo ">> [SERVER] Warming up Vivado JTAG Server in background..."
	@mkdir -p $(BUILD_DIR)
	@python3 -c "import socket; socket.create_connection(('localhost', 3122), 0.1)" 2>/dev/null || \
	(nohup vivado -mode tcl -source $(ROOT_DIR)/hw/jtag_server.tcl -notrace -nolog -nojournal > $(BUILD_DIR)/jtag_server.log 2>&1 &)
	@$(MAKE) sw_build
	@echo ">> [UART] Starting pipeline..."
	@$(MAKE) clean_logs
	python3 $(SW_DIR)/upload.py $(BUILD_DIR)/sw/main.bin

sw_build:
	@echo ">> [SW] Building Application..."
	@mkdir -p $(BUILD_DIR)/sw
	$(MAKE) -C $(SW_DIR) all BUILD_DIR=$(BUILD_DIR)/sw

clean_logs:
	@rm -rf $(VIVADO_JUNK)

all_clean: kill_server clean_logs
	@echo ">> Cleaning everything..."
	rm -rf $(BUILD_DIR)
	rm -rf ./hw/CUSTOM_SoC.gen

sw_clean:
	@echo ">> Cleaning Software build artifacts..."
	$(MAKE) -C $(SW_DIR) clean BUILD_DIR=$(BUILD_DIR)/sw

hw_clean:
	@echo ">> Cleaning Hardware/Bootloader build artifacts..."
	$(MAKE) -C $(BOOT_DIR) clean BUILD_DIR=$(BUILD_DIR)/boot
	rm -rf $(BUILD_DIR)/hw

clean: all_clean
