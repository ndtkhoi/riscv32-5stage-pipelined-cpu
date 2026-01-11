//==============================================================
// ID/EX pipeline register
// FINAL FIX: Correct Flush Logic & Signal Widths
//==============================================================
module ID_EX (
  input  logic        i_clk,
  input  logic        i_reset_n,
  input  logic        i_stall,
  input  logic        i_flush,

  // in
  input  logic        i_valid,
  input  logic [31:0] i_pc,
  input  logic [31:0] i_rs1_data,
  input  logic [31:0] i_rs2_data,
  input  logic [31:0] i_imm,
  input  logic [4:0]  i_rs1,
  input  logic [4:0]  i_rs2,
  input  logic [4:0]  i_rd,
  input  logic [2:0]  i_funct3,
  input  logic [6:0]  i_opcode,

  input  logic        i_regwrite,
  input  logic        i_memread,
  input  logic        i_memwrite,
  input  logic [1:0]  i_wb_sel,
  input  logic [3:0]  i_alu_op,
  input  logic        i_alu_src_imm,
  input  logic        i_alu_src_pc,
  input  logic        i_is_branch,
  input  logic        i_is_jal,
  input  logic        i_is_jalr,
  
  input 	logic			 i_pred_taken,

  // out
  output logic        o_valid,
  output logic [31:0] o_pc,
  output logic [31:0] o_rs1_data,
  output logic [31:0] o_rs2_data,
  output logic [31:0] o_imm,
  output logic [4:0]  o_rs1,
  output logic [4:0]  o_rs2,
  output logic [4:0]  o_rd,
  output logic [2:0]  o_funct3,
  output logic [6:0]  o_opcode,

  output logic        o_regwrite,
  output logic        o_memread,
  output logic        o_memwrite,
  output logic [1:0]  o_wb_sel,
  output logic [3:0]  o_alu_op,
  output logic        o_alu_src_imm,
  output logic        o_alu_src_pc,
  output logic        o_is_branch,
  output logic        o_is_jal,
  output logic        o_is_jalr,
  
  output logic		    o_pred_taken
);

  always_ff @(posedge i_clk) begin
    if (~i_reset_n) begin
      o_valid       <= 1'b0;
      o_pc          <= 32'b0;
      o_rs1_data    <= 32'b0;
      o_rs2_data    <= 32'b0;
      o_imm         <= 32'b0;
      o_rs1         <= 5'b0;
      o_rs2         <= 5'b0;
      o_rd          <= 5'b0;
      o_funct3      <= 3'b0;
      o_opcode      <= 7'b0;
      
      o_regwrite    <= 1'b0;
      o_memread     <= 1'b0;
      o_memwrite    <= 1'b0;
      o_wb_sel      <= 2'b0;
      o_alu_op      <= 4'd0;
      o_alu_src_imm <= 1'b0;
      o_alu_src_pc  <= 1'b0;
      o_is_branch   <= 1'b0;
      o_is_jal      <= 1'b0;
      o_is_jalr     <= 1'b0;
		
		o_pred_taken  <= 1'b0;
      
    end else if (i_flush) begin
      // === QUAN TRỌNG: Khi flush, phải xóa cờ Valid và Control ===
      o_valid       <= 1'b0;
      o_regwrite    <= 1'b0;
      o_memread     <= 1'b0;
      o_memwrite    <= 1'b0;
      o_is_branch   <= 1'b0;
      o_is_jal      <= 1'b0; 
      o_is_jalr     <= 1'b0;
		o_pred_taken  <= 1'b0;
      // Các tín hiệu data khác không cần xóa để tiết kiệm logic
      
    end else if (!i_stall) begin
      o_valid       <= i_valid;
      o_pc          <= i_pc;
      o_rs1_data    <= i_rs1_data;
      o_rs2_data    <= i_rs2_data;
      o_imm         <= i_imm;
      o_rs1         <= i_rs1;
      o_rs2         <= i_rs2;
      o_rd          <= i_rd;
      o_funct3      <= i_funct3;
      o_opcode      <= i_opcode;

      o_regwrite    <= i_regwrite;
      o_memread     <= i_memread;
      o_memwrite    <= i_memwrite;
      o_wb_sel      <= i_wb_sel;
      o_alu_op      <= i_alu_op;
      o_alu_src_imm <= i_alu_src_imm;
      o_alu_src_pc  <= i_alu_src_pc;
      o_is_branch   <= i_is_branch;
      o_is_jal      <= i_is_jal;
      o_is_jalr     <= i_is_jalr;
		
		o_pred_taken  <= i_pred_taken;
    end
  end

endmodule