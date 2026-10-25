# Behavioural simulation of one variant in Vivado's simulator.
#   vivado -mode batch -source tcl/sim.tcl -tclargs fixed
#   vivado -mode batch -source tcl/sim.tcl -tclargs float
#
# The float variant needs the IP generated first, so it takes longer.
set variant [lindex $argv 0]
if {$variant ni {fixed float}} { puts "ERROR: variant must be fixed or float"; exit 1 }

create_project -force -part xc7a100tcsg324-1 sim_prj ./sim_prj
add_files -norecurse [glob rtl/*.v]
add_files -fileset sim_1 -norecurse tb/tb_das8_${variant}.v
add_files -norecurse [glob sim/*.hex]
set_property include_dirs [file normalize rtl] [current_fileset]
set_property include_dirs [file normalize rtl] [get_filesets sim_1]

if {$variant eq "float"} {
    source tcl/create_fp_ip.tcl
}
set_property top tb_das8_${variant} [get_filesets sim_1]
launch_simulation
run all
