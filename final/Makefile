CC=vcs

CFLAGS=-sverilog -R -debug_all #+v2k #-assert filter -assert enable_diag
DFLAGS=-sverilog -debug_all

all: user_FPGA_format.sv address_translator.sv user_FPGA_test.sv window_handler.sv window_holder.sv ncc.sv template_handler.sv testBenches.sv
	$(CC) $(CFLAGS) user_FPGA_format.sv address_translator.sv user_FPGA_test.sv window_handler.sv window_holder.sv ncc.sv template_handler.sv testBenches.sv

dylan: ncc.sv win_tb.sv
	$(CC) $(CFLAGS) ncc.sv win_tb.sv

gun: gun_tb.sv user_FPGA_format.sv
	$(CC) $(CFLAGS) tbUserInterface.sv user_interface.sv user_FPGA_format.sv address_translator.sv user_FPGA_test.sv window_handler.sv window_holder.sv ncc.sv template_handler.sv average.sv 

window_handler: window_handler_mine.sv address_translator.sv tbWindow_holder.sv
	$(CC) $(CFLAGS) window_handler_mine.sv address_translator.sv tbWindow_holder.sv


clean:
	rm -rf simv
	rm -rf simv.daidir
	rm -rf csrc
	rm -rf ucli.key
	rm -rf simv.vdb
	rm -rf DVEfiles
	rm -rf inter.vpd
