# Arty A7-100T board constraints

# System Clock
set_property -dict {PACKAGE_PIN E3 IOSTANDARD LVCMOS33} [get_ports CLK100MHZ]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports {CLK100MHZ}]

# System Reset
set_property -dict {PACKAGE_PIN C2 IOSTANDARD LVCMOS33} [get_ports CPU_RESETN]

# USB UART
set_property -dict {PACKAGE_PIN A9 IOSTANDARD LVCMOS33} [get_ports UART_rxd]
set_property -dict {PACKAGE_PIN D10 IOSTANDARD LVCMOS33} [get_ports UART_txd]

# LD0
set_property -dict {PACKAGE_PIN H5 IOSTANDARD LVCMOS33} [get_ports mb_reset]
# LD1
set_property -dict {PACKAGE_PIN J5 IOSTANDARD LVCMOS33} [get_ports diag_led_rst]
# LD2
set_property -dict {PACKAGE_PIN T9 IOSTANDARD LVCMOS33} [get_ports diag_led_blink]

# DDR3 Address
set_property -dict { PACKAGE_PIN R2   IOSTANDARD SSTL135 } [get_ports { DDR3_addr[0] }]
set_property -dict { PACKAGE_PIN M6   IOSTANDARD SSTL135 } [get_ports { DDR3_addr[1] }]
set_property -dict { PACKAGE_PIN N4   IOSTANDARD SSTL135 } [get_ports { DDR3_addr[2] }]
set_property -dict { PACKAGE_PIN T1   IOSTANDARD SSTL135 } [get_ports { DDR3_addr[3] }]
set_property -dict { PACKAGE_PIN N6   IOSTANDARD SSTL135 } [get_ports { DDR3_addr[4] }]
set_property -dict { PACKAGE_PIN R7   IOSTANDARD SSTL135 } [get_ports { DDR3_addr[5] }]
set_property -dict { PACKAGE_PIN V6   IOSTANDARD SSTL135 } [get_ports { DDR3_addr[6] }]
set_property -dict { PACKAGE_PIN U7   IOSTANDARD SSTL135 } [get_ports { DDR3_addr[7] }]
set_property -dict { PACKAGE_PIN R8   IOSTANDARD SSTL135 } [get_ports { DDR3_addr[8] }]
set_property -dict { PACKAGE_PIN V7   IOSTANDARD SSTL135 } [get_ports { DDR3_addr[9] }]
set_property -dict { PACKAGE_PIN R6   IOSTANDARD SSTL135 } [get_ports { DDR3_addr[10] }]
set_property -dict { PACKAGE_PIN U6   IOSTANDARD SSTL135 } [get_ports { DDR3_addr[11] }]
set_property -dict { PACKAGE_PIN T6   IOSTANDARD SSTL135 } [get_ports { DDR3_addr[12] }]
set_property -dict { PACKAGE_PIN T8   IOSTANDARD SSTL135 } [get_ports { DDR3_addr[13] }]

# DDR3 Bank Address
set_property -dict { PACKAGE_PIN R1   IOSTANDARD SSTL135 } [get_ports { DDR3_ba[0] }]
set_property -dict { PACKAGE_PIN P4   IOSTANDARD SSTL135 } [get_ports { DDR3_ba[1] }]
set_property -dict { PACKAGE_PIN P2   IOSTANDARD SSTL135 } [get_ports { DDR3_ba[2] }]

# DDR3 Control
set_property -dict { PACKAGE_PIN M4   IOSTANDARD SSTL135 } [get_ports { DDR3_cas_n }]
set_property -dict { PACKAGE_PIN P3   IOSTANDARD SSTL135 } [get_ports { DDR3_ras_n }]
set_property -dict { PACKAGE_PIN P5   IOSTANDARD SSTL135 } [get_ports { DDR3_we_n }]
set_property -dict { PACKAGE_PIN K6   IOSTANDARD SSTL135 } [get_ports { DDR3_reset_n }]
set_property -dict { PACKAGE_PIN N5   IOSTANDARD SSTL135 } [get_ports { DDR3_cke[0] }]
set_property -dict { PACKAGE_PIN R5   IOSTANDARD SSTL135 } [get_ports { DDR3_odt[0] }]
set_property -dict { PACKAGE_PIN U8   IOSTANDARD SSTL135 } [get_ports { DDR3_cs_n[0] }]

