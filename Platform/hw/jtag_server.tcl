open_hw_manager
connect_hw_server -url localhost:3121
open_hw_target

set device [lindex [get_hw_devices] 0]
current_hw_device $device
refresh_hw_device $device

set hw_axi_list [get_hw_axis]
if {[llength $hw_axi_list] == 0} {
    puts "ERROR: No JTAG-to-AXI Master found!"
    exit 1
}
set ::hw_axi [lindex $hw_axi_list 0]
reset_hw_axi $::hw_axi

proc read_and_execute {sock} {
    if {[eof $sock]} {
        close $sock
        return
    }
    set cmd [gets $sock]
    if {$cmd ne ""} {
        set ::client_sock $sock
        if {[catch {uplevel #0 $cmd} err]} {
            puts $sock "ERROR: $err"
        } else {
            puts $sock "DONE"
        }
        flush $sock
    }
}

proc handle_client {sock addr port} {
    fconfigure $sock -buffering line -translation crlf
    fileevent $sock readable [list read_and_execute $sock]
}

socket -server handle_client 3122
vwait forever