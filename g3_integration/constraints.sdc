#input arrival times
set_input_delay 0.0 [all_inputs]

#output delays required times 
set_output_delay 0.0 [all_outputs]

# max delay
set_max_delay 2.0 -from [all_inputs] -to [all_outputs]

#set load?? might be needed
set_load 0.1 [all_outputs]

# heard we might nee drive strnegth.
# set_driving_cell -lib_cell gf180mcu_fd_sc_mcu7t5v0__buf_1 [all_inputs]