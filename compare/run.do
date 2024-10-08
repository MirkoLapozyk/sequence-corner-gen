onbreak {resume}
#onerror {quit -f}

# Create the library.
if [file exists work] { vdel -all }

vlib work

#define directories
set packages_path "./fpu_32_64_new/src/pkg"
set include_path  "./fpu_32_64_new/src/include"
set rtl_path      "./fpu_32_64_new/src/rtl"

# Compile the sources.



#includevsim   
vlog -sv $include_path/registers.svh

#packages
vlog -sv $packages_path/fpuv_pkg.sv


#rtl
vlog -sv $rtl_path/fpuv_top.svp "+incdir+$include_path"


#tb
#vlog -sv -dpiheader dpiheader.h fpu_tb.sv fpu_tb.c 
vlog -sv  fpu_tb.sv

# Simulate the design.
vsim -voptargs=+acc=r fpu_tb

# View the results.
#if {![batch_mode]} {
#	log -r *
#	wave zoomfull
#}
run -all


#  vsim -batch -do run.do