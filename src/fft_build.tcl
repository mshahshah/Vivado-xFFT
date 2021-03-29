
set prj_path [pwd]
cd  $prj_path
puts "project path is :$prj_path"

source src/build_fft_cfg.tcl
set mode [lindex $argv 0]

switch $fft_size  {
   128  { set n_stage  0 }
   256  { set n_stage  1 }
   512  { set n_stage  2 }
   1024 { set n_stage  3 }
   2048 { set n_stage  4 }
   default { puts "Error : Incorrect fft size"   }
}

switch $rounding  {
   "round"  { set rounding_modes  "convergent_rounding" }
   "trunc"  { set rounding_modes  "truncation" }
   default { puts "Error : Incorrect rounding_modes"}
}


if { $ip_cfg_mode == "new" } {
puts "************ Building a new BD design  ************ "
   create_project -force $prj_name  $prj_path
   set_property board_part xilinx.com:zcu102:part0:3.3 [current_project]
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
   set_property -dict [list CONFIG.number_of_stages_using_block_ram_for_data_and_phase_factors {3} ] [get_bd_cells $module_name]
   endgroup
   
   startgroup
   make_bd_pins_external  [get_bd_cells $module_name]
   make_bd_intf_pins_external  [get_bd_cells $module_name]
   endgroup
   
   regenerate_bd_layout
   validate_bd_design -force

   make_wrapper -files [get_files $prj_name.srcs/sources_1/bd/fft_bd/fft_bd.bd] -top
   add_files -norecurse $prj_name.srcs/sources_1/bd/fft_bd/hdl/fft_bd_wrapper.v

   set_property SOURCE_SET sources_1 [get_filesets sim_1]
   add_files -fileset sim_1 -norecurse src/time_controller.v
   add_files -fileset sim_1 -norecurse src/tb_ifft.sv
   update_compile_order -fileset sim_1

} elseif { $ip_cfg_mode == "update" } {
puts "************ Updating the FFT module in design  ************ "
   startgroup
   set_property -dict [list CONFIG.transform_length $fft_size ] [get_bd_cells $module_name]
   set_property -dict [list CONFIG.data_format.VALUE_SRC USER CONFIG.input_width.VALUE_SRC USER] [get_bd_cells $module_name]
   set_property -dict [list CONFIG.target_clock_frequency $fft_clk] [get_bd_cells $module_name]
   set_property -dict [list CONFIG.implementation_options {pipelined_streaming_io}] [get_bd_cells $module_name]
   set_property -dict [list CONFIG.data_format {fixed_point} CONFIG.input_width {16} CONFIG.phase_factor_width {16}] [get_bd_cells $module_name]
   set_property -dict [list CONFIG.scaling_options {block_floating_point} CONFIG.rounding_modes $rounding_modes] [get_bd_cells $module_name]
   
   set_property -dict [list CONFIG.run_time_configurable_transform_length {true} ] [get_bd_cells $module_name]
   set_property -dict [list CONFIG.output_ordering {natural_order} ] [get_bd_cells $module_name]
   set_property -dict [list CONFIG.cyclic_prefix_insertion {true} ] [get_bd_cells $module_name]   
   set_property -dict [list CONFIG.number_of_stages_using_block_ram_for_data_and_phase_factors {3} ] [get_bd_cells $module_name]   
   endgroup             

   regenerate_bd_layout
   validate_bd_design -force

   make_wrapper -files [get_files $prj_name.srcs/sources_1/bd/fft_bd/fft_bd.bd] -top
}
