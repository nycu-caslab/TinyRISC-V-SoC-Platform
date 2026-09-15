# sw/Makefile
SHELL := /bin/bash
TARGET_PREFIX ?= riscv64-unknown-elf
CC      = $(TARGET_PREFIX)-gcc
CXX     = $(TARGET_PREFIX)-g++
OBJCOPY = $(TARGET_PREFIX)-objcopy
MKDIR   = mkdir -p

PROJECT_CONFIG ?= project.mk

# --- Set Model ---
MODEL_DIR ?= models
MODEL_FILE ?=
MODEL_PROFILE ?=
TENSOR_ARENA_SIZE ?= 262144
USE_SOFTWARE_CFU ?= 0
# ------------------

-include $(PROJECT_CONFIG)

APP_EXTRA_SRCS ?=
APP_DEFINES ?=

override TFLM_MODEL_ENABLED := 0
ifneq ($(strip $(MODEL_FILE)$(MODEL_PROFILE)),)
ifeq ($(strip $(MODEL_FILE)),)
$(error MODEL_FILE and MODEL_PROFILE must be specified together)
endif
ifeq ($(strip $(MODEL_PROFILE)),)
$(error MODEL_FILE and MODEL_PROFILE must be specified together)
endif
override TFLM_MODEL_ENABLED := 1
endif

BUILD_DIR      ?= $(abspath ../build/sw)
GEN_DIR        := $(BUILD_DIR)/generated
MODEL_PATH     := $(if $(strip $(MODEL_FILE)),$(if $(findstring /,$(MODEL_FILE)),$(MODEL_FILE),$(MODEL_DIR)/$(MODEL_FILE)))
MODEL_ABS      := $(if $(MODEL_PATH),$(abspath $(MODEL_PATH)))
MODEL_BASENAME := $(if $(MODEL_PATH),$(notdir $(MODEL_PATH)),none)
MODEL_STAMP    := $(BUILD_DIR)/model_data.$(MODEL_BASENAME).stamp
MODEL_SELECTED := $(BUILD_DIR)/model_data.selected
MICRO_SRC_DIR := $(BUILD_DIR)/src
TFLM_SRC_ROOT := $(abspath ../../tflite-micro)

TFLM_SRC_STAMP := $(BUILD_DIR)/tflm_src.stamp
TFLM_PATCH_DIR := tflm_patches
TFLM_PATCH_FILES := $(shell find $(TFLM_PATCH_DIR) -type f 2>/dev/null)
TFLM_PATCH_STAMP := $(BUILD_DIR)/tflm_patch.stamp
APP_SRC_DIR := app
PROJECT_SRC_DIR := project
RUNTIME_DIR := runtime
MODEL_PROFILE_DIR ?= models

MODEL_PROFILE_SRC ?= $(if $(filter 1,$(TFLM_MODEL_ENABLED)),$(MODEL_PROFILE_DIR)/$(MODEL_PROFILE)_profile.cc)
TFLM_OBJ_DIR := $(BUILD_DIR)/obj
PROJECT_CONFIG_STATUS := $(if $(wildcard $(PROJECT_CONFIG)),$(PROJECT_CONFIG),not found)
LINKER_SCRIPT := $(RUNTIME_DIR)/linker.ld
STARTUP_SRC := $(RUNTIME_DIR)/crt0.s
STARTUP_OBJ := $(TFLM_OBJ_DIR)/$(RUNTIME_DIR)/crt0.o
SYSCALLS_SRC := $(RUNTIME_DIR)/syscalls.c
SYSCALLS_OBJ := $(TFLM_OBJ_DIR)/$(RUNTIME_DIR)/syscalls.o

# RISC-V Compiled Params
ARCH_FLAGS   := -march=rv32im -mabi=ilp32 -mcmodel=medany
DEFINES      := $(APP_DEFINES)
ifeq ($(TFLM_MODEL_ENABLED),1)
DEFINES      += -DTFLM_MODEL_ENABLED=1 \
                -DMODEL_NAME=\"$(MODEL_BASENAME)\" \
                -DTENSOR_ARENA_SIZE=$(TENSOR_ARENA_SIZE)
endif
ifeq ($(USE_SOFTWARE_CFU),1)
DEFINES      += -DCFU_SOFTWARE_DEFINED
endif
COMMON_FLAGS := $(ARCH_FLAGS) -O3 -g -ffunction-sections -fdata-sections -fno-builtin \
                --param ggc-min-expand=0 --param ggc-min-heapsize=1024000 \
                -MMD -MP
CFLAGS        := $(COMMON_FLAGS) -std=c11
CXXFLAGS      := $(COMMON_FLAGS) -std=c++11 -fno-rtti -fno-exceptions -fpermissive
APP_CXXFLAGS  := $(CXXFLAGS) $(DEFINES)
LDFLAGS       := $(ARCH_FLAGS) -T $(LINKER_SCRIPT) -nostartfiles -Wl,--gc-sections -Wl,--no-relax
LDLIBS        := -lm -lstdc++ -lc

INCLUDES := -I. -I$(APP_SRC_DIR) -I$(PROJECT_SRC_DIR) -I$(GEN_DIR) -I$(MICRO_SRC_DIR) \
            -I$(MICRO_SRC_DIR)/third_party/flatbuffers/include \
            -I$(MICRO_SRC_DIR)/third_party/gemmlowp \
            -I$(MICRO_SRC_DIR)/third_party/ruy

ALL_APP_CC_SRCS := main.cc $(sort $(shell find $(APP_SRC_DIR) $(PROJECT_SRC_DIR) -name "*.cc" 2>/dev/null) $(APP_EXTRA_SRCS))
MODEL_APP_CC_SRCS := $(APP_SRC_DIR)/model_io.cc $(APP_SRC_DIR)/tflm_runner.cc $(PROJECT_SRC_DIR)/tflm_ops.cc

ifeq ($(TFLM_MODEL_ENABLED),1)
APP_CC_SRCS := $(sort $(ALL_APP_CC_SRCS) $(MODEL_PROFILE_SRC))
MODEL_OBJS := $(TFLM_OBJ_DIR)/model_data.o
MODEL_DEPS := $(TFLM_OBJ_DIR)/model_data.d
TFLM_SRCS := $(shell find $(MICRO_SRC_DIR) -name "*.cc" -o -name "*.c" 2>/dev/null | \
					  grep -vE "_test.cc|_benchmark.cc|arc_mli|ethosu|/tools/|/examples/|fft2d|debug_log.cc")
TFLM_SRCS += $(MICRO_SRC_DIR)/third_party/fft2d/fft4g.c
TFLM_OBJS := $(patsubst $(MICRO_SRC_DIR)/%.cc,$(TFLM_OBJ_DIR)/%.o,$(filter %.cc,$(TFLM_SRCS)))
TFLM_OBJS += $(patsubst $(MICRO_SRC_DIR)/%.c,$(TFLM_OBJ_DIR)/%.o,$(filter %.c,$(TFLM_SRCS)))
else
APP_CC_SRCS := $(filter-out $(MODEL_APP_CC_SRCS),$(ALL_APP_CC_SRCS))
MODEL_OBJS :=
MODEL_DEPS :=
TFLM_SRCS :=
TFLM_OBJS :=
endif

APP_CC_OBJS := $(patsubst %.cc,$(TFLM_OBJ_DIR)/%.o,$(APP_CC_SRCS))
APP_OBJS    := $(APP_CC_OBJS) $(MODEL_OBJS) $(SYSCALLS_OBJ)
DEPS := $(APP_CC_OBJS:.o=.d) $(TFLM_OBJS:.o=.d) \
		$(MODEL_DEPS) $(SYSCALLS_OBJ:.o=.d)

.DEFAULT_GOAL := all

-include $(DEPS)

all: check-env
	@$(MAKE) build-binary

