//==============================================================
// MEM/WB pipeline register
// RESTORED: Full Register mode to align with pipeline stages
//==============================================================
module MEM_WB (
  input  logic        i_clk,
  input  logic        i_reset_n,
  input  logic        i_stall,
  input  logic        i_flush,

  // in
  input  logic        i_valid,
  input  logic [31:0] i_pc,
  input  logic [31:0] i_alu_result,
  input  logic [31:0] i_mem_data,  
  input  logic [31:0] i_imm_data,
  input  logic [4:0]  i_rd,
  input  logic        i_regwrite,
  input  logic [1:0]  i_wb_sel,
  input  logic        i_is_ctrl,
  input  logic        i_mispred,

  // out
  output logic        o_valid,
  output logic [31:0] o_pc,
  output logic [31:0] o_alu_result,
  output logic [31:0] o_mem_data,
  output logic [31:0] o_imm_data,
  output logic [4:0]  o_rd,
  output logic        o_regwrite,
  output logic [1:0]  o_wb_sel,
  output logic        o_is_ctrl,
  output logic        o_mispred
);

  always_ff @(posedge i_clk) begin
    if (~i_reset_n) begin
      o_valid      <= 1'b0;
      o_pc         <= 32'b0;
      o_alu_result <= 32'b0;
      o_mem_data   <= 32'b0; // KHÔI PHỤC LẠI DÒNG NÀY
      o_imm_data   <= 32'b0;
      o_rd         <= 5'b0;
      o_regwrite   <= 1'b0;
      o_wb_sel     <= 2'b0;
      o_is_ctrl    <= 1'b0;
      o_mispred    <= 1'b0;
    end else if (i_flush) begin
      o_valid      <= 1'b0;
      o_regwrite   <= 1'b0;
      o_wb_sel     <= 2'b0;
      o_is_ctrl    <= 1'b0;
      o_mispred    <= 1'b0;
    end else if (!i_stall) begin
      o_valid      <= i_valid;
      o_pc         <= i_pc;
      o_alu_result <= i_alu_result;
      o_mem_data   <= i_mem_data; // KHÔI PHỤC LẠI DÒNG NÀY
      o_imm_data   <= i_imm_data;
      o_rd         <= i_rd;
      o_regwrite   <= i_regwrite;
      o_wb_sel     <= i_wb_sel;
      o_is_ctrl    <= i_is_ctrl;
      o_mispred    <= i_mispred;
    end
  end

endmodule
