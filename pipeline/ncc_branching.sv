`default_nettype none
module ncc
	#(parameter descSize = 2048,
	 parameter numPixelsDesc = 256,
	 parameter windowSize = 640)
	(input logic clk, rst, window_data_ready, desc_data_ready,
	input bit [35:0] desc_data_in,
	input bit signed [8:0] window_data_in [15:0] [15:0],
	output logic done_with_window_data, done_with_desc_data,
    output logic result_ready,
	output bit signed [31:-32] greatestNCC,
	output bit [12:0] greatestWindowIndex

    );
    //EXTRANEOUS
    bit [31:0]   accOut [15:0] [15:0];
    bit [31:0]   denDesc;
    bit          dataReadyDenDesc;
    bit [31:0]   denWin;
    bit          dataReadyDenWin;
    bit          dataReady;
    bit [9:-54]  denomLog2Latch;
    bit          denomLog2Ready;
    //END EXTRANEOUS
    bit my_rst;
    bit [12:0] my_counter;

    bit signed [31:0] accIn [15:0] [15:0];
    bit en1, en2, en3, en4, en4Desc, en4Win, en5;
    bit  [31:0]      numerator;
    assign accIn = '{default:0};

    bit [10:-54]                inputToPE_desc [15:0] [15:0];
    bit [10:-54]                inputToPE_window [15:0] [15:0];

    numeratorDescriptor  nd(.en(desc_data_ready), .desc_array_out(inputToPE_desc), .rst(rst | my_rst), .*);
    numeratorWindow nw(.en_out(en2), .en(window_data_ready), .window_data_out(inputToPE_window), .rst(rst | my_rst), .*);


    bit [31:0]                  descPixelOut [15:0][15:0];
    bit [31:0]                  windowPixelOut [15:0][15:0];

	genvar i, j;
	//generate 16x16 PE grid
	generate
		for (i = 0; i < 16; i++) begin
			for (j = 0; j < 16; j++) begin
				processingElement PE_inst(.clk(clk), .rst(rst | my_rst), .descPixelLog2In(inputToPE_desc[i][j]), .windowPixelLog2In(inputToPE_window[i][j]), .loadDescReg(en2), .loadWinReg(en2), .accIn(accIn[i][j]), .descPixelOut(descPixelOut[i][j]), .windowPixelOut(windowPixelOut[i][j]), .accOut(accOut[i][j]));
			end
		end
	endgenerate

    //NUMERATOR COMPUTATION
    bit [31:0] treeAdderIn [15:0][15:0];
    //latch the data returned from the PE
    latchNumWinDesc lnwd(.en(en3), .data_in(accOut), .data_out(treeAdderIn), .en_out(en4), .rst(rst | my_rst), .*);


    //DENOMINATOR COMPUTATION
    bit [31:0] treeAdderDescIn [15:0][15:0];
    bit [31:0] treeAdderWinIn [15:0][15:0];
    //latch the data returned from the PE
    latchNumWinDesc ld(.en(en3), .data_in(descPixelOut), .data_out(treeAdderDescIn), .en_out(en4Desc),  .rst(rst | my_rst),.*);
    latchNumWinDesc lw(.en(en3), .data_in(windowPixelOut), .data_out(treeAdderWinIn), .en_out(en4Win), .rst(rst | my_rst), .*);

    always_ff @(posedge clk, posedge my_rst, posedge rst) begin
        if (my_rst|rst) begin
            en3 <= 0;
        end
        else begin
            en3 <= en2;
        end
    end
    
    //NUMERATOR: treeadder code here
    tree_adder #(32) ta (.enable(en4), .operand(treeAdderIn), .sum_result(numerator), .rst_n(~rst | ~my_rst), .*);

    //DENOMINATOR:
    tree_adder #(32) ta_desc (.enable(en4Desc), .operand(treeAdderDescIn), .sum_result(denDesc), .dataReady(dataReadyDenDesc), .rst_n(~rst | ~my_rst), .*);
    tree_adder #(32) ta_win (.enable(en4Win), .operand(treeAdderWinIn), .sum_result(denWin), .dataReady(dataReadyDenWin), .rst_n(~rst | ~my_rst), .*);

    //latch the result
    bit [31:0] descSumOfSquares, winSumOfSquares;
    bit [10:-54] descSumOfSquaresLog2, winSumOfSquaresLog2;
    bit sumSquaresReady;
    bit  [31:0]      numeratorReg;
    always_ff @(posedge clk, posedge my_rst, posedge rst) begin
        if (my_rst | rst) begin
            descSumOfSquares <= 0;
            winSumOfSquares <= 0;
            sumSquaresReady <= 0;
            numeratorReg <= 0;
        end
        else begin
            descSumOfSquares <= denDesc;
            winSumOfSquares <= denWin;
            sumSquaresReady <= dataReadyDenWin;
            numeratorReg <= numerator;
        end
    end

    //convert back to log 2 and finish off the math
    
	bit [10:-54] numeratorLog2;
	log2 denom_desc_log2_inst (descSumOfSquares, descSumOfSquaresLog2);
	log2 denom_win_log2_inst (winSumOfSquares, winSumOfSquaresLog2);
	log2 num_log2_inst (numeratorReg, numeratorLog2);

    //latch the result
    bit [10:-54] winSumSquaresLatch, descSumSquaresLatch;
    bit sumSquaresLog2Ready;
    bit  [10:-54]      numeratorReg1;
    always_ff @(posedge clk, posedge rst, posedge my_rst) begin
        if (my_rst | rst) begin
            winSumSquaresLatch <= 0;
            descSumSquaresLatch <= 0;
            sumSquaresLog2Ready <= 0;
            numeratorReg1 <= 0;
        end
        else begin
            winSumSquaresLatch <= winSumOfSquaresLog2;
            descSumSquaresLatch <= descSumOfSquaresLog2;
            sumSquaresLog2Ready <= sumSquaresReady;
            numeratorReg1 <= numeratorLog2;
        end
    end

	//part 2 of denominator
    bit [9:-54] denomLog2;
	assign denomLog2 = (descSumSquaresLatch[9:-54] + winSumSquaresLatch[9:-54]) >> 1;

    //latch the result

    //bit [10:-54] denomLog2Latch;
    //bit denomLog2Ready;
    bit  [10:-54]      numeratorReg2;
    always_ff @(posedge clk, posedge rst, posedge my_rst) begin
        if (my_rst | rst) begin
            denomLog2Ready <= 0;
            denomLog2Latch <=  0;
            numeratorReg2 <= 0;
        end
        else begin
            denomLog2Latch <= denomLog2;
            denomLog2Ready <= sumSquaresLog2Ready;
            numeratorReg2 <= numeratorReg1;
        end
    end

/////////// DYLAN ///////////////////
	//final computation
	bit [9:-54] numLog2;
	bit signed [9:-54] corrCoeffLog2;
	always_comb begin
		if (numeratorReg2[10] == 1'b1) begin
			numLog2 = ~(numeratorReg2[9:-54])+1;
		end
		else begin
			numLog2 = numeratorReg2[9:-54];
		end
		corrCoeffLog2 = signed'(numLog2) - signed'(denomLog2);
		//if (corrCoeffLog2 > numeratorLog2[9:-54]) begin
	//		corrCoeffLog2 =  {10'd1, 54'd0};
	//	end
	end

	bit signed [31:-32] correlationCoefficient, corrCoeff;
	ilog2_negatives coeff_ilog2_inst (corrCoeffLog2, corrCoeff);
	always_comb begin
		if (numeratorLog2[10] == 1'b1) begin
			correlationCoefficient = ~corrCoeff + 1;
		end
		else begin
			correlationCoefficient = corrCoeff;
		end
	end
	
	//register to store the entire patch acc total sum
	//register #(32) accReg (accPatchSum, clk, rst, loadAccSumReg, accTotalSum);

	logic loadGreatestReg, clearWinCount, clearGreatestReg;
	bit [12:0] windowCount;
	//register to store greatest correlation coefficient and window index
	//priorityRegisterFP #(13) greatestNCCRegFP (correlationCoefficient, windowCount, clk, rst, loadGreatestReg, clearGreatestReg, greatestNCC, greatestWindowIndex);
	priorityRegisterFP #(13) greatestNCCRegFP (correlationCoefficient, windowCount, clk, (rst | my_rst), denomLog2Ready, clearGreatestReg, greatestNCC, greatestWindowIndex);
	counter #(13) windowCounter (clk, (rst | my_rst), clearWinCount, loadGreatestReg, windowCount);

    //assign done_with_window_data = denomLog2Ready;

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            done_with_window_data <= 0;
            result_ready <= 0;
            my_rst <= 1;
            my_counter <= 0;
        end
        else if (denomLog2Ready & my_counter+1 == 13'd4096) begin
            my_counter <= 0;
            result_ready <= 1;
            my_rst <= 0;
            done_with_window_data <= denomLog2Ready;
        end
        else if (result_ready) begin
            my_counter <= 0;
            my_rst <= 1;
            result_ready <= 0;
            done_with_window_data <= denomLog2Ready;
        end
        else begin
            my_counter <= my_counter + 1'd1;
            my_rst <= 0;
            result_ready <= 0;
            done_with_window_data <= denomLog2Ready;
        end
    end

endmodule: ncc


module absoluteValueFP
	#(parameter signBit = 32)
	(input bit signed [31:-32] dataIn,
	output bit signed [31:-32] dataOut);

	bit dataSign;

	assign dataSign = dataIn[signBit-1];
	assign dataOut = (dataSign) ? ~dataIn + 1 : dataIn;

endmodule: absoluteValueFP



module counter
	#(parameter w = 256)
	(input logic clk, rst, clr, enable,
	output bit [w-1:0] count);

	always_ff @(posedge clk, posedge rst) begin
		if (rst) begin
			count <= 'd0;
		end
		else if (clr) begin
			count <= 'd0;
		end
		else if (enable) begin
			count <= count + 'd1;
		end
	end
endmodule: counter

module priorityRegisterFP
	#(parameter w2 = 12)
	(input bit signed[31:-32] dataIn,
	input bit [w2-1:0] dataIn2,
	input bit clk, rst, load, clear,
	output bit signed [31:-32] dataOut,
	output bit	[w2-1:0] dataOut2);

	bit signed [31:-32] dataInAbs, dataOutAbs, data;
	bit [w2-1:0] data2;

	absoluteValueFP #(32) absValInFP_inst (dataIn, dataInAbs);
	absoluteValueFP #(32) absValOutFP_inst (dataOut, dataOutAbs);

	assign data = (dataInAbs > dataOutAbs) ? dataIn : dataOut;
	assign data2 = (dataIn > dataOut) ? dataIn2 : dataOut2;

	always_ff @(posedge clk, posedge rst) begin
		if (rst) begin
			dataOut <= 'd0;
			dataOut2 <= 'd0;
		end
		else if (clear) begin
			dataOut <= 'd0;
			dataOut2 <= 'd0;
		end
		else if (load) begin
			dataOut <= data;
			dataOut2 <= data2;
		end
	end
endmodule: priorityRegisterFP

module denominatorTop(
        input bit               clk,
        input bit               rst,
        input bit               window_data_ready,
        input bit  [8:0]        window_data_in [15:0] [15:0],
        input bit               desc_data_ready,
        input bit  [35:0]       desc_data_in,

        output bit [31:0]       accOut[15:0][15:0],
        output bit  [31:0]      denDesc,
        output bit              dataReadyDenDesc,
        output bit  [31:0]      denWin,
        output bit              dataReadyDenWin,
        output bit [9:-54]      denomLog2Latch,
        output bit              denomLog2Ready
    );

    bit signed [31:0] accIn [15:0] [15:0];
    bit en1, en2, en3, en4Desc, en4Win, en5;
    assign accIn = '{default:0};

    bit [10:-54]                inputToPE_desc [15:0] [15:0];
    bit [10:-54]                inputToPE_window [15:0] [15:0];

    numeratorDescriptor  nd(.en(desc_data_ready), .desc_array_out(inputToPE_desc), .*);
    numeratorWindow nw(.en_out(en2), .en(window_data_ready), .window_data_out(inputToPE_window), .*);


    bit [31:0]                  descPixelOut [15:0][15:0];
    bit [31:0]                  windowPixelOut [15:0][15:0];

	genvar i, j;
	//generate 16x16 PE grid
	generate
		for (i = 0; i < 16; i++) begin
			for (j = 0; j < 16; j++) begin
				processingElement PE_inst(.clk(clk), .rst(rst), .descPixelLog2In(inputToPE_desc[i][j]), .windowPixelLog2In(inputToPE_window[i][j]), .loadDescReg(en2), .loadWinReg(en2), .accIn(accIn[i][j]), .descPixelOut(descPixelOut[i][j]), .windowPixelOut(windowPixelOut[i][j]), .accOut(accOut[i][j]));
			end
		end
	endgenerate

    bit [31:0] treeAdderDescIn [15:0][15:0];
    bit [31:0] treeAdderWinIn [15:0][15:0];
    //latch the data returned from the PE
    latchNumWinDesc ld(.en(en3), .data_in(descPixelOut), .data_out(treeAdderDescIn), .en_out(en4Desc), .*);
    latchNumWinDesc lw(.en(en3), .data_in(windowPixelOut), .data_out(treeAdderWinIn), .en_out(en4Win), .*);

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            en3 <= 0;
        end
        else begin
            en3 <= en2;
        end
    end

    //treeadder code here
    tree_adder #(32) ta_desc (.rst_n(~rst), .enable(en4Desc), .operand(treeAdderDescIn), .sum_result(denDesc), .dataReady(dataReadyDenDesc), .*);
    tree_adder #(32) ta_win (.rst_n(~rst), .enable(en4Win), .operand(treeAdderWinIn), .sum_result(denWin), .dataReady(dataReadyDenWin), .*);


    //latch the result
    bit [31:0] descSumOfSquares, winSumOfSquares;
    bit [10:-54] descSumOfSquaresLog2, winSumOfSquaresLog2;
    bit sumSquaresReady;
    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            descSumOfSquares <= 0;
            winSumOfSquares <= 0;
            sumSquaresReady <= 0;
        end
        else begin
            descSumOfSquares <= denDesc;
            winSumOfSquares <= denWin;
            sumSquaresReady <= dataReadyDenWin;
        end
    end

    //convert back to log 2 and finish off the math
    
/////////// DYLAN ///////////////////
	log2 denom_desc_log2_inst (descSumOfSquares, descSumOfSquaresLog2);
	log2 denom_win_log2_inst (winSumOfSquares, winSumOfSquaresLog2);

    //latch the result
    bit [10:-54] winSumSquaresLatch, descSumSquaresLatch;
    bit sumSquaresLog2Ready;
    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            winSumSquaresLatch <= 0;
            descSumSquaresLatch <= 0;
            sumSquaresLog2Ready <= 0;
        end
        else begin
            winSumSquaresLatch <= winSumOfSquaresLog2;
            descSumSquaresLatch <= descSumOfSquaresLog2;
            sumSquaresLog2Ready <= sumSquaresReady;
        end
    end

	//part 2 of denominator
    bit [9:-54] denomLog2;
	assign denomLog2 = (descSumSquaresLatch[9:-54] + winSumSquaresLatch[9:-54]) >> 1;

    //latch the result

    //bit [10:-54] denomLog2Latch;
    //bit denomLog2Ready;
    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            denomLog2Ready <= 0;
            denomLog2Latch <=  0;
        end
        else begin
            denomLog2Latch <= denomLog2;
            denomLog2Ready <= sumSquaresLog2Ready;
        end
    end

    /*
	//final computation
	always_comb begin
		if (numeratorLog2[10] == 1'b1) begin
			numLog2 = ~(numeratorLog2[9:-54])+1;
		end
		else begin
			numLog2 = numeratorLog2[9:-54];
		end
		corrCoeffLog2 = signed'(numLog2) - signed'(denomLog2);
		//if (corrCoeffLog2 > numeratorLog2[9:-54]) begin
	//		corrCoeffLog2 =  {10'd1, 54'd0};
	//	end
	end

	ilog2_negatives coeff_ilog2_inst (corrCoeffLog2, corrCoeff);
	always_comb begin
		if (numeratorLog2[10] == 1'b1) begin
			correlationCoefficient = ~corrCoeff + 1;
		end
		else begin
			correlationCoefficient = corrCoeff;
		end
	end
	
	//register to store the entire patch acc total sum
	//register #(32) accReg (accPatchSum, clk, rst, loadAccSumReg, accTotalSum);

	logic loadGreatestReg, clearWinCount, clearGreatestReg;
	bit [12:0] windowCount;
	//register to store greatest correlation coefficient and window index
	priorityRegisterFP #(13) greatestNCCRegFP (correlationCoefficient, windowCount, clk, rst, loadGreatestReg, clearGreatestReg, greatestNCC, greatestWindowIndex);
	counter #(13) windowCounter (clk, rst, clearWinCount, loadGreatestReg, windowCount);
*/


/////////// DYLAN ///////////////////


endmodule:denominatorTop




module numeratorTop(
        input bit               clk,
        input bit               rst,
        input bit               window_data_ready,
        input bit  [8:0]        window_data_in [15:0] [15:0],
        input bit               desc_data_ready,
        input bit  [35:0]       desc_data_in,

//        output bit              en_out,
//        output bit [31:0]       windowPixelOut [15:0] [15:0],
//        output bit [31:0]       descPixelOut [15:0] [15:0],
//        output bit [10:-54]     descPixelLog2 [15:0] [15:0],
//        output bit [10:-54]     windowPixelLog2 [15:0] [15:0],
        output bit [31:0]       accOut[15:0][15:0],
        output bit              dataReady,
        output bit  [31:0]      numerator
    );

    bit signed [31:0] accIn [15:0] [15:0];
    bit en1, en2, en3, en4, en5;
    assign accIn = '{default:0};

    bit [10:-54]                inputToPE_desc [15:0] [15:0];
    bit [10:-54]                inputToPE_window [15:0] [15:0];

    numeratorDescriptor  nd(.en(desc_data_ready), .desc_array_out(inputToPE_desc), .*);
    numeratorWindow nw(.en_out(en2), .en(window_data_ready), .window_data_out(inputToPE_window), .*);


    bit [31:0]                  descPixelOut [15:0][15:0];
    bit [31:0]                  windowPixelOut [15:0][15:0];

	genvar i, j;
	//generate 16x16 PE grid
	generate
		for (i = 0; i < 16; i++) begin
			for (j = 0; j < 16; j++) begin
				processingElement PE_inst(.clk(clk), .rst(rst), .descPixelLog2In(inputToPE_desc[i][j]), .windowPixelLog2In(inputToPE_window[i][j]), .loadDescReg(en2), .loadWinReg(en2), .accIn(accIn[i][j]), .descPixelOut(descPixelOut[i][j]), .windowPixelOut(windowPixelOut[i][j]), .accOut(accOut[i][j]));
			end
		end
	endgenerate

    bit [31:0] treeAdderIn [15:0][15:0];
    //latch the data returned from the PE
    latchNumWinDesc lnwd(.en(en3), .data_in(accOut), .data_out(treeAdderIn), .en_out(en4), .*);

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            en3 <= 0;
        end
        else begin
            en3 <= en2;
        end
    end
    


    //treeadder code here
    tree_adder #(32) ta (.rst_n(~rst), .enable(en4), .operand(treeAdderIn), .sum_result(numerator), .*);

endmodule


module latchNumWinDesc (
    input bit                   en,
    input bit                   clk,
    input bit                   rst,
    input bit       [31:0]    data_in  [15:0] [15:0],
    output bit      [31:0]    data_out [15:0] [15:0],

    output bit                  en_out
    );

    always_ff @(posedge clk, posedge rst) begin
       
        if (rst) begin
            data_out <= '{default:0};
        end
        else if (en) begin
            data_out <= data_in;
        end
        else begin
            data_out <= data_out;
        end
        en_out <= en;
    end

endmodule:latchNumWinDesc



module processingElement
	(input bit	[10:-54]	descPixelLog2In,
	 input bit	[10:-54]	windowPixelLog2In,
	 input bit			clk, rst, loadDescReg, loadWinReg,
	 input bit signed [31:0] accIn,
	 output bit signed [31:0] descPixelOut,
	 output bit signed [31:0] windowPixelOut,
	 output bit	signed [31:0] accOut);
	
	bit [10:-54] descPixelLog2Out, windowPixelLog2Out;
	bit [9:-54] tempSumLog2, descPixelLog2, windowPixelLog2;
	bit [31:0] tempSum;
	bit descSignBit, winSignBit;
	assign descSignBit = descPixelLog2Out[10];
	assign winSignBit = windowPixelLog2Out[10];

	ilog2 ilog2_inst (tempSumLog2, tempSum);

	//register for descriptor pixel
	registerLog2 #(10) descReg (descPixelLog2In, clk, rst, loadDescReg, descPixelLog2Out);
	//register for storing "LTC"
	registerLog2 #(10) windowReg (windowPixelLog2In, clk, rst, loadWinReg, windowPixelLog2Out);

	//output the ilog2 of the square of the pixels for denominator computation
	assign descPixelLog2 = descPixelLog2Out[9:-54] << 1;
	assign windowPixelLog2 = windowPixelLog2Out[9:-54] << 1;
	ilog2 ilog2_desc_inst (descPixelLog2, descPixelOut);
	ilog2 ilog2_win_inst (windowPixelLog2, windowPixelOut);

	assign tempSumLog2 = descPixelLog2Out[9:-54] + windowPixelLog2Out[9:-54];
	assign accOut = (descSignBit ^ winSignBit) ? (accIn - signed'(tempSum)) : (accIn + signed'(tempSum));

endmodule: processingElement

module registerLog2
	#(parameter w = 10)
	(input bit	[w:-54]	dataIn,
	 input bit			clk, rst, load,
	 output bit	[w:-54] dataOut);

	always_ff @(posedge clk, posedge rst) begin
		if (rst) begin
			dataOut <= 'd0;
		end
		else if (load) begin
			dataOut <= dataIn;
		end
	end
endmodule: registerLog2

module numeratorWindow (
        input bit               en,
        input bit               clk,
        input bit               rst,
        input bit   [8:0]       window_data_in  [15:0] [15:0],
        output bit  [10:-54]    window_data_out [15:0] [15:0],
        output bit              en_out

    );

	bit [10:-54] windowLog2 [15:0] [15:0];
    latchNumWin lnw (.window_data_in(windowLog2),.*);

    //window log2 hardware
	genvar i, j;
	generate
		for (i = 0; i < 16; i++) begin
			for (j = 0; j < 16; j++) begin
				log2 windowLog2_inst({{23{window_data_in[i][j][8]}}, window_data_in[i][j]}, windowLog2[i][j]);
			end
		end
	endgenerate

endmodule:numeratorWindow

module latchNumWin (
    input bit                   en,
    input bit                   clk,
    input bit                   rst,
    input bit       [10:-54]    window_data_in  [15:0] [15:0],
    output bit      [10:-54]    window_data_out [15:0] [15:0],

    output bit                  en_out
    );

    always_ff @(posedge clk, posedge rst) begin
       
        if (rst) begin
            window_data_out <= '{default:0};
        end
        else if (en) begin
            window_data_out <= window_data_in;
        end
        else begin
            window_data_out <= window_data_out;
        end
        en_out <= en;
    end

endmodule:latchNumWin


// Takes in 36 bits (4 signed bytes of data)
// converts them to log2 and latches the results
module numeratorDescriptor(
    input bit                   en,
    input bit                   clk,
    input bit                   rst,
    input bit       [35:0]      desc_data_in,
    output bit      [10:-54]    desc_array_out  [15:0] [15:0]
    );
    

	bit [10:-54] descLog2 [3:0];
	log2 descLog2_inst1({{23{desc_data_in[35]}}, desc_data_in[35:27]}, descLog2[0]);
	log2 descLog2_inst2({{23{desc_data_in[26]}}, desc_data_in[26:18]}, descLog2[1]);
	log2 descLog2_inst3({{23{desc_data_in[17]}}, desc_data_in[17:9]}, descLog2[2]);
	log2 descLog2_inst4({{23{desc_data_in[8]}}, desc_data_in[8:0]}, descLog2[3]);

    latchNumDesc lnd (.desc_data_in(descLog2), .*);


endmodule:numeratorDescriptor

module latchNumDesc (
    input bit                   en,
    input bit                   clk,
    input bit                   rst,
    input bit       [10:-54]    desc_data_in    [3:0],
    output bit      [10:-54]    desc_array_out  [15:0] [15:0]
    );

    bit [4:0] iCounterOld, jCounterOld, iCounterNew, jCounterNew;


    always_comb begin
        iCounterNew = iCounterOld;
        jCounterNew = jCounterOld;

        if (en) begin
            if (jCounterOld + 5'd4 >= 5'd16) begin
                jCounterNew = 5'd0;
                iCounterNew = iCounterOld+5'd1;
            end
            else begin
                jCounterNew = jCounterNew + 5'd4;
            end
        end
    end

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            desc_array_out <= '{default:0};
        end
        else if (en) begin
            desc_array_out[iCounterOld][jCounterOld] <= desc_data_in[0];
            desc_array_out[iCounterOld][jCounterOld+5'd1] <= desc_data_in[1];
            desc_array_out[iCounterOld][jCounterOld+5'd2] <= desc_data_in[2];
            desc_array_out[iCounterOld][jCounterOld+5'd3] <= desc_data_in[3];

            jCounterOld <= jCounterNew;
            iCounterOld <= iCounterNew;
        end
        else begin
            desc_array_out <= desc_array_out;
        end
    end

endmodule: latchNumDesc


module log2
	(input bit signed [31:0] dataIn,
	output bit [10:-54] dataOut);

	bit [31:0] fraction;
	bit signed [31:0] dataInAbs;
	bit dataInSign;
	bit [4:0] oneIndex;

	absoluteValue #(32) absVal_inst(dataIn, dataInAbs, dataInSign);
	findFirstOne #(32) firstOneFinder(dataInAbs, oneIndex);
	
	assign fraction = dataInAbs << (32-oneIndex);
	assign dataOut = {dataInSign, 5'd0, oneIndex, fraction, 22'd0};

endmodule: log2

module absoluteValue
	#(parameter signBit = 32)
	(input bit signed [31:0] dataIn,
	output bit signed [31:0] dataOut,
	output bit dataSign);

	assign dataSign = dataIn[signBit-1];
	assign dataOut = (dataSign) ? ~dataIn + 1 : dataIn;

endmodule: absoluteValue

module findFirstOne
	#(parameter w = 32)
	(input bit [w-1:0] dataIn,
	output bit [$clog2(w)-1:0] index);

	bit [$clog2(w)-1:0] zeros, zeros1, zeros2, zeros3, zeros4, zeros5;
	bit [w-1:0] temp2, temp3, temp4, temp5;

	assign index = 'd31 - zeros;
	assign zeros = zeros1 + zeros2 + zeros3 + zeros4 + zeros5;

	always_comb begin
		if (dataIn == 'd0) begin
			zeros1 = 'd31;
			temp2 = 'hffffffff;
		end
		else begin
			if (dataIn <= 'hffff) begin
				zeros1 = 'd16;
				temp2 = dataIn << 'd16;
			end
			else begin
				zeros1 = 'd0;
				temp2 = dataIn;
			end
		end
	end
	always_comb begin
		if (temp2 <= 'hffffff) begin
			zeros2 = 'd8;
			temp3 = temp2 << 'd8;
		end
		else begin
			zeros2 = 'd0;
			temp3 = temp2;
		end
	end
	always_comb begin
		if (temp3 <= 'hfffffff) begin
			zeros3 = 'd4;
			temp4 = temp3 << 'd4;
		end
		else begin
			zeros3 = 'd0;
			temp4 = temp3;
		end
	end
	always_comb begin
		if (temp4 <= 'h3fffffff) begin
			zeros4 = 'd2;
			temp5 = temp4 << 'd2;
		end
		else begin
			zeros4 = 'd0;
			temp5 = temp4;
		end
	end
	always_comb begin
		if (temp5 <= 'h7fffffff) begin
			zeros5 = 'd1;
		end
		else begin
			zeros5 = 'd0;
		end
	end
endmodule: findFirstOne


module ilog2_negatives
	(input bit signed [9:-54] dataIn,
	output bit signed [31:-32] dataOut);

	bit signed [9:0] oneIndex;
	always_comb begin
		oneIndex = signed'(dataIn[9:0]);
		dataOut = {32'd1, 32'd0} << oneIndex;
		unique case (signed'(dataIn[9:0]))
			10'sd0: begin
			end
			10'sd1: begin
				dataOut[0:-32] = dataIn[-1:-33];
			end
			10'sd2: begin
				dataOut[1:-32] = dataIn[-1:-34];
			end
			10'sd3: begin
				dataOut[2:-32] = dataIn[-1:-35];
			end
			10'sd4: begin
				dataOut[3:-32] = dataIn[-1:-36];
			end
			10'sd5: begin
				dataOut[4:-32] = dataIn[-1:-37];
			end
			10'sd6: begin
				dataOut[5:-32] = dataIn[-1:-38];
			end
			10'sd7: begin
				dataOut[6:-32] = dataIn[-1:-39];
			end
			10'sd8: begin
				dataOut[7:-32] = dataIn[-1:-40];
			end
			10'sd9: begin
				dataOut[8:-32] = dataIn[-1:-41];
			end
			10'sd10: begin
				dataOut[9:-32] = dataIn[-1:-42];
			end
			10'sd11: begin
				dataOut[10:-32] = dataIn[-1:-43];
			end
			10'sd12: begin
				dataOut[11:-32] = dataIn[-1:-44];
			end
			10'sd13: begin
				dataOut[12:-32] = dataIn[-1:-45];
			end
			10'sd14: begin
				dataOut[13:-32] = dataIn[-1:-46];
			end
			10'sd15: begin
				dataOut[14:-32] = dataIn[-1:-47];
			end
			10'sd16: begin
				dataOut[15:-32] = dataIn[-1:-48];
			end
			10'sd17: begin
				dataOut[16:-32] = dataIn[-1:-49];
			end
			10'sd18: begin
				dataOut[17:-32] = dataIn[-1:-50];
			end
			10'sd19: begin
				dataOut[18:-32] = dataIn[-1:-51];
			end
			10'sd20: begin
				dataOut[19:-32] = dataIn[-1:-52];
			end
			10'sd21: begin
				dataOut[20:-32] = dataIn[-1:-53];
			end
			10'sd22: begin
				dataOut[21:-32] = dataIn[-1:-54];
			end
			10'sd23: begin
				dataOut[22:-32] = {dataIn[-1:-54], 1'd0};
			end
			10'sd24: begin
				dataOut[23:-32] = {dataIn[-1:-54], 2'd0};
			end
			10'sd25: begin
				dataOut[24:-32] = {dataIn[-1:-54], 3'd0};
			end
			10'sd26: begin
				dataOut[25:-32] = {dataIn[-1:-54], 4'd0};
			end
			10'sd27: begin
				dataOut[26:-32] = {dataIn[-1:-54], 5'd0};
			end
			10'sd28: begin
				dataOut[27:-32] = {dataIn[-1:-54], 6'd0};
			end
			10'sd29: begin
				dataOut[28:-32] = {dataIn[-1:-54], 7'd0};
			end
			10'sd30: begin
				dataOut[29:-32] = {dataIn[-1:-54], 8'd0};
			end
			10'sd31: begin
				dataOut[30:-32] = {dataIn[-1:-54], 9'd0};
			end
			-10'sd1: begin
				dataOut[-2:-32] = dataIn[-1:-31];
			end
			-10'sd2: begin
				dataOut[-3:-32] = dataIn[-1:-30];
			end
			-10'sd3: begin
				dataOut[-4:-32] = dataIn[-1:-29];
			end
			-10'sd4: begin
				dataOut[-5:-32] = dataIn[-1:-28];
			end
			-10'sd5: begin
				dataOut[-6:-32] = dataIn[-1:-27];
			end
			-10'sd6: begin
				dataOut[-7:-32] = dataIn[-1:-26];
			end
			-10'sd7: begin
				dataOut[-8:-32] = dataIn[-1:-25];
			end
			-10'sd8: begin
				dataOut[-9:-32] = dataIn[-1:-24];
			end
			-10'sd9: begin
				dataOut[-10:-32] = dataIn[-1:-23];
			end
			-10'sd10: begin
				dataOut[-11:-32] = dataIn[-1:-22];
			end
			-10'sd11: begin
				dataOut[-12:-32] = dataIn[-1:-21];
			end
			-10'sd12: begin
				dataOut[-13:-32] = dataIn[-1:-20];
			end
			-10'sd13: begin
				dataOut[-14:-32] = dataIn[-1:-19];
			end
			-10'sd14: begin
				dataOut[-15:-32] = dataIn[-1:-18];
			end
			-10'sd15: begin
				dataOut[-16:-32] = dataIn[-1:-17];
			end
			-10'sd16: begin
				dataOut[-17:-32] = dataIn[-1:-16];
			end
			-10'sd17: begin
				dataOut[-18:-32] = dataIn[-1:-15];
			end
			-10'sd18: begin
				dataOut[-19:-32] = dataIn[-1:-14];
			end
			-10'sd19: begin
				dataOut[-20:-32] = dataIn[-1:-13];
			end
			-10'sd20: begin
				dataOut[-21:-32] = dataIn[-1:-12];
			end
			-10'sd21: begin
				dataOut[-22:-32] = dataIn[-1:-11];
			end
			-10'sd22: begin
				dataOut[-23:-32] = dataIn[-1:-10];
			end
			-10'sd23: begin
				dataOut[-24:-32] = dataIn[-1:-9];
			end
			-10'sd24: begin
				dataOut[-25:-32] = dataIn[-1:-8];
			end
			-10'sd25: begin
				dataOut[-26:-32] = dataIn[-1:-7];
			end
			-10'sd26: begin
				dataOut[-27:-32] = dataIn[-1:-6];
			end
			-10'sd27: begin
				dataOut[-28:-32] = dataIn[-1:-5];
			end
			-10'sd28: begin
				dataOut[-29:-32] = dataIn[-1:-4];
			end
			-10'sd29: begin
				dataOut[-30:-32] = dataIn[-1:-3];
			end
			-10'sd30: begin
				dataOut[-31:-32] = dataIn[-1:-2];
			end
			-10'sd31: begin
				dataOut[-32] = dataIn[-1];
			end
		endcase
	end
endmodule: ilog2_negatives


module ilog2
	(input bit [9:-54] dataIn,
	output bit [31:0] dataOut);
	always_comb begin
		dataOut = 32'd1 << dataIn[9:0];
		unique case (dataIn[9:0])
			10'd0: begin
			end
			10'd1: begin
				dataOut[0] = dataIn[-1];
			end
			10'd2: begin
				dataOut[1:0] = dataIn[-1:-2];
			end
			10'd3: begin
				dataOut[2:0] = dataIn[-1:-3];
			end
			10'd4: begin
				dataOut[3:0] = dataIn[-1:-4];
			end
			10'd5: begin
				dataOut[4:0] = dataIn[-1:-5];
			end
			10'd6: begin
				dataOut[5:0] = dataIn[-1:-6];
			end
			10'd7: begin
				dataOut[6:0] = dataIn[-1:-7];
			end
			10'd8: begin
				dataOut[7:0] = dataIn[-1:-8];
			end
			10'd9: begin
				dataOut[8:0] = dataIn[-1:-9];
			end
			10'd10: begin
				dataOut[9:0] = dataIn[-1:-10];
			end
			10'd11: begin
				dataOut[10:0] = dataIn[-1:-11];
			end
			10'd12: begin
				dataOut[11:0] = dataIn[-1:-12];
			end
			10'd13: begin
				dataOut[12:0] = dataIn[-1:-13];
			end
			10'd14: begin
				dataOut[13:0] = dataIn[-1:-14];
			end
			10'd15: begin
				dataOut[14:0] = dataIn[-1:-15];
			end
			10'd16: begin
				dataOut[15:0] = dataIn[-1:-16];
			end
			10'd17: begin
				dataOut[16:0] = dataIn[-1:-17];
			end
			10'd18: begin
				dataOut[17:0] = dataIn[-1:-18];
			end
			10'd19: begin
				dataOut[18:0] = dataIn[-1:-19];
			end
			10'd20: begin
				dataOut[19:0] = dataIn[-1:-20];
			end
			10'd21: begin
				dataOut[20:0] = dataIn[-1:-21];
			end
			10'd22: begin
				dataOut[21:0] = dataIn[-1:-22];
			end
			10'd23: begin
				dataOut[22:0] = dataIn[-1:-23];
			end
			10'd24: begin
				dataOut[23:0] = dataIn[-1:-24];
			end
			10'd25: begin
				dataOut[24:0] = dataIn[-1:-25];
			end
			10'd26: begin
				dataOut[25:0] = dataIn[-1:-26];
			end
			10'd27: begin
				dataOut[26:0] = dataIn[-1:-27];
			end
			10'd28: begin
				dataOut[27:0] = {dataIn[-1:-28]};
			end
			10'd29: begin
				dataOut[28:0] = {dataIn[-1:-29]};
			end
			10'd30: begin
				dataOut[29:0] = {dataIn[-1:-30]};
			end
			10'd31: begin
				dataOut[30:0] = {dataIn[-1:-31]};
			end
		endcase
	end
endmodule: ilog2


module tree_adder
#(parameter inputSize = 9)
(input logic clk,
input logic rst_n,
input logic enable,
input logic signed [inputSize-1:0] operand[16][16] ,
output logic signed [inputSize-1:0] sum_result,
output logic dataReady);

logic signed [inputSize -1:0] sum_0_in[128];
logic signed [inputSize -1:0] sum_1_in[64];
logic signed [inputSize -1:0] sum_2_in[32];
logic signed [inputSize -1:0] sum_3_in[16];
logic signed [inputSize -1:0] sum_4_in[8];
logic signed [inputSize -1:0] sum_5_in[4];
logic signed [inputSize -1:0] sum_6_in[2];
logic signed [inputSize -1:0] sum_7_in;

logic signed [inputSize -1:0] sum_0_out[128];
logic signed [inputSize -1:0] sum_1_out[64];
logic signed [inputSize -1:0] sum_2_out[32];
logic signed [inputSize -1:0] sum_3_out[16];
logic signed [inputSize -1:0] sum_4_out[8];
logic signed [inputSize -1:0] sum_5_out[4];
logic signed [inputSize -1:0] sum_6_out[2];
logic signed [inputSize -1:0] sum_7_out;

logic en0;
logic en1;
logic en2;
logic en3;
logic en4;
logic en5;
logic en6;
logic en7;

always_ff @(posedge clk) begin
    en0 <= enable;
    en1 <= en0;
    en2 <= en1;
    en3 <= en2;
    en4 <= en3;
    en5 <= en4;
    en6 <= en5;
    dataReady <= en6;
end


assign sum_result = sum_7_out;
//pair off all the values.
// first pairing 256 ==> 128

genvar i;
generate 

	for(i = 0 ; i < 128; i++) begin
	// 128 sum
		adder#(inputSize) stage0(.input_A(operand[i/8][(i%8)*2]),.input_B(operand[i/8][(i%8)*2 +1]),.out(sum_0_in[i]));
		adder_reg#(inputSize) re_0(.clk(clk),.rst_n(rst_n),.in(sum_0_in[i]),.enable(enable),.out(sum_0_out[i]));

	end
endgenerate

generate 
// second pairing 128 ==>64
for(i = 0; i< 64; i++)begin

adder#(inputSize) stage1(.input_A(sum_0_out[i*2]),.input_B(sum_0_out[i*2+1]),.out(sum_1_in[i]));
adder_reg#(inputSize) re_1(.clk(clk),.rst_n(rst_n),.in(sum_1_in[i]),.enable(en0),.out(sum_1_out[i]));



end
endgenerate

generate
// third pairing 64 ==>32
for(i = 0; i<32; i++)begin

adder#(inputSize) stage2(.input_A(sum_1_out[i*2]),.input_B(sum_1_out[i*2+1]),.out(sum_2_in[i]));
adder_reg#(inputSize) re_2(.clk(clk),.rst_n(rst_n),.in(sum_2_in[i]),.enable(en1),.out(sum_2_out[i]));


end
endgenerate

generate
// forth pairing 32 ==>16
for( i = 0; i<16; i++)begin

adder#(inputSize) stage3(.input_A(sum_2_out[i*2]),.input_B(sum_2_out[i*2+1]),.out(sum_3_in[i]));
adder_reg#(inputSize) re_3(.clk(clk),.rst_n(rst_n),.in(sum_3_in[i]),.enable(en2),.out(sum_3_out[i]));


end
endgenerate

generate
// fifth pairing 16 ==>8

for( i = 0; i <8; i++)begin

adder#(inputSize) stage4(.input_A(sum_3_out[i*2]),.input_B(sum_3_out[i*2+1]),.out(sum_4_in[i]));
adder_reg#(inputSize) re_4(.clk(clk),.rst_n(rst_n),.in(sum_4_in[i]),.enable(en3),.out(sum_4_out[i]));


end
endgenerate
generate
// sixth pairing 8 ==> 4

for( i = 0; i < 4; i++)begin

adder#(inputSize) stage5(.input_A(sum_4_out[i*2]),.input_B(sum_4_out[i*2+1]),.out(sum_5_in[i]));
adder_reg#(inputSize) re_5(.clk(clk),.rst_n(rst_n),.in(sum_5_in[i]),.enable(en4),.out(sum_5_out[i]));


end
endgenerate
generate 
// seventh pairing 4 ==>2

for( i = 0; i <2; i++)begin

adder#(inputSize) stage6(.input_A(sum_5_out[i*2]),.input_B(sum_5_out[i*2+1]),.out(sum_6_in[i]));
adder_reg#(inputSize) re_6(.clk(clk),.rst_n(rst_n),.in(sum_6_in[i]),.enable(en5),.out(sum_6_out[i]));


end
endgenerate

generate
// eigth pairing 2 ==>1

adder#(inputSize) stage7(.input_A(sum_6_out[0]),.input_B(sum_6_out[1]),.out(sum_7_in));
adder_reg#(inputSize) re_7(.clk(clk),.rst_n(rst_n),.in(sum_7_in),.enable(en6),.out(sum_7_out));

endgenerate

endmodule: tree_adder

module adder #(parameter inputSize = 9)(
				input logic signed [inputSize-1:0] input_A,
				input logic signed [inputSize-1:0] input_B,
				output logic signed [inputSize-1:0] out
);

assign out = input_A + input_B;

endmodule: adder


module adder_reg #(parameter inputSize = 9)
		 (input logic clk,
		  input logic rst_n,
		  input logic signed [inputSize-1:0] in,
		  input logic enable,
		  output logic signed[inputSize-1:0] out);

always_ff@(posedge clk,negedge rst_n)begin
	if(~rst_n)begin
		out <= 'd0;
	end
	else if (enable)begin
		out <= in;
	end
	else begin
		out <= out;
	end
end
endmodule: adder_reg

/*
	enum logic {DESC_WAIT, DESC_LOAD} currStateDesc, nextStateDesc;
	enum logic {WIN_WAIT, WIN_LOAD} currStateWin, nextStateWin;
	logic winWriteA, winWriteB;

	//descriptor loading datapath hardware
	logic incDescRowC, incDescColC, loadDescGroup1, loadDescGroup2, loadDescGroup3, loadDescGroup4;
	logic loadDescNow, loadWinReg;
	logic [15:0] loadRow;
	logic [3:0] loadColGroup;
	bit signed [31:0] accRowTotal [15:0];
	bit signed [31:0] accOut [239:0];
	bit [3:0] descRowC;
	bit [1:0] descColC;
	bit [10:-54] descLog2 [3:0];
	bit [10:-54] windowLog2 [15:0] [15:0];
	bit [31:0] descPixelOut [255:0];
	bit [31:0] winPixelOut [255:0];
	counter #(4) descRowCounter(clk, rst, 1'b0, incDescRowC, descRowC);
	counter #(2) descColCounter(clk, rst, 1'b0, incDescColC, descColC);

	//descriptor log2 hardware
	log2 descLog2_inst1({{23{desc_data_in[35]}}, desc_data_in[35:27]}, descLog2[0]);
	log2 descLog2_inst2({{23{desc_data_in[26]}}, desc_data_in[26:18]}, descLog2[1]);
	log2 descLog2_inst3({{23{desc_data_in[17]}}, desc_data_in[17:9]}, descLog2[2]);
	log2 descLog2_inst4({{23{desc_data_in[8]}}, desc_data_in[8:0]}, descLog2[3]);

	decoder #(4) desc_decoder_col(descColC, loadColGroup);
	decoder #(16) desc_decoder_row(descRowC, loadRow);

	//window log2 hardware
	genvar i, j;
	generate
		for (i = 0; i < 16; i++) begin
			for (j = 0; j < 16; j++) begin
				log2 windowLog2_inst({{23{window_data_in[i][j][8]}}, window_data_in[i][j]}, windowLog2[i][j]);
			end
		end
	endgenerate

	//generate 16x16 PE grid
	generate
		for (i = 0; i < 16; i++) begin
			for (j = 0; j < 16; j++) begin
				int k = j/4;
				if (j == 0) begin
					//set accIn = 0 for first PE in row
					processingElement PE_inst(.clk(clk), .rst(rst), .descPixelLog2In(descLog2[j%4]), .windowPixelLog2In(windowLog2[i][j]), .loadDescReg(loadColGroup[k]&loadRow[i]&loadDescNow), .loadWinReg(loadWinReg), .accIn('d0), .descPixelOut(descPixelOut[j+i*16]), .windowPixelOut(winPixelOut[j+i*16]), .accOut(accOut[j+i*15]));
				end
				else if (j == 'd15) begin
					processingElement PE_inst(.clk(clk), .rst(rst), .descPixelLog2In(descLog2[j%4]), .windowPixelLog2In(windowLog2[i][j]), .loadDescReg(loadColGroup[k]&loadRow[i]&loadDescNow), .loadWinReg(loadWinReg), .accIn(accOut[j-1+i*15]), .descPixelOut(descPixelOut[j+i*16]), .windowPixelOut(winPixelOut[j+i*16]), .accOut(accRowTotal[i]));
				end
				else begin
					processingElement PE_inst(.clk(clk), .rst(rst), .descPixelLog2In(descLog2[j%4]), .windowPixelLog2In(windowLog2[i][j]), .loadDescReg(loadColGroup[k]&loadRow[i]&loadDescNow), .loadWinReg(loadWinReg), .accIn(accOut[j-1+i*15]), .descPixelOut(descPixelOut[j+i*16]), .windowPixelOut(winPixelOut[j+i*16]), .accOut(accOut[j+i*15]));
				end
			end
		end
	endgenerate

	bit [31:0] accPatchSum;
	bit signed [31:-32] correlationCoefficient, corrCoeff;
	bit [9:-54] denomLog2, numLog2;
	bit signed [9:-54] corrCoeffLog2;
	bit [31:0] descSumOfSquares, winSumOfSquares;
	bit [10:-54] descSumOfSquaresLog2, winSumOfSquaresLog2;
	bit [10:-54] numeratorLog2;

	assign accPatchSum = accRowTotal[0] + accRowTotal[1] + accRowTotal[2] + accRowTotal[3] + accRowTotal[4] + accRowTotal[5] + accRowTotal[6] + accRowTotal[7] + accRowTotal[8] + accRowTotal[9] + accRowTotal[10] + accRowTotal[11] + accRowTotal[12] + accRowTotal[13] + accRowTotal[14] + accRowTotal[15];
	log2 num_log2_inst (accPatchSum, numeratorLog2);

	//compute denominator
	//compute sum of squares for denominator
	always_comb begin
		descSumOfSquares = 0;
		winSumOfSquares = 0;
		for (int rowI = 0; rowI < 16; rowI++) begin
			for (int colI = 0; colI < 16; colI++) begin
				//$display("descVal=%b\nwinVal=%b",descPixelOut[rowI*16+colI],winPixelOut[rowI*16+colI]);
				//$display("dval=%d\n",descPixelOut[rowI*16+colI]);
				descSumOfSquares = descSumOfSquares + descPixelOut[rowI*16 + colI];
				winSumOfSquares = winSumOfSquares + winPixelOut[rowI*16 + colI];
				//$display("dsos=%b\nwsos=%b",descSumOfSquares,winSumOfSquares);
			end
		end
	end
	log2 denom_desc_log2_inst (descSumOfSquares, descSumOfSquaresLog2);
	log2 denom_win_log2_inst (winSumOfSquares, winSumOfSquaresLog2);

	//part 2 of denominator
	assign denomLog2 = (descSumOfSquaresLog2[9:-54] + winSumOfSquaresLog2[9:-54]) >> 1;

	//final computation
	always_comb begin
		if (numeratorLog2[10] == 1'b1) begin
			numLog2 = ~(numeratorLog2[9:-54])+1;
		end
		else begin
			numLog2 = numeratorLog2[9:-54];
		end
		corrCoeffLog2 = signed'(numLog2) - signed'(denomLog2);
		//if (corrCoeffLog2 > numeratorLog2[9:-54]) begin
	//		corrCoeffLog2 =  {10'd1, 54'd0};
	//	end
	end

	ilog2_negatives coeff_ilog2_inst (corrCoeffLog2, corrCoeff);
	always_comb begin
		if (numeratorLog2[10] == 1'b1) begin
			correlationCoefficient = ~corrCoeff + 1;
		end
		else begin
			correlationCoefficient = corrCoeff;
		end
	end
	
	//register to store the entire patch acc total sum
	//register #(32) accReg (accPatchSum, clk, rst, loadAccSumReg, accTotalSum);

	logic loadGreatestReg, clearWinCount, clearGreatestReg;
	bit [12:0] windowCount;
	//register to store greatest correlation coefficient and window index
	priorityRegisterFP #(13) greatestNCCRegFP (correlationCoefficient, windowCount, clk, rst, loadGreatestReg, clearGreatestReg, greatestNCC, greatestWindowIndex);
	counter #(13) windowCounter (clk, rst, clearWinCount, loadGreatestReg, windowCount);

	//descriptor loading fsm
	always_comb begin
		done_with_desc_data = 1'b0;
		loadDescNow = 1'b0;
		incDescColC = 1'b0;
		incDescRowC = 1'b0;
		case (currStateDesc)
			DESC_WAIT: begin
				if (desc_data_ready) begin
					loadDescNow = 1'b1;
					incDescColC = 1'b1;
					if (descColC == 'd3) begin
						incDescRowC = 1'b1;
					end
					nextStateDesc = DESC_WAIT;
				end
				else begin
					nextStateDesc = DESC_WAIT;
				end
			end
			default: nextStateDesc = DESC_WAIT;
		endcase
	end

	//window loading fsm
	always_comb begin
		done_with_window_data = 1'b0;
		loadWinReg = 1'b0;
		loadGreatestReg = 1'b0;
		clearWinCount = 1'b0;
		clearGreatestReg = 1'b0;
		case (currStateWin)
			WIN_WAIT: begin
				if (window_data_ready) begin
					loadWinReg = 1'b1;
					nextStateWin = WIN_LOAD;
				end
				else begin
					nextStateWin = WIN_WAIT;
				end
			end
			WIN_LOAD: begin
				loadGreatestReg = 1'b1;
				done_with_window_data = 1'b1;
				if (windowCount >= (4224)) begin
					clearWinCount = 1'b1;
					clearGreatestReg = 1'b1;
				end
				nextStateWin = WIN_WAIT;
			end
			default: nextStateWin = WIN_WAIT;
		endcase
	end

	//state register
	always_ff @(posedge clk, posedge rst) begin
		if (rst) begin
			currStateDesc <= DESC_WAIT;
			currStateWin <= WIN_WAIT;
		end
		else begin
			currStateDesc <= nextStateDesc;
			currStateWin <= nextStateWin;
		end
	end

endmodule: ncc

module mux
	#(parameter w = 4)
	(input bit [w-1:0] in,
	input bit [$clog2(w)-1:0] sel,
	output bit out);
	
	assign out = in[sel];

endmodule: mux


module decoder
	#(parameter w = 4)
	(input bit [$clog2(w)-1:0] sel,
	output bit [w-1:0] out);

	always_comb begin
		out = 'd1 << sel;
	end

endmodule: decoder

module treeAdder
	(input bit signed [31:0] accIn,
	 input bit signed [31:0] tempSum,
	 input bit descSignBit, winSignBit,
	 input bit clk, rst, load,
	output bit signed [31:0] accOut)

	bit signed [31:0] accTemp

	assign accTemp = (descSignBit ^ winSignBit) ? (accIn - tempsum) : (accIn + tempSum);

	registerSigned tree_adder_reg_inst (accTemp, clk, rst, load, accOut);

endmodule: treeAdder

module counter
	#(parameter w = 256)
	(input logic clk, rst, clr, enable,
	output bit [w-1:0] count);

	always_ff @(posedge clk, posedge rst) begin
		if (rst) begin
			count <= 'd0;
		end
		else if (clr) begin
			count <= 'd0;
		end
		else if (enable) begin
			count <= count + 'd1;
		end
	end
endmodule: counter

module processingElement
	(input bit	[10:-54]	descPixelLog2In,
	 input bit	[10:-54]	windowPixelLog2In,
	 input bit			clk, rst, loadDescReg, loadWinReg,
	 input bit signed [31:0] accIn,
	 output bit signed [31:0] descPixelOut,
	 output bit signed [31:0] windowPixelOut,
	 output bit	signed [31:0] accOut);
	
	bit [10:-54] descPixelLog2Out, windowPixelLog2Out;
	bit [9:-54] tempSumLog2, descPixelLog2, windowPixelLog2;
	bit [31:0] tempSum;
	bit descSignBit, winSignBit;
	assign descSignBit = descPixelLog2Out[10];
	assign winSignBit = windowPixelLog2Out[10];

	ilog2 ilog2_inst (tempSumLog2, tempSum);

	//register for descriptor pixel
	registerLog2 #(10) descReg (descPixelLog2In, clk, rst, loadDescReg, descPixelLog2Out);
	//register for storing "LTC"
	registerLog2 #(10) windowReg (windowPixelLog2In, clk, rst, loadWinReg, windowPixelLog2Out);
	//register for "ACCin + ltc*f
	//register #(32) accReg (accSum, clk, rst, loadAccSumReg, accOut);

	//output the ilog2 of the square of the pixels for denominator computation
	assign descPixelLog2 = descPixelLog2Out[9:-54] << 1;
	assign windowPixelLog2 = windowPixelLog2Out[9:-54] << 1;
	ilog2 ilog2_desc_inst (descPixelLog2, descPixelOut);
	ilog2 ilog2_win_inst (windowPixelLog2, windowPixelOut);

	assign tempSumLog2 = descPixelLog2Out[9:-54] + windowPixelLog2Out[9:-54];
	assign accOut = (descSignBit ^ winSignBit) ? (accIn - signed'(tempSum)) : (accIn + signed'(tempSum));

endmodule: processingElement

module log2
	(input bit signed [31:0] dataIn,
	output bit [10:-54] dataOut);

	bit [31:0] fraction;
	bit signed [31:0] dataInAbs;
	bit dataInSign;
	bit [4:0] oneIndex;

	absoluteValue #(32) absVal_inst(dataIn, dataInAbs, dataInSign);
	findFirstOne #(32) firstOneFinder(dataInAbs, oneIndex);
	
	assign fraction = dataInAbs << (32-oneIndex);
	assign dataOut = {dataInSign, 5'd0, oneIndex, fraction, 22'd0};

endmodule: log2


module ilog2_negatives
	(input bit signed [9:-54] dataIn,
	output bit signed [31:-32] dataOut);

	bit signed [9:0] oneIndex;
	always_comb begin
		oneIndex = signed'(dataIn[9:0]);
		dataOut = {32'd1, 32'd0} << oneIndex;
		unique case (signed'(dataIn[9:0]))
			10'sd0: begin
			end
			10'sd1: begin
				dataOut[0:-32] = dataIn[-1:-33];
			end
			10'sd2: begin
				dataOut[1:-32] = dataIn[-1:-34];
			end
			10'sd3: begin
				dataOut[2:-32] = dataIn[-1:-35];
			end
			10'sd4: begin
				dataOut[3:-32] = dataIn[-1:-36];
			end
			10'sd5: begin
				dataOut[4:-32] = dataIn[-1:-37];
			end
			10'sd6: begin
				dataOut[5:-32] = dataIn[-1:-38];
			end
			10'sd7: begin
				dataOut[6:-32] = dataIn[-1:-39];
			end
			10'sd8: begin
				dataOut[7:-32] = dataIn[-1:-40];
			end
			10'sd9: begin
				dataOut[8:-32] = dataIn[-1:-41];
			end
			10'sd10: begin
				dataOut[9:-32] = dataIn[-1:-42];
			end
			10'sd11: begin
				dataOut[10:-32] = dataIn[-1:-43];
			end
			10'sd12: begin
				dataOut[11:-32] = dataIn[-1:-44];
			end
			10'sd13: begin
				dataOut[12:-32] = dataIn[-1:-45];
			end
			10'sd14: begin
				dataOut[13:-32] = dataIn[-1:-46];
			end
			10'sd15: begin
				dataOut[14:-32] = dataIn[-1:-47];
			end
			10'sd16: begin
				dataOut[15:-32] = dataIn[-1:-48];
			end
			10'sd17: begin
				dataOut[16:-32] = dataIn[-1:-49];
			end
			10'sd18: begin
				dataOut[17:-32] = dataIn[-1:-50];
			end
			10'sd19: begin
				dataOut[18:-32] = dataIn[-1:-51];
			end
			10'sd20: begin
				dataOut[19:-32] = dataIn[-1:-52];
			end
			10'sd21: begin
				dataOut[20:-32] = dataIn[-1:-53];
			end
			10'sd22: begin
				dataOut[21:-32] = dataIn[-1:-54];
			end
			10'sd23: begin
				dataOut[22:-32] = {dataIn[-1:-54], 1'd0};
			end
			10'sd24: begin
				dataOut[23:-32] = {dataIn[-1:-54], 2'd0};
			end
			10'sd25: begin
				dataOut[24:-32] = {dataIn[-1:-54], 3'd0};
			end
			10'sd26: begin
				dataOut[25:-32] = {dataIn[-1:-54], 4'd0};
			end
			10'sd27: begin
				dataOut[26:-32] = {dataIn[-1:-54], 5'd0};
			end
			10'sd28: begin
				dataOut[27:-32] = {dataIn[-1:-54], 6'd0};
			end
			10'sd29: begin
				dataOut[28:-32] = {dataIn[-1:-54], 7'd0};
			end
			10'sd30: begin
				dataOut[29:-32] = {dataIn[-1:-54], 8'd0};
			end
			10'sd31: begin
				dataOut[30:-32] = {dataIn[-1:-54], 9'd0};
			end
			-10'sd1: begin
				dataOut[-2:-32] = dataIn[-1:-31];
			end
			-10'sd2: begin
				dataOut[-3:-32] = dataIn[-1:-30];
			end
			-10'sd3: begin
				dataOut[-4:-32] = dataIn[-1:-29];
			end
			-10'sd4: begin
				dataOut[-5:-32] = dataIn[-1:-28];
			end
			-10'sd5: begin
				dataOut[-6:-32] = dataIn[-1:-27];
			end
			-10'sd6: begin
				dataOut[-7:-32] = dataIn[-1:-26];
			end
			-10'sd7: begin
				dataOut[-8:-32] = dataIn[-1:-25];
			end
			-10'sd8: begin
				dataOut[-9:-32] = dataIn[-1:-24];
			end
			-10'sd9: begin
				dataOut[-10:-32] = dataIn[-1:-23];
			end
			-10'sd10: begin
				dataOut[-11:-32] = dataIn[-1:-22];
			end
			-10'sd11: begin
				dataOut[-12:-32] = dataIn[-1:-21];
			end
			-10'sd12: begin
				dataOut[-13:-32] = dataIn[-1:-20];
			end
			-10'sd13: begin
				dataOut[-14:-32] = dataIn[-1:-19];
			end
			-10'sd14: begin
				dataOut[-15:-32] = dataIn[-1:-18];
			end
			-10'sd15: begin
				dataOut[-16:-32] = dataIn[-1:-17];
			end
			-10'sd16: begin
				dataOut[-17:-32] = dataIn[-1:-16];
			end
			-10'sd17: begin
				dataOut[-18:-32] = dataIn[-1:-15];
			end
			-10'sd18: begin
				dataOut[-19:-32] = dataIn[-1:-14];
			end
			-10'sd19: begin
				dataOut[-20:-32] = dataIn[-1:-13];
			end
			-10'sd20: begin
				dataOut[-21:-32] = dataIn[-1:-12];
			end
			-10'sd21: begin
				dataOut[-22:-32] = dataIn[-1:-11];
			end
			-10'sd22: begin
				dataOut[-23:-32] = dataIn[-1:-10];
			end
			-10'sd23: begin
				dataOut[-24:-32] = dataIn[-1:-9];
			end
			-10'sd24: begin
				dataOut[-25:-32] = dataIn[-1:-8];
			end
			-10'sd25: begin
				dataOut[-26:-32] = dataIn[-1:-7];
			end
			-10'sd26: begin
				dataOut[-27:-32] = dataIn[-1:-6];
			end
			-10'sd27: begin
				dataOut[-28:-32] = dataIn[-1:-5];
			end
			-10'sd28: begin
				dataOut[-29:-32] = dataIn[-1:-4];
			end
			-10'sd29: begin
				dataOut[-30:-32] = dataIn[-1:-3];
			end
			-10'sd30: begin
				dataOut[-31:-32] = dataIn[-1:-2];
			end
			-10'sd31: begin
				dataOut[-32] = dataIn[-1];
			end
		endcase
	end
endmodule: ilog2_negatives

module findFirstOne
	#(parameter w = 32)
	(input bit [w-1:0] dataIn,
	output bit [$clog2(w)-1:0] index);

	bit [$clog2(w)-1:0] zeros, zeros1, zeros2, zeros3, zeros4, zeros5;
	bit [w-1:0] temp2, temp3, temp4, temp5;

	assign index = 'd31 - zeros;
	assign zeros = zeros1 + zeros2 + zeros3 + zeros4 + zeros5;

	always_comb begin
		if (dataIn == 'd0) begin
			zeros1 = 'd31;
			temp2 = 'hffffffff;
		end
		else begin
			if (dataIn <= 'hffff) begin
				zeros1 = 'd16;
				temp2 = dataIn << 'd16;
			end
			else begin
				zeros1 = 'd0;
				temp2 = dataIn;
			end
		end
	end
	always_comb begin
		if (temp2 <= 'hffffff) begin
			zeros2 = 'd8;
			temp3 = temp2 << 'd8;
		end
		else begin
			zeros2 = 'd0;
			temp3 = temp2;
		end
	end
	always_comb begin
		if (temp3 <= 'hfffffff) begin
			zeros3 = 'd4;
			temp4 = temp3 << 'd4;
		end
		else begin
			zeros3 = 'd0;
			temp4 = temp3;
		end
	end
	always_comb begin
		if (temp4 <= 'h3fffffff) begin
			zeros4 = 'd2;
			temp5 = temp4 << 'd2;
		end
		else begin
			zeros4 = 'd0;
			temp5 = temp4;
		end
	end
	always_comb begin
		if (temp5 <= 'h7fffffff) begin
			zeros5 = 'd1;
		end
		else begin
			zeros5 = 'd0;
		end
	end
endmodule: findFirstOne

module absoluteValue
	#(parameter signBit = 32)
	(input bit signed [31:0] dataIn,
	output bit signed [31:0] dataOut,
	output bit dataSign);

	assign dataSign = dataIn[signBit-1];
	assign dataOut = (dataSign) ? ~dataIn + 1 : dataIn;

endmodule: absoluteValue

module absoluteValueFP
	#(parameter signBit = 32)
	(input bit signed [31:-32] dataIn,
	output bit signed [31:-32] dataOut);

	bit dataSign;

	assign dataSign = dataIn[signBit-1];
	assign dataOut = (dataSign) ? ~dataIn + 1 : dataIn;

endmodule: absoluteValueFP

module registerSigned
	#(parameter w = 32)
	(input bit signed [w-1:0] dataIn,
	 input bit clk, rst, load,
	 output bit signed [w-1:0] dataOut);

	always_ff @(posedge clk, posedge rst) begin
		if (rst) begin
			dataOut <= 'sd0;
		end
		else if (load) begin
			dataOut <= dataIn;
		end
	end

endmodule: registerSigned

module register
	#(parameter w = 32)
	(input bit	[w-1:0]	dataIn,
	 input bit			clk, rst, load,
	 output bit	[w-1:0] dataOut);

	always_ff @(posedge clk, posedge rst) begin
		if (rst) begin
			dataOut <= 'd0;
		end
		else if (load) begin
			dataOut <= dataIn;
		end
	end

endmodule: register

module priorityRegisterFP
	#(parameter w2 = 12)
	(input bit signed[31:-32] dataIn,
	input bit [w2-1:0] dataIn2,
	input bit clk, rst, load, clear,
	output bit signed [31:-32] dataOut,
	output bit	[w2-1:0] dataOut2);

	bit signed [31:-32] dataInAbs, dataOutAbs, data;
	bit [w2-1:0] data2;

	absoluteValueFP #(32) absValInFP_inst (dataIn, dataInAbs);
	absoluteValueFP #(32) absValOutFP_inst (dataOut, dataOutAbs);

	assign data = (dataInAbs > dataOutAbs) ? dataIn : dataOut;
	assign data2 = (dataIn > dataOut) ? dataIn2 : dataOut2;

	always_ff @(posedge clk, posedge rst) begin
		if (rst) begin
			dataOut <= 'd0;
			dataOut2 <= 'd0;
		end
		else if (clear) begin
			dataOut <= 'd0;
			dataOut2 <= 'd0;
		end
		else if (load) begin
			dataOut <= data;
			dataOut2 <= data2;
		end
	end
endmodule: priorityRegisterFP

module priorityRegister
	#(parameter w2 = 9)
	(input bit	[9:-54] dataIn,
	input bit	[w2-1:0] dataIn2,
	input bit	clk, rst, load,
	output bit	[9:-54] dataOut,
	output bit	[w2-1:0] dataOut2);

	bit [9:-54] data;
	bit [w2-1:0] data2;
	assign data = (dataIn > dataOut) ? dataIn : dataOut;
	assign data2 = (dataIn > dataOut) ? dataIn2 : dataOut2;
	always_ff @(posedge clk, posedge rst) begin
		if (rst) begin
			dataOut <= 'd0;
			dataOut2 <= 'd0;
		end
		else if (load) begin
			dataOut <= data;
			dataOut2 <= data2;
		end
	end
endmodule: priorityRegister

module registerLog2
	#(parameter w = 10)
	(input bit	[w:-54]	dataIn,
	 input bit			clk, rst, load,
	 output bit	[w:-54] dataOut);

	always_ff @(posedge clk, posedge rst) begin
		if (rst) begin
			dataOut <= 'd0;
		end
		else if (load) begin
			dataOut <= dataIn;
		end
	end
endmodule: registerLog2*/
