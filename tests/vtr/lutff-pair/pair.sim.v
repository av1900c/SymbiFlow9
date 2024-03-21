/*
 * Copyright (C) 2020  The SymbiFlow Authors.
 *
 * Use of this source code is governed by a ISC-style
 * license that can be found in the LICENSE file or at
 * https://opensource.org/licenses/ISC
 *
 * SPDX-License-Identifier:	ISC
 */

`include "lut/lut4.sim.v"
`include "ff/ff.sim.v"
`include "omux/omux.sim.v"

module PAIR (
	I,
	CLK,
	O
);
	input wire [3:0] I;
	input wire CLK;

	output wire O;

	(* pack="LUT2FF" *)
	wire lut_out;

	LUT4 lut (.I(I), .O(lut_out));

	wire ff_out;
	DFF ff (.CLK(CLK), .D(lut_out), .Q(ff_out));

	parameter FF_BYPASS = "F";
	OMUX #(.MODE(FF_BYPASS)) mux(.L(lut_out), .F(ff_out), .O(O));

endmodule
