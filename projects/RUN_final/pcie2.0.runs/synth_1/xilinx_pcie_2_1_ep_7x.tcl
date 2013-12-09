# 
# Synthesis run script generated by Vivado
# 

  set_param gui.test TreeTableDev
create_project -in_memory -part xc7vx485tffg1761-2
set_param project.compositeFile.enableAutoGeneration 0

read_ip /afs/ece.cmu.edu/usr/gcharnma/Private/18-545/RUN_final/pcie2.0.srcs/sources_1/ip/clk_wiz_0/clk_wiz_0.xci
set_property used_in_implementation false [get_files -all /afs/ece.cmu.edu/usr/gcharnma/Private/18-545/RUN_final/pcie2.0.srcs/sources_1/ip/clk_wiz_0/clk_wiz_0/example_design/clk_wiz_0_exdes.xdc]
set_property used_in_implementation false [get_files -all /afs/ece.cmu.edu/usr/gcharnma/Private/18-545/RUN_final/pcie2.0.srcs/sources_1/ip/clk_wiz_0/clk_wiz_0_board.xdc]
set_property used_in_implementation false [get_files -all /afs/ece.cmu.edu/usr/gcharnma/Private/18-545/RUN_final/pcie2.0.srcs/sources_1/ip/clk_wiz_0/clk_wiz_0.xdc]
set_property used_in_implementation false [get_files -all /afs/ece.cmu.edu/usr/gcharnma/Private/18-545/RUN_final/pcie2.0.srcs/sources_1/ip/clk_wiz_0/clk_wiz_0_OOC.xdc]
set_property is_locked true [get_files /afs/ece.cmu.edu/usr/gcharnma/Private/18-545/RUN_final/pcie2.0.srcs/sources_1/ip/clk_wiz_0/clk_wiz_0.xci]

read_ip /afs/ece.cmu.edu/usr/gcharnma/Private/18-545/RUN_final/pcie2.0.srcs/sources_1/ip/blk_mem_gen_0/blk_mem_gen_0.xci
set_property used_in_implementation false [get_files -all /afs/ece.cmu.edu/usr/gcharnma/Private/18-545/RUN_final/pcie2.0.srcs/sources_1/ip/blk_mem_gen_0/blk_mem_gen_0/example_design/blk_mem_gen_0_exdes.xdc]
set_property used_in_implementation false [get_files -all /afs/ece.cmu.edu/usr/gcharnma/Private/18-545/RUN_final/pcie2.0.srcs/sources_1/ip/blk_mem_gen_0/blk_mem_gen_0/blk_mem_gen_0_ooc.xdc]
set_property is_locked true [get_files /afs/ece.cmu.edu/usr/gcharnma/Private/18-545/RUN_final/pcie2.0.srcs/sources_1/ip/blk_mem_gen_0/blk_mem_gen_0.xci]

read_ip /afs/ece.cmu.edu/usr/gcharnma/Private/18-545/RUN_final/pcie2.0.srcs/sources_1/ip/vc707_pcie_x8_gen2/vc707_pcie_x8_gen2.xci
set_property used_in_implementation false [get_files -all /afs/ece.cmu.edu/usr/gcharnma/Private/18-545/RUN_final/pcie2.0.srcs/sources_1/ip/vc707_pcie_x8_gen2/vc707_pcie_x8_gen2/example_design/xilinx_pcie_7x_ep_x8g2_VC707.xdc]
set_property used_in_implementation false [get_files -all /afs/ece.cmu.edu/usr/gcharnma/Private/18-545/RUN_final/pcie2.0.srcs/sources_1/ip/vc707_pcie_x8_gen2/vc707_pcie_x8_gen2/source/vc707_pcie_x8_gen2-PCIE_X1Y0.xdc]
set_property used_in_implementation false [get_files -all /afs/ece.cmu.edu/usr/gcharnma/Private/18-545/RUN_final/pcie2.0.srcs/sources_1/ip/vc707_pcie_x8_gen2/synth/vc707_pcie_x8_gen2_ooc.xdc]
set_property is_locked true [get_files /afs/ece.cmu.edu/usr/gcharnma/Private/18-545/RUN_final/pcie2.0.srcs/sources_1/ip/vc707_pcie_x8_gen2/vc707_pcie_x8_gen2.xci]

