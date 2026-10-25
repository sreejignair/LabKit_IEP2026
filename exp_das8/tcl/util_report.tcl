# Helper: pull the four resource numbers and WNS out of the open design and
# append one row to reports/utilisation.csv
proc das8_report {board part variant ila} {
    set rpt [report_utilization -return_string]
    proc _grab {rpt row} {
        foreach line [split $rpt "\n"] {
            if {[regexp "\\|\\s*${row}\\s*\\|\\s*(\\d+)\\s*\\|" $line -> v]} { return $v }
        }
        return 0
    }
    set n_lut  [_grab $rpt {Slice LUTs\*?}]
    set n_ff   [_grab $rpt {Slice Registers}]
    set n_dsp  [_grab $rpt {DSPs}]
    set n_bram [_grab $rpt {Block RAM Tile}]

    set wns "n/a"
    if {[llength [get_clocks -quiet]]} {
        set p [get_property SLACK [get_timing_paths -max_paths 1 -delay_type max -quiet]]
        if {$p ne ""} { set wns $p }
    }

    file mkdir reports
    set csv reports/utilisation.csv
    set newfile [expr {![file exists $csv]}]
    set fh [open $csv a]
    if {$newfile} { puts $fh "board,part,variant,ila,LUT,FF,DSP,BRAM36,WNS_ns" }
    puts $fh "$board,$part,$variant,$ila,$n_lut,$n_ff,$n_dsp,$n_bram,$wns"
    close $fh
    puts "  >> $variant on $board : LUT $n_lut  FF $n_ff  DSP $n_dsp  BRAM36 $n_bram  WNS $wns"
}
