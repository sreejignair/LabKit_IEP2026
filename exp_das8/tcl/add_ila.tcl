# ---------------------------------------------------------------------------
# add_ila.tcl  -  insert an ILA on the DAS output, after synthesis
#
# Probes result, out_valid and point so a whole 64-point line can be captured
# on hardware and compared against sim/golden_*.hex.
# ---------------------------------------------------------------------------
set clk_net [get_nets -hier -filter {NAME =~ *clk*} -quiet]
if {![llength $clk_net]} { puts "ERROR: no clock net found"; return }

create_debug_core u_ila ila
set_property C_DATA_DEPTH 1024      [get_debug_cores u_ila]
set_property C_TRIGIN_EN  false     [get_debug_cores u_ila]
set_property C_EN_STRG_QUAL true    [get_debug_cores u_ila]
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila]
set_property port_width 1 [get_debug_ports u_ila/clk]
connect_debug_port u_ila/clk [lindex $clk_net 0]

set idx 0
foreach sig {result out_valid point} {
    set net [get_nets -hier -filter "NAME =~ *${sig}*" -quiet]
    if {![llength $net]} { puts "  skip $sig - not found"; continue }
    if {$idx > 0} { create_debug_port u_ila probe }
    set_property port_width [llength $net] [get_debug_ports u_ila/probe$idx]
    connect_debug_port u_ila/probe$idx $net
    puts "  probe$idx <- $sig ([llength $net] bits)"
    incr idx
}
puts "ILA inserted with $idx probes, depth 1024"
