//==============================================================
// EX/MEM pipeline register
// FIXED: Added imm_data port for LUI instruction
//==============================================================
module EX_MEM (
  input  logic        i_clk,
  input  logic        i_reset_n,
  input  logic        i_stall,
  input  logic        i_flush,

  // in
  input  logic        i_valid,
  input  logic [31:0] i_pc,
  input  logic [31:0] i_alu_result,
  input  logic [31:0] i_rs2_data_fwd,
  input  logic [31:0] i_imm_data,      // NEW: for LUI
  input  logic [4:0]  i_rd,
  input  logic [2:0]  i_funct3,
  input  logic [6:0]  i_opcode,

  input  logic        i_regwrite,
  input  logic        i_memread,
  input  logic        i_memwrite,
  input  logic [1:0]  i_wb_sel,
  input  logic        i_is_ctrl,
  input  logic        i_mispred,

  // out
  output logic        o_valid,
  output logic [31:0] o_pc,
  output logic [31:0] o_alu_result,
  output logic [31:0] o_rs2_data_fwd,
  output logic [31:0] o_imm_data,      // NEW: for LUI
  output logic [4:0]  o_rd,
  output logic [2:0]  o_funct3,
  output logic [6:0]  o_opcode,

  output logic        o_regwrite,
  output logic        o_memread,
  output logic        o_memwrite,
  output logic [1:0]  o_wb_sel,
  output logic        o_is_ctrl,
  output logic        o_mispred
);

  always_ff @(posedge i_clk) begin
    if (~i_reset_n) begin
      o_valid        <= 1'b0;
      o_pc           <= 32'b0;
      o_alu_result   <= 32'b0;
      o_rs2_data_fwd <= 32'b0;
      o_imm_data     <= 32'b0;
      o_rd           <= 5'b0;
      o_funct3       <= 3'b0;
      o_opcode       <= 7'b0;
      o_regwrite     <= 1'b0;
      o_memread      <= 1'b0;
      o_memwrite     <= 1'b0;
      o_wb_sel       <= 2'b0;
      o_is_ctrl      <= 1'b0;
      o_mispred      <= 1'b0;
    end else if (i_flush) begin
      o_valid    <= 1'b0;
      o_regwrite <= 1'b0;
      o_memread  <= 1'b0;
      o_memwrite <= 1'b0;
      o_wb_sel   <= 2'b0;
      o_is_ctrl  <= 1'b0;
      o_mispred  <= 1'b0;
    end else if (! i_stall) begin
      o_valid        <= i_valid;
      o_pc           <= i_pc;
      o_alu_result   <= i_alu_result;
      o_rs2_data_fwd <= i_rs2_data_fwd;
      o_imm_data     <= i_imm_data;
      o_rd           <= i_rd;
      o_funct3       <= i_funct3;
      o_opcode       <= i_opcode;
      o_regwrite     <= i_regwrite;
      o_memread      <= i_memread;
      o_memwrite     <= i_memwrite;
      o_wb_sel       <= i_wb_sel;
      o_is_ctrl      <= i_is_ctrl;
      o_mispred      <= i_mispred;
    end else if (i_stall) o_memread <= 1'b0;	// xoa phuc vu cho stall toan thiet ke khi read mem
  end

endmodule