help:
	@printf "AAML RISC-V Platform\n"
	@printf "\n"
	@printf "Common targets:\n"
	@printf "  make                 Build firmware without an embedded model\n"
	@printf "  make run             Build and run\n"
	@printf "  make models          List available model files\n"
	@printf "  make profiles        List available model profile files\n"
	@printf "  make templates       List software extension templates\n"
	@printf "  make config          Print resolved build configuration\n"
	@printf "  make validate        Print resolved config and available assets\n"
	@printf "  make check-env       Check toolchain, TFLM source, and model files\n"
	@printf "  make clean           Remove generated SW build files\n"
	@printf "\n"
	@printf "Useful overrides:\n"
	@printf "  MODEL_FILE=ad01_int8.tflite\n"
	@printf "  MODEL_PROFILE=ad01\n"
	@printf "  TENSOR_ARENA_SIZE=262144\n"
	@printf "  TARGET_PREFIX=riscv64-unknown-elf\n"
	@printf "  PROJECT_CONFIG=project.mk\n"
	@printf "\n"
	@printf "Set MODEL_FILE and MODEL_PROFILE to enable TFLM inference.\n"

models:
	@printf "Available models in Platform/sw/$(MODEL_DIR):\n"
	@find $(MODEL_DIR) -maxdepth 1 -name "*.tflite" -print | sed 's#^$(MODEL_DIR)/#  #'

profiles:
	@printf "Available model profiles in Platform/sw/$(MODEL_PROFILE_DIR):\n"
	@find $(MODEL_PROFILE_DIR) -maxdepth 1 -name "*_profile.cc" -print | sed 's#^$(MODEL_PROFILE_DIR)/#  #; s#_profile.cc$$##'

templates:
	@printf "Available templates in Platform/sw/templates:\n"
	@find templates -maxdepth 1 -name "*_template.*" -print | sed 's#^templates/#  #'

config:
	@printf "PROJECT_CONFIG=%s\n" "$(PROJECT_CONFIG_STATUS)"
	@printf "TARGET_PREFIX=%s\n" "$(TARGET_PREFIX)"
	@printf "MODEL_DIR=%s\n" "$(MODEL_DIR)"
	@printf "MODEL_FILE=%s\n" "$(MODEL_FILE)"
	@printf "MODEL_PATH=%s\n" "$(MODEL_PATH)"
	@printf "MODEL_BASENAME=%s\n" "$(MODEL_BASENAME)"
	@printf "MODEL_PROFILE=%s\n" "$(MODEL_PROFILE)"
	@printf "MODEL_PROFILE_SRC=%s\n" "$(MODEL_PROFILE_SRC)"
	@printf "TFLM_MODEL_ENABLED=%s\n" "$(TFLM_MODEL_ENABLED)"
	@printf "APP_SRC_DIR=%s\n" "$(APP_SRC_DIR)"
	@printf "PROJECT_SRC_DIR=%s\n" "$(PROJECT_SRC_DIR)"
	@printf "TFLM_PATCH_DIR=%s\n" "$(TFLM_PATCH_DIR)"
	@printf "TENSOR_ARENA_SIZE=%s\n" "$(TENSOR_ARENA_SIZE)"
	@printf "USE_SOFTWARE_CFU=%s\n" "$(USE_SOFTWARE_CFU)"
	@printf "BUILD_DIR=%s\n" "$(BUILD_DIR)"

validate:
	@$(MAKE) config
	@$(MAKE) models
	@$(MAKE) profiles
	@$(MAKE) templates

check-env:
	@printf "Checking SW build environment...\n"
	@command -v $(CC) >/dev/null || { printf "ERROR: missing %s in PATH\n" "$(CC)"; exit 1; }
	@command -v $(CXX) >/dev/null || { printf "ERROR: missing %s in PATH\n" "$(CXX)"; exit 1; }
	@command -v $(OBJCOPY) >/dev/null || { printf "ERROR: missing %s in PATH\n" "$(OBJCOPY)"; exit 1; }