# DDR3 Clock (Differential)
set_property -dict { PACKAGE_PIN U9   IOSTANDARD DIFF_SSTL135 } [get_ports { DDR3_ck_p[0] }]
set_property -dict { PACKAGE_PIN V9   IOSTANDARD DIFF_SSTL135 } [get_ports { DDR3_ck_n[0] }]

# DDR3 Data Mask
set_property -dict { PACKAGE_PIN L1   IOSTANDARD SSTL135 } [get_ports { DDR3_dm[0] }]
set_property -dict { PACKAGE_PIN U1   IOSTANDARD SSTL135 } [get_ports { DDR3_dm[1] }]

# DDR3 Data
set_property -dict { PACKAGE_PIN K5   IOSTANDARD SSTL135 } [get_ports { DDR3_dq[0] }]
set_property -dict { PACKAGE_PIN L3   IOSTANDARD SSTL135 } [get_ports { DDR3_dq[1] }]
set_property -dict { PACKAGE_PIN K3   IOSTANDARD SSTL135 } [get_ports { DDR3_dq[2] }]
set_property -dict { PACKAGE_PIN L6   IOSTANDARD SSTL135 } [get_ports { DDR3_dq[3] }]
set_property -dict { PACKAGE_PIN M3   IOSTANDARD SSTL135 } [get_ports { DDR3_dq[4] }]
set_property -dict { PACKAGE_PIN M1   IOSTANDARD SSTL135 } [get_ports { DDR3_dq[5] }]
set_property -dict { PACKAGE_PIN L4   IOSTANDARD SSTL135 } [get_ports { DDR3_dq[6] }]
set_property -dict { PACKAGE_PIN M2   IOSTANDARD SSTL135 } [get_ports { DDR3_dq[7] }]
set_property -dict { PACKAGE_PIN V4   IOSTANDARD SSTL135 } [get_ports { DDR3_dq[8] }]
set_property -dict { PACKAGE_PIN T5   IOSTANDARD SSTL135 } [get_ports { DDR3_dq[9] }]
set_property -dict { PACKAGE_PIN U4   IOSTANDARD SSTL135 } [get_ports { DDR3_dq[10] }]
set_property -dict { PACKAGE_PIN V5   IOSTANDARD SSTL135 } [get_ports { DDR3_dq[11] }]
set_property -dict { PACKAGE_PIN V1   IOSTANDARD SSTL135 } [get_ports { DDR3_dq[12] }]
set_property -dict { PACKAGE_PIN T3   IOSTANDARD SSTL135 } [get_ports { DDR3_dq[13] }]
set_property -dict { PACKAGE_PIN U3   IOSTANDARD SSTL135 } [get_ports { DDR3_dq[14] }]
set_property -dict { PACKAGE_PIN R3   IOSTANDARD SSTL135 } [get_ports { DDR3_dq[15] }]

# DDR3 DQS (Differential)
set_property -dict { PACKAGE_PIN N2   IOSTANDARD DIFF_SSTL135 } [get_ports { DDR3_dqs_p[0] }]
set_property -dict { PACKAGE_PIN N1   IOSTANDARD DIFF_SSTL135 } [get_ports { DDR3_dqs_n[0] }]
set_property -dict { PACKAGE_PIN U2   IOSTANDARD DIFF_SSTL135 } [get_ports { DDR3_dqs_p[1] }]
set_property -dict { PACKAGE_PIN V2   IOSTANDARD DIFF_SSTL135 } [get_ports { DDR3_dqs_n[1] }]
