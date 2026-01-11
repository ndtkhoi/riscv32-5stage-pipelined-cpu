module alu(
	input  logic [31:0] i_op_a,
	input  logic [31:0] i_op_b,
	input  logic [3:0]  i_alu_op,
	output logic [31:0] o_alu_data
);
	logic [32:0] add_ext, sub_ext;
	addsub32 addsub_add (
		.i_a(i_op_a),
		.i_b(i_op_b),
		.Cin(1'b0),		//add
		.Cout(add_ext[32]),
		.o_s(add_ext[31:0])
	);
	addsub32 addsub_sub (
		.i_a(i_op_a), 
		.i_b(i_op_b),
		.Cin(1'b1),		//sub
		.Cout(sub_ext[32]),
		.o_s(sub_ext[31:0])
	);	
	
/*	assign add_ext = {1'b0, i_op_a} + {1'b0, i_op_b};
	assign sub_ext = {1'b0, i_op_a} + {1'b0, ~i_op_b} + 33'd1;	*/

	logic [31:0] add_res, sub_res; logic sub_cout;
	assign add_res  = add_ext[31:0];
	assign sub_res  = sub_ext[31:0];
	assign sub_cout = sub_ext[32];

	logic ov_s; logic slt_signed_bit, sltu_bit;
	assign ov_s           = (i_op_a[31] ^ i_op_b[31]) & (i_op_a[31] ^ sub_res[31]);
	assign slt_signed_bit = sub_res[31] ^ ov_s;
	assign sltu_bit       = ~sub_cout;

	logic [4:0] shamt;	// shift amount
	assign shamt = i_op_b[4:0];

	// bariel shifter (sll)
	logic [31:0] sll1,sll2,sll3,sll4,sll5;
	assign sll1 = shamt[0] ? {i_op_a[30:0],1'b0}     : i_op_a;
	assign sll2 = shamt[1] ? {sll1[29:0],  2'b00}    : sll1;
	assign sll3 = shamt[2] ? {sll2[27:0],  4'b0000}  : sll2;
	assign sll4 = shamt[3] ? {sll3[23:0],  8'h00}    : sll3;
	assign sll5 = shamt[4] ? {sll4[15:0], 16'h0000}  : sll4;

	// bariel shifter (srl)
	logic [31:0] srl1,srl2,srl3,srl4,srl5;
	assign srl1 = shamt[0] ? {1'b0,     i_op_a[31:1]} : i_op_a;
	assign srl2 = shamt[1] ? {2'b00,    srl1[31:2]}   : srl1;
	assign srl3 = shamt[2] ? {4'b0000,  srl2[31:4]}   : srl2;
	assign srl4 = shamt[3] ? {8'h00,    srl3[31:8]}   : srl3;
	assign srl5 = shamt[4] ? {16'h0000, srl4[31:16]}  : srl4;

	// bariel shifter (sra)
	logic sign_a; assign sign_a = i_op_a[31];
	logic [31:0] sra1,sra2,sra3,sra4,sra5;
	assign sra1 = shamt[0] ? {sign_a,       i_op_a[31:1]} : i_op_a;
	assign sra2 = shamt[1] ? {{2{sign_a}},  sra1[31:2]}   : sra1;
	assign sra3 = shamt[2] ? {{4{sign_a}},  sra2[31:4]}   : sra2;
	assign sra4 = shamt[3] ? {{8{sign_a}},  sra3[31:8]}   : sra3;
	assign sra5 = shamt[4] ? {{16{sign_a}}, sra4[31:16]}  : sra4;

	always_comb begin
		unique case (i_alu_op)
			4'd0:	o_alu_data = add_res;
			4'd1: o_alu_data = sub_res;
			4'd2: o_alu_data = {31'b0, slt_signed_bit};
			4'd3: o_alu_data = {31'b0, sltu_bit};
			4'd4: o_alu_data = (i_op_a ^ i_op_b);
			4'd5: o_alu_data = (i_op_a | i_op_b);
			4'd6: o_alu_data = (i_op_a & i_op_b);
			4'd7: o_alu_data = sll5;
			4'd8: o_alu_data = srl5;
			4'd9: o_alu_data = sra5;
			default: o_alu_data = 32'b0;
		endcase
	end
endmodule
