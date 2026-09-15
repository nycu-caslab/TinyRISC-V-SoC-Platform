set origin_dir [file normalize [file dirname [info script]]]
set root_dir [file normalize "$origin_dir/.."]
set hw_srcs "$origin_dir/srcs"
set proj_name "SoC"

create_project ${proj_name} ./${proj_name} -part xc7a100tcsg324-1 -force

# Source files
set rtl_files [glob -nocomplain "$hw_srcs/sources_1/imports/*.v" "$hw_srcs/sources_1/imports/*.sv"]
if {[llength $rtl_files] > 0} { add_files -norecurse $rtl_files }

set rtl_files [glob -nocomplain "$hw_srcs/*.v" "$hw_srcs/*.sv"]
if {[llength $rtl_files] > 0} { add_files -norecurse $rtl_files }

set ip_files [glob -nocomplain "$hw_srcs/sources_1/ip/*/*.xci"]
if {[llength $ip_files] > 0} { add_files -norecurse $ip_files }

add_files -norecurse [file normalize "$hw_srcs/sources_1/bd/MMIO/MMIO.bd"]
add_files -norecurse [file normalize "$hw_srcs/sources_1/imports/SoC.v"]
add_files -fileset constrs_1 [file normalize "$hw_srcs/constrs_1/new/Arty-A7-100T-Master.xdc"]

# riscv_defs.v
set defs_file [file normalize "$hw_srcs/sources_1/riscv_defs.v"]
if {[file exists $defs_file]} {
    add_files -norecurse $defs_file
    set_property file_type "Verilog Header" [get_files $defs_file]
    set_property is_global_include true [get_files $defs_file]
}

set hex_path [file normalize "$root_dir/build/boot/boot.hex"]
if {[file exists $hex_path]} {
    add_files -norecurse $hex_path
} else {
    puts ">> \[TCL\] WARNING: boot.hex not found at $hex_path"
}

update_compile_order -fileset sources_1
open_bd_design [get_files MMIO.bd]

# Vivado locks a block design when one of its generated IP instances is older
# than the IP revision installed with the current tool release.  Upgrade those
# instances before validating the design so a fresh clone can be built without
# first opening the project in the GUI.
set locked_ips [get_ips -quiet -filter {IS_LOCKED == 1}]
if {[llength $locked_ips] > 0} {
    puts ">> \[TCL\] Updating locked IPs: $locked_ips"
    report_ip_status
    upgrade_ip $locked_ips
    save_bd_design
}

# CPU clock setting
set cpu_freq_mhz 70.0
set config_file [file normalize "$root_dir/sw/app/platform_config.h"]

if {[file exists $config_file]} {
    set fp [open $config_file r]
    while {[gets $fp line] >= 0} {
        if {[regexp {^\s*#define\s+PLATFORM_CLOCK_HZ\s+([0-9]+)u?} $line match val]} {
            set cpu_freq_mhz [expr {$val / 1000000.0}]
            break
        }
    }
    close $fp
    puts ">> \[TCL\] Successfully parsed PLATFORM_CLOCK_HZ = $val Hz ($cpu_freq_mhz MHz) from platform_config.h"
} else {
    puts ">> \[TCL\] WARNING: platform_config.h not found, using default $cpu_freq_mhz MHz"
}


set_property -dict [list \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ 200.000 \
    CONFIG.CLKOUT2_REQUESTED_OUT_FREQ $cpu_freq_mhz \
] [get_bd_cells clk_wiz_0]

set elf_obj [get_files -quiet "*/bootloader.elf"]
if {$elf_obj != ""} {
    set_property SCOPED_TO_REF {} $elf_obj
    set_property SCOPED_TO_CELLS {} $elf_obj
}


assign_bd_address
validate_bd_design
save_bd_design
generate_target all [get_files MMIO.bd]
add_files -norecurse [make_wrapper -files [get_files MMIO.bd] -top]

set_property top SoC [current_fileset]
update_compile_order -fileset sources_1
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1

set bit_src [file normalize "./${proj_name}/${proj_name}.runs/impl_1/SoC.bit"]
if {[file exists $bit_src]} {
    file mkdir "$root_dir/build"
    file copy -force $bit_src "$root_dir/build/out.bit"
}

set report_dir [file normalize "$root_dir/build/reports"]
set timing_report "$report_dir/post_route_timing_summary.rpt"
set npu_report "$report_dir/post_route_utilization_npu.rpt"

file mkdir $report_dir
open_run impl_1

report_timing_summary \
    -delay_type min_max \
    -max_paths 10 \
    -input_pins \
    -file $timing_report
set npu_cells [get_cells -hierarchical -quiet \
    -filter {ORIG_REF_NAME == NPU || REF_NAME == NPU}]

if {[file exists $npu_report]} {
    file delete -force $npu_report
}

if {[llength $npu_cells] == 1} {
    set npu_cell [lindex $npu_cells 0]
    report_utilization \
        -cells $npu_cell \
        -hierarchical \
        -file $npu_report
    puts ">> \[TCL\] NPU utilization cell: [get_property NAME $npu_cell]"
} elseif {[llength $npu_cells] == 0} {
    puts ">> \[TCL\] WARNING: no implemented cell has REF_NAME or ORIG_REF_NAME NPU; NPU-only utilization report was not written"
} else {
    puts ">> \[TCL\] WARNING: multiple implemented NPU cells matched: [join [get_property NAME $npu_cells] {, }]"
    puts ">> \[TCL\] WARNING: NPU-only utilization report was not written because the selection is ambiguous"
}

puts ">> \[TCL\] Post-route timing report: $timing_report"
if {[file exists $npu_report]} {
    puts ">> \[TCL\] Post-route NPU utilization report: $npu_report"
}

exit
