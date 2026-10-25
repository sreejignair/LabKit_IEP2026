# ---------------------------------------------------------------------------
# create_fp_ip.tcl  -  AMD Floating-Point Operator cores for das8_float
#
# Three cores: fp_add, fp_sub, fp_mul. Latency is 3 for all of them and MUST
# match FP_LAT_ADD / FP_LAT_SUB / FP_LAT_MUL in rtl/das8_float.v.
#
# C_Mult_Usage Full_Usage puts the multiplier mantissa into DSP48 slices.
# Set FP_MULT_USAGE to No_Usage to build the same design entirely from LUTs -
# running both is itself an instructive comparison.
# ---------------------------------------------------------------------------
if {![info exists FP_LATENCY]}    { set FP_LATENCY 3 }
if {![info exists FP_MULT_USAGE]} { set FP_MULT_USAGE Full_Usage }

proc mk_fp {name op {sub Add}} {
    global FP_LATENCY FP_MULT_USAGE
    create_ip -name floating_point -vendor xilinx.com -library ip \
              -module_name $name -dir ./ip_gen
    set props [list \
        CONFIG.Operation_Type           $op \
        CONFIG.A_Precision_Type         Single \
        CONFIG.Result_Precision_Type    Single \
        CONFIG.C_A_Exponent_Width       8 \
        CONFIG.C_A_Fraction_Width       24 \
        CONFIG.C_Result_Exponent_Width  8 \
        CONFIG.C_Result_Fraction_Width  24 \
        CONFIG.Flow_Control             NonBlocking \
        CONFIG.Has_ARESETn              false \
        CONFIG.Has_ACLKEN               false \
        CONFIG.Maximum_Latency          false \
        CONFIG.C_Latency                $FP_LATENCY \
        CONFIG.C_Rate                   1 \
        CONFIG.C_Mult_Usage             $FP_MULT_USAGE ]
    if {$op eq "Add_Subtract"} { lappend props CONFIG.Add_Sub_Value $sub }
    set_property -dict $props [get_ips $name]
    generate_target {instantiation_template synthesis} [get_ips $name]
}

mk_fp fp_add Add_Subtract Add
mk_fp fp_sub Add_Subtract Subtract
mk_fp fp_mul Multiply
puts "FP IP created: latency $FP_LATENCY, multiplier usage $FP_MULT_USAGE"
