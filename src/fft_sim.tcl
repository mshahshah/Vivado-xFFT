
set prj_path [pwd]
cd  $prj_path
puts "project path is :$prj_path"

source src/build_fft_cfg.tcl
set sim_mode [lindex $argv 0]

set sim_len [expr {35000 + $nSymbols*10000}]
puts "The simulation len is : $sim_len"

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


if { $sim_mode == "sim" } {
   puts "Running the Simulation in new sim mode"
   open_project  $prj_name.xpr
   generate_target Simulation [get_files $prj_name.srcs/sources_1/bd/fft_bd/fft_bd.bd]
   export_ip_user_files -of_objects [get_files $prj_name.srcs/sources_1/bd/fft_bd/fft_bd.bd] -no_script -sync -force -quiet
   export_simulation -of_objects [get_files $prj_name.srcs/sources_1/bd/fft_bd/fft_bd.bd] -directory $prj_name.ip_user_files/sim_scripts -ip_user_files_dir $prj_name.ip_user_files -ipstatic_source_dir $prj_name.ip_user_files/ipstatic -use_ip_compiled_libs -force -quiet
   set_property -name {xsim.simulate.runtime} -value {$sim_len} -objects [get_filesets sim_1]
   launch_simulation -mode behavioral 
   source tb_ifft.tcl
   #open_wave_config tb_ifft_behav.wcfg
   
} elseif { $sim_mode == "resim" } {
   puts "Running the Simulation in resim mode"
   relaunch_sim
}
