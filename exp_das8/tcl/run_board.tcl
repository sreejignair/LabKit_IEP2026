# ---------------------------------------------------------------------------
# run_board.tcl  -  synthesise both DAS variants for one board
#
#   vivado -mode batch -source tcl/run_board.tcl -tclargs <board> [ila]
#
#   board : basys3 | arty_a7_100 | nexys_a7_100 | nexys_a7_50 | arty_a7_35
#   ila   : optional. Without it you get synthesis + utilisation only, which is
#           what the comparison table needs. With it you get implementation,
#           a bitstream and a .ltx probe file.
# ---------------------------------------------------------------------------
set board    [lindex $argv 0]
set want_ila [expr {[lindex $argv 1] eq "ila"}]

array set PARTS {
    basys3        xc7a35tcpg236-1
    arty_a7_35    xc7a35ticsg324-1L
    arty_a7_100   xc7a100tcsg324-1
    nexys_a7_50   xc7a50tcsg324-1
    nexys_a7_100  xc7a100tcsg324-1
}
if {![info exists PARTS($board)]} {
    puts "ERROR: unknown board '$board'. Known: [array names PARTS]"
    exit 1
}
set part $PARTS($board)
puts "=== board $board   part $part   ila $want_ila ==="

source tcl/util_report.tcl
file mkdir reports/$board
file mkdir ip_gen

foreach variant {fixed float} {
    set top das8_${variant}
    puts "\n--- $top on $board ---"
    create_project -in_memory -part $part

    add_files -norecurse [glob rtl/*.v]
    set_property include_dirs [file normalize rtl] [current_fileset]
    # memory init files must be visible to synthesis for $readmemh
    add_files -norecurse [glob sim/*.hex]
    set_property file_type {Memory Initialization Files} [get_files -filter {FILE_TYPE == Verilog && NAME =~ *.hex}] 

    if {$variant eq "float"} {
        source tcl/create_fp_ip.tcl
        foreach ip {fp_add fp_sub fp_mul} { synth_ip [get_ips $ip] }
    }

    set_property top $top [current_fileset]
    read_xdc xdc/clock_only.xdc
    synth_design -top $top -part $part

    write_checkpoint -force reports/$board/${variant}_synth.dcp
    report_utilization -hierarchical -file reports/$board/${variant}_util_synth.rpt
    report_timing_summary          -file reports/$board/${variant}_timing_synth.rpt
    das8_report $board $part $variant [expr {$want_ila?1:0}]

    if {$want_ila} {
        source tcl/add_ila.tcl
        implement_debug_core
        opt_design
        place_design
        route_design
        report_utilization    -file reports/$board/${variant}_util_impl_ila.rpt
        report_timing_summary -file reports/$board/${variant}_timing_impl_ila.rpt
        write_bitstream     -force reports/$board/${variant}_ila.bit
        write_debug_probes  -force reports/$board/${variant}_ila.ltx
        puts "  bitstream + .ltx written to reports/$board/"
    }
    close_project
}
puts "\n=== done. reports/utilisation.csv now holds the comparison ==="
