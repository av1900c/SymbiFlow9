(* whitebox *)
module LUT4 (I, O);
	input wire [3:0] I;
	(* DELAY_MATRIX_I="30e-12 30e-12 30e-12 30e-12" *)
	output wire O;

	localparam INIT = 16'h0000;
	assign O = INIT[I];
endmodule