ifeq ($(TFLM_MODEL_ENABLED),1)
	@command -v python3 >/dev/null || { printf "ERROR: missing python3 in PATH\n"; exit 1; }
	@command -v perl >/dev/null || { printf "ERROR: missing perl in PATH\n"; exit 1; }
	@test -d "$(TFLM_SRC_ROOT)/tensorflow" || { printf "ERROR: missing TFLM source at %s\n" "$(TFLM_SRC_ROOT)"; exit 1; }
	@test -d "$(MODEL_DIR)" || { printf "ERROR: missing model directory %s\n" "$(MODEL_DIR)"; exit 1; }
	@test -f "$(MODEL_PATH)" || { printf "ERROR: missing model file %s\n" "$(MODEL_PATH)"; exit 1; }
	@test -f "$(MODEL_PROFILE_SRC)" || { printf "ERROR: missing model profile source %s\n" "$(MODEL_PROFILE_SRC)"; exit 1; }
	@printf "OK: toolchain=%s, model=%s, profile=%s, arena=%s bytes\n" "$(TARGET_PREFIX)" "$(MODEL_PATH)" "$(MODEL_PROFILE)" "$(TENSOR_ARENA_SIZE)"
else
	@printf "OK: toolchain=%s, embedded TFLM model disabled\n" "$(TARGET_PREFIX)"
endif

build-binary: prepare-src
	@$(MAKE) link-binary

link-binary: $(STARTUP_OBJ) $(APP_OBJS) $(TFLM_OBJS) $(LINKER_SCRIPT)
	@$(MKDIR) $(BUILD_DIR)
	@echo ">> [LINK] Finalizing ELF..."
	$(CXX) $(LDFLAGS) -o $(BUILD_DIR)/main.elf $(filter-out $(LINKER_SCRIPT),$^) $(LDLIBS)
	$(OBJCOPY) -O binary $(BUILD_DIR)/main.elf $(BUILD_DIR)/main.bin

ifeq ($(TFLM_MODEL_ENABLED),1)
$(BUILD_DIR)/model_data.c $(GEN_DIR)/model_data.h: $(MODEL_STAMP)

$(MODEL_SELECTED):
	@$(MKDIR) $(BUILD_DIR) $(GEN_DIR)
	@touch $@

$(MODEL_STAMP): FORCE $(MODEL_PATH) $(MODEL_SELECTED)
	@$(MKDIR) $(BUILD_DIR) $(GEN_DIR)
	@if [ ! -f "$(BUILD_DIR)/model_data.c" ] || \
		[ ! -f "$(GEN_DIR)/model_data.h" ] || \
		[ "$$(cat "$(MODEL_SELECTED)" 2>/dev/null)" != "$(MODEL_ABS)" ] || \
		[ "$(MODEL_PATH)" -nt "$(BUILD_DIR)/model_data.c" ]; then \
		echo ">> Generating model_data.h and model_data.c from $(MODEL_PATH)..."; \
		python3 -c "import sys; data=open(sys.argv[1],'rb').read(); print('#include <stdint.h>\n#include \"model_data.h\"\nconst uint8_t g_model[] __attribute__((aligned(16))) = {'); print(','.join([hex(b) for b in data])); print('};\nconst int g_model_len = ' + str(len(data)) + ';')" "$(MODEL_PATH)" > "$(BUILD_DIR)/model_data.c"; \
		echo "#ifndef PLATFORM_SW_GENERATED_MODEL_DATA_H_" > "$(GEN_DIR)/model_data.h"; \
		echo "#define PLATFORM_SW_GENERATED_MODEL_DATA_H_" >> "$(GEN_DIR)/model_data.h"; \
		echo "#include <stdint.h>" >> "$(GEN_DIR)/model_data.h"; \
		echo "#ifdef __cplusplus" >> "$(GEN_DIR)/model_data.h"; \
		echo "extern \"C\" {" >> "$(GEN_DIR)/model_data.h"; \
		echo "#endif" >> "$(GEN_DIR)/model_data.h"; \
		echo "extern const uint8_t g_model[];" >> "$(GEN_DIR)/model_data.h"; \
		echo "extern const int g_model_len;" >> "$(GEN_DIR)/model_data.h"; \
		echo "#ifdef __cplusplus" >> "$(GEN_DIR)/model_data.h"; \
		echo "}" >> "$(GEN_DIR)/model_data.h"; \
		echo "#endif" >> "$(GEN_DIR)/model_data.h"; \
		echo "#endif" >> "$(GEN_DIR)/model_data.h"; \
		printf "%s\n" "$(MODEL_ABS)" > "$(MODEL_SELECTED)"; \
	fi
	@touch $@

$(TFLM_OBJ_DIR)/model_data.o: $(BUILD_DIR)/model_data.c $(GEN_DIR)/model_data.h
	@$(MKDIR) $(dir $@)
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@
endif
$(TFLM_OBJ_DIR)/%.o: $(MICRO_SRC_DIR)/%.cc
	@$(MKDIR) $(dir $@)
	$(CXX) $(CXXFLAGS) $(INCLUDES) -c $< -o $@

$(TFLM_OBJ_DIR)/%.o: $(MICRO_SRC_DIR)/%.c
	@$(MKDIR) $(dir $@)
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

$(TFLM_OBJ_DIR)/%.o: %.cc
	@$(MKDIR) $(dir $@)
	$(CXX) $(APP_CXXFLAGS) $(INCLUDES) -c $< -o $@

ifeq ($(TFLM_MODEL_ENABLED),1)
$(TFLM_OBJ_DIR)/$(APP_SRC_DIR)/tflm_runner.o: $(GEN_DIR)/model_data.h
endif

$(SYSCALLS_OBJ): $(SYSCALLS_SRC)
	@$(MKDIR) $(dir $@)
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

$(STARTUP_OBJ): $(STARTUP_SRC)
	@$(MKDIR) $(dir $@)
	$(CC) $(ARCH_FLAGS) -c $< -o $@

ifeq ($(TFLM_MODEL_ENABLED),1)
$(APP_CC_OBJS) $(TFLM_OBJS): $(TFLM_PATCH_STAMP)
endif
$(APP_CC_OBJS): FORCE

$(TFLM_SRC_STAMP):
	@$(MKDIR) $(BUILD_DIR)
	@if [ ! -d $(MICRO_SRC_DIR)/tensorflow ]; then \
		$(MKDIR) $(MICRO_SRC_DIR); \
		echo ">> Copying TFLM source..."; \
		cp -r $(TFLM_SRC_ROOT)/tensorflow $(MICRO_SRC_DIR)/; \
		cp -r $(TFLM_SRC_ROOT)/third_party $(MICRO_SRC_DIR)/; \
	fi
	@touch $@

$(TFLM_PATCH_STAMP): $(TFLM_SRC_STAMP) $(TFLM_PATCH_FILES)
	@if [ -d $(TFLM_PATCH_DIR) ]; then \
		cp -r $(TFLM_PATCH_DIR)/. $(MICRO_SRC_DIR)/; \
	fi
	@echo ">> Running compatibility fixes..."
	@find $(MICRO_SRC_DIR) -type f \( -name "*.h" -o -name "*.cc" -o -name "*.c" \) -exec perl -pi -e 's/std::fmax/fmax/g; s/std::fmin/fmin/g; s/std::round/round/g; s/std::expm1/expm1/g; s/std::isnan/isnan/g; s/std::isinf/isinf/g' {} +
	@perl -pi -e 's/TF_LITE_GLOBAL_STD_PREFIX std/TF_LITE_GLOBAL_STD_PREFIX/g' $(MICRO_SRC_DIR)/tensorflow/lite/kernels/internal/cppmath.h
	@perl -pi -e 's/AddEthosU/ \/\/ AddEthosU/g' $(MICRO_SRC_DIR)/tensorflow/lite/micro/all_ops_resolver.cc
	@perl -pi -e 's/AddAudio_Spectrogram/ \/\/ AddAudio_Spectrogram/g' $(MICRO_SRC_DIR)/tensorflow/lite/micro/all_ops_resolver.cc
	@perl -pi -e 's/AddMFCC/ \/\/ AddMFCC/g' $(MICRO_SRC_DIR)/tensorflow/lite/micro/all_ops_resolver.cc
	@touch $@

.PHONY: prepare-src
ifeq ($(TFLM_MODEL_ENABLED),1)
prepare-src: $(TFLM_PATCH_STAMP)
else
prepare-src:
endif

run: all
	@sudo chmod 666 /dev/ttyUSB1 2>/dev/null || true
	sudo python3 upload.py $(BUILD_DIR)/main.bin

clean:
	rm -rf $(BUILD_DIR)

FORCE:

.PHONY: all clean prepare-src build-binary link-binary run help models profiles templates config validate check-env FORCE
