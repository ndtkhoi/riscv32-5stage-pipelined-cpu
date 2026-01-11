module MEM_WB (
  input  logic        i_clk, i_reset_n, i_stall, i_flush,
  // Inputs
  input  logic        i_valid,
  input  logic [31:0] i_pc, i_alu_result, i_mem_data, i_imm_data,
  input  logic [4:0]  i_rd,
  input  logic        i_regwrite,
  input  logic [1:0]  i_wb_sel,
  input  logic        i_is_ctrl, i_mispred,

  // Outputs
  output logic        o_valid,
  output logic [31:0] o_pc, o_alu_result, o_mem_data, o_imm_data,
  output logic [4:0]  o_rd,
  output logic        o_regwrite,
  output logic [1:0]  o_wb_sel,
  output logic        o_is_ctrl, o_mispred
);

  always_ff @(posedge i_clk) begin
    if (~i_reset_n) begin
      o_valid      <= 1'b0;
      o_pc         <= 32'b0;
      o_alu_result <= 32'b0;
      // o_mem_data <= 32'b0; // REMOVED from FF
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
      // o_mem_data <= i_mem_data; // REMOVED from FF
      o_imm_data   <= i_imm_data;
      o_rd         <= i_rd;
      o_regwrite   <= i_regwrite;
      o_wb_sel     <= i_wb_sel;
      o_is_ctrl    <= i_is_ctrl;
      o_mispred    <= i_mispred;
    end
  end

  // PASS-THROUGH ASSIGNMENT
  assign o_mem_data = i_mem_data;

endmodule
