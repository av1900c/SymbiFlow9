/*
 * `input wire clk` should be detected as a clock despite this being a black
 * box module.
 */
(* blackbox *)
module block(clk, a, o);
	input wire clk;
	input wire a;
	output wire o;
endmodule