read_verilog -sv {
  /afs/ece.cmu.edu/usr/gcharnma/Private/18-545/RUN_final/pcie2.0.srcs/sources_1/imports/example_design/window_handler_gun.sv
  /afs/ece.cmu.edu/usr/gcharnma/Private/18-545/RUN_final/pcie2.0.srcs/sources_1/imports/example_design/template_handler.sv
  /afs/ece.cmu.edu/usr/gcharnma/Private/18-545/RUN_final/pcie2.0.srcs/sources_1/imports/example_design/ncc.sv
  /afs/ece.cmu.edu/usr/gcharnma/Private/18-545/RUN_final/pcie2.0.srcs/sources_1/imports/example_design/average.sv
  /afs/ece.cmu.edu/usr/gcharnma/Private/18-545/RUN_final/pcie2.0.srcs/sources_1/imports/example_design/user_FPGA_format.sv
  /afs/ece.cmu.edu/usr/gcharnma/Private/18-545/RUN_final/pcie2.0.srcs/sources_1/imports/example_design/address_translator.sv
  /afs/ece.cmu.edu/usr/gcharnma/Private/18-545/RUN_final/pcie2.0.srcs/sources_1/imports/example_design/user_interface.sv
  /afs/ece.cmu.edu/usr/gcharnma/Private/18-545/RUN_final/pcie2.0.srcs/sources_1/imports/example_design/PIO_EP_astroFPGA_MEM.sv
}
read_verilog {
  /afs/ece.cmu.edu/usr/gcharnma/Private/18-545/RUN_final/pcie2.0.srcs/sources_1/imports/example_design/PIO_TX_ENGINE.v
  /afs/ece.cmu.edu/usr/gcharnma/Private/18-545/RUN_final/pcie2.0.srcs/sources_1/imports/example_design/PIO_RX_ENGINE.v
  /afs/ece.cmu.edu/usr/gcharnma/Private/18-545/RUN_final/pcie2.0.srcs/sources_1/imports/example_design/PIO_TO_CTRL.v
  /afs/ece.cmu.edu/usr/gcharnma/Private/18-545/RUN_final/pcie2.0.srcs/sources_1/imports/example_design/PIO_EP.v
  /afs/ece.cmu.edu/usr/gcharnma/Private/18-545/RUN_final/pcie2.0.srcs/sources_1/imports/example_design/PIO.v
  /afs/ece.cmu.edu/usr/gcharnma/Private/18-545/RUN_final/pcie2.0.srcs/sources_1/imports/example_design/pcie_app_7x.v
  /afs/ece.cmu.edu/usr/gcharnma/Private/18-545/RUN_final/pcie2.0.srcs/sources_1/imports/example_design/xilinx_pcie_2_1_ep_7x.v
}
read_xdc /afs/ece.cmu.edu/usr/gcharnma/Private/18-545/RUN_final/pcie2.0.srcs/constrs_1/imports/example_design/xilinx_pcie_7x_ep_x8g2_VC707.xdc
set_property used_in_implementation false [get_files /afs/ece.cmu.edu/usr/gcharnma/Private/18-545/RUN_final/pcie2.0.srcs/constrs_1/imports/example_design/xilinx_pcie_7x_ep_x8g2_VC707.xdc]

read_xdc dont_touch.xdc
set_property used_in_implementation false [get_files dont_touch.xdc]
set_param synth.vivado.isSynthRun true
set_property webtalk.parent_dir /afs/ece.cmu.edu/usr/gcharnma/Private/18-545/RUN_final/pcie2.0.data/wt [current_project]
set_property parent.project_dir /afs/ece.cmu.edu/usr/gcharnma/Private/18-545/RUN_final [current_project]
synth_design -top xilinx_pcie_2_1_ep_7x -part xc7vx485tffg1761-2 -flatten_hierarchy full -gated_clock_conversion auto
write_checkpoint xilinx_pcie_2_1_ep_7x.dcp
report_utilization -file xilinx_pcie_2_1_ep_7x_utilization_synth.rpt -pb xilinx_pcie_2_1_ep_7x_utilization_synth.pb
