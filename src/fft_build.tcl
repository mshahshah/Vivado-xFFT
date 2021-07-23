
set prj_path [pwd]
cd  $prj_path
puts "project path is :$prj_path"

source src/build_fft_cfg.tcl
set mode [lindex $argv 0]


puts " here is $prj_name" 
puts " here is $ip_cfg_mode" 
#file delete -force -- $prj_name.hw
#file delete -force -- $prj_name.srcs
#file delete -force -- $prj_name.gen
#file delete -force -- $prj_name.cache
#file delete -force -- $prj_name.cache
#file delete -force -- .Xil
#file delete -force -- .idea



switch $rounding  {
   "round"  { set rounding_modes  "convergent_rounding" }
   "trunc"  { set rounding_modes  "truncation" }
   default { puts "Error : Incorrect rounding_modes"}
}

if { $ip_cfg_mode == "new" } {
puts "************ Building a new BD design  ************ "
   file delete {*}[glob *.jou]
   file delete {*}[glob *.log]
   create_project -force $prj_name  $prj_path
   set_property part xczu48dr-ffvg1517-2-i [current_project]
   reset_property board_connections [current_project]
   create_bd_design "fft_bd"
   update_compile_order -fileset sources_1
   
   startgroup
   create_bd_cell -type ip -vlnv xilinx.com:ip:xfft:9.1 $module_name
   set_property -dict [list CONFIG.transform_length $fft_size ] [get_bd_cells $module_name]
   set_property -dict [list CONFIG.data_format.VALUE_SRC USER CONFIG.input_width.VALUE_SRC USER] [get_bd_cells $module_name]
   set_property -dict [list CONFIG.target_clock_frequency $fft_clk] [get_bd_cells $module_name]
   set_property -dict [list CONFIG.implementation_options {pipelined_streaming_io}] [get_bd_cells $module_name]
   set_property -dict [list CONFIG.data_format {fixed_point} CONFIG.input_width {16} CONFIG.phase_factor_width {16}] [get_bd_cells $module_name]
   set_property -dict [list CONFIG.scaling_options {block_floating_point} CONFIG.rounding_modes $rounding_modes] [get_bd_cells $module_name]
   
   set_property -dict [list CONFIG.run_time_configurable_transform_length {true} ] [get_bd_cells $module_name]
   set_property -dict [list CONFIG.output_ordering {natural_order} ] [get_bd_cells $module_name]
   set_property -dict [list CONFIG.cyclic_prefix_insertion {true} ] [get_bd_cells $module_name]   
   set_property -dict [list CONFIG.number_of_stages_using_block_ram_for_data_and_phase_factors $STAGE_BRAM ] [get_bd_cells $module_name]
   set_property -dict [list CONFIG.memory_options_hybrid {true}] [get_bd_cells $module_name]
   set_property -dict [list CONFIG.aclken {true} ]  [get_bd_cells $module_name]
   set_property -dict [list CONFIG.aresetn {true} ] [get_bd_cells $module_name]
   endgroup
   
   startgroup
   make_bd_pins_external  [get_bd_cells $module_name]
   make_bd_intf_pins_external  [get_bd_cells $module_name]
   endgroup
   
   regenerate_bd_layout
   validate_bd_design -force

   generate_target all [get_files  $prj_name.srcs/sources_1/bd/fft_bd/fft_bd.bd]
   catch { config_ip_cache -export [get_ips -all fft_bd_ifft_cc0_0] }
   export_ip_user_files -of_objects [get_files $prj_name.srcs/sources_1/bd/fft_bd/fft_bd.bd] -no_script -sync -force -quiet
   create_ip_run [get_files -of_objects [get_fileset sources_1] $prj_name.srcs/sources_1/bd/fft_bd/fft_bd.bd]
   export_simulation -of_objects [get_files $prj_name.srcs/sources_1/bd/fft_bd/fft_bd.bd] -directory $prj_name.ip_user_files/sim_scripts -ip_user_files_dir $prj_name.ip_user_files -ipstatic_source_dir $prj_name.ip_user_files/ipstatic -lib_map_path [list {modelsim=$prj_name.cache/compile_simlib/modelsim} {questa=$prj_name.cache/compile_simlib/questa}  ] -use_ip_compiled_libs -force -quiet

   #make_wrapper -files [get_files $prj_name.srcs/sources_1/bd/fft_bd/fft_bd.bd] -top
   #add_files -norecurse $prj_name.srcs/sources_1/bd/fft_bd/hdl/fft_bd_wrapper.v
   add_files -norecurse src/xFFT_wrapper.sv


   if { $run_syn == "true" } {
      launch_runs synth_1 -jobs 12
      wait_on_run synth_1
      open_run synth_1 -name synth_1
      report_utilization -file "FFT_report${fft_size}_${STAGE_BRAM}.txt" -name utilization_1
   }

   set_property -name {xsim.simulate.runtime} -value {50000ns} -objects [get_filesets sim_1]
   set_property -name {xsim.simulate.log_all_signals} -value {true} -objects [get_filesets sim_1]
   set_property -name {xsim.simulate.wdb} -value {./sim/tb_multi_ifft_waveform.wcfg} -objects [get_filesets sim_1]
} elseif { $ip_cfg_mode == "update" } {
puts "************ Updating the FFT module in design  ************ "
   startgroup
   create_bd_cell -type ip -vlnv xilinx.com:ip:xfft:9.1 $module_name
   set_property -dict [list CONFIG.transform_length $fft_size ] [get_bd_cells $module_name]
   set_property -dict [list CONFIG.data_format.VALUE_SRC USER CONFIG.input_width.VALUE_SRC USER] [get_bd_cells $module_name]
   set_property -dict [list CONFIG.target_clock_frequency $fft_clk] [get_bd_cells $module_name]
   set_property -dict [list CONFIG.implementation_options {pipelined_streaming_io}] [get_bd_cells $module_name]
   set_property -dict [list CONFIG.data_format {fixed_point} CONFIG.input_width {16} CONFIG.phase_factor_width {16}] [get_bd_cells $module_name]
   set_property -dict [list CONFIG.scaling_options {block_floating_point} CONFIG.rounding_modes $rounding_modes] [get_bd_cells $module_name]
   
   set_property -dict [list CONFIG.run_time_configurable_transform_length {true} ] [get_bd_cells $module_name]
   set_property -dict [list CONFIG.output_ordering {natural_order} ] [get_bd_cells $module_name]
   set_property -dict [list CONFIG.cyclic_prefix_insertion {true} ] [get_bd_cells $module_name]   
   set_property -dict [list CONFIG.number_of_stages_using_block_ram_for_data_and_phase_factors $STAGE_BRAM ] [get_bd_cells $module_name]
   set_property -dict [list CONFIG.memory_options_hybrid {true}] [get_bd_cells $module_name]
   set_property -dict [list CONFIG.aclken {true} ]  [get_bd_cells $module_name]
   set_property -dict [list CONFIG.aresetn {true} ] [get_bd_cells $module_name]
   endgroup

   regenerate_bd_layout
   validate_bd_design -force

   make_wrapper -files [get_files $prj_name.srcs/sources_1/bd/fft_bd/fft_bd.bd] -top


   if { $run_syn == "true" } {
      reset_run synth_1
      launch_runs synth_1 -jobs 12
      wait_on_run synth_1
      open_run synth_1 -name synth_1
      report_utilization -file "FFT_report${fft_size}_${STAGE_BRAM}.txt" -name utilization_1
   }
}
