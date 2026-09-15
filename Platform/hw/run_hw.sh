#!/bin/bash
# hw/run_hw.sh
set -euo pipefail

#XILINX_SETTING="/home/yc/Xilinx/Vivado/2024.1/settings64.sh"
#source "$XILINX_SETTING" || { echo ">> [ERROR] Vivado settings not found!"; exit 1; }

find_vivado_settings() {
    local settings_path=""
    for base_dir in "/tools/Xilinx/Vivado" "/opt/Xilinx/Vivado" "$HOME/Xilinx/Vivado" "/home/yc/Xilinx/Vivado"; do
        if [ -d "$base_dir" ]; then
            local latest_ver=$(ls -d "$base_dir"/* 2>/dev/null | grep -E '[0-9]+\.[0-9]+' | sort -V | tail -n 1)
            if [ -n "$latest_ver" ] && [ -f "$latest_ver/settings64.sh" ]; then
                settings_path="$latest_ver/settings64.sh"
                break
            fi
        fi
    done
    echo "$settings_path"
}

if ! command -v vivado &> /dev/null; then
    VIVADO_SETTING=$(find_vivado_settings)
    if [ -z "$VIVADO_SETTING" ]; then
        echo ">> [ERROR] Vivado settings not found automatically! Please check your installation path."
        exit 1
    fi
    echo ">> [INFO] Auto-detected Vivado settings: $VIVADO_SETTING"
    source "$VIVADO_SETTING"
else
    echo ">> [INFO] Vivado is already available in your shell environment."
fi

ROOT_DIR=$(pwd)
export BUILD_DIR="$ROOT_DIR/build"
HW_DIR="$ROOT_DIR/hw"
BIT_FINAL="$BUILD_DIR/out.bit"
BOOT_HEX="$BUILD_DIR/boot/boot.hex"
CONFIG_HEADER="$ROOT_DIR/sw/app/platform_config.h"
CONFIG_CHANGES=""

NEEDS_SYNTH=true
RTL_CHANGES=""
HEX_CHANGES=""
if [ -f "$BIT_FINAL" ]; then
    RTL_CHANGES=$(find "$HW_DIR/srcs" -newer "$BIT_FINAL" 2>/dev/null)

    if [ -f "$BOOT_HEX" ]; then
        HEX_CHANGES=$(find "$BOOT_HEX" -newer "$BIT_FINAL" 2>/dev/null)
    fi
    
    if [ -f "$CONFIG_HEADER" ]; then
        CONFIG_CHANGES=$(find "$CONFIG_HEADER" -newer "$BIT_FINAL" 2>/dev/null)
    fi

    if [ -z "$RTL_CHANGES" ] && [ -z "$HEX_CHANGES" ] && [ -z "$CONFIG_CHANGES" ]; then
        echo ">> [HW] RTL, Bootloader, and Config are up to date. Skipping Full Synthesis."
        NEEDS_SYNTH=false
    fi
fi

if [ "$NEEDS_SYNTH" = true ]; then
    if [ -n "$HEX_CHANGES" ] && [ -z "$RTL_CHANGES" ] && [ -z "$CONFIG_CHANGES" ]; then
        echo ">> [HW] Bootloader updated! Starting Full Synthesis to bake new ROM into Bitstream..."
    elif [ -n "$CONFIG_CHANGES" ]; then
        echo ">> [HW] platform_config.h updated! Starting Full Synthesis to apply new CPU frequency..."
    else
        echo ">> [HW] Hardware changes detected! Starting Full Synthesis..."
    fi
    
    mkdir -p "$BUILD_DIR/hw"
    cd "$BUILD_DIR/hw" || exit
    vivado -mode batch -source "$HW_DIR/build_SoC.tcl" -notrace -nolog -nojournal
    cd "$ROOT_DIR"
fi

echo ">> [HW] Programming FPGA with $BIT_FINAL..."
vivado -mode batch -source "$HW_DIR/program.tcl" -notrace -tclargs "$BIT_FINAL"
