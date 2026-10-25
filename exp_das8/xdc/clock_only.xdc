# Clock-only constraints for the synthesis comparison.
# 100 MHz oscillator, which all three Digilent boards carry.
create_clock -period 10.000 -name sys_clk [get_ports clk]
set_false_path -from [get_ports rst_n]
