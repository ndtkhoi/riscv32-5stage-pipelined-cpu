//==============================================================
// Hazard + Forwarding Unit (1 module như hình Figure 1)
//
// - Phần Forwarding:
//   + So sánh rd ở EX/MEM, MEM/WB với rs1, rs2 ở ID/EX
//   + Tạo o_forward_a, o_forward_b cho mux ALU
//
// - Phần Hazard:
//   + Phát hiện load-use hazard giữa ID và EX
//   + Tạo o_stall_pc, o_stall_if_id, o_flush_id_ex
//==============================================================
module hazard_fwd_unit (
  // Địa chỉ register ở IF/ID (lệnh đang decode)
  input  logic [4:0] i_if_id_rs1,
  input  logic [4:0] i_if_id_rs2,

  // Địa chỉ register ở ID/EX (lệnh đang ở EX kế tiếp)
  input  logic [4:0] i_id_ex_rs1,
  input  logic [4:0] i_id_ex_rs2,
  input  logic [4:0] i_id_ex_rd,
  input  logic       i_id_ex_memread,     // lệnh EX là load?

  // Đích ở EX/MEM (để forward từ MEM stage)
  input  logic       i_ex_mem_regwrite,
  input  logic [4:0] i_ex_mem_rd,

  // Đích ở MEM/WB (để forward từ WB stage)
  input  logic       i_mem_wb_regwrite,
  input  logic [4:0] i_mem_wb_rd,

  // STALL / FLUSH
  output logic       o_stall_pc,
  output logic       o_stall_if_id,
  output logic       o_flush_id_ex,

  // Forward cho ALU
  output logic [1:0] o_forward_a,
  output logic [1:0] o_forward_b
);

  // -------------------------------
  // Load-use hazard detection
  // -------------------------------
  logic load_use_hazard;

  always_comb begin
    load_use_hazard = 1'b0;

    if (i_id_ex_memread &&
        (i_id_ex_rd != 5'd0) &&
        ((i_id_ex_rd == i_if_id_rs1) ||
         (i_id_ex_rd == i_if_id_rs2))) begin
      load_use_hazard = 1'b1;
    end

    // Nếu có load-use: dừng PC + IF/ID, chèn bubble vào ID/EX
    o_stall_pc    = load_use_hazard;
    o_stall_if_id = load_use_hazard;
    o_flush_id_ex = load_use_hazard;
  end

  // -------------------------------
  // Forwarding logic
  // -------------------------------
  always_comb begin
    // default: không forward
    o_forward_a = 2'b00;
    o_forward_b = 2'b00;

    // EX hazard (forward từ EX/MEM)
    if (i_ex_mem_regwrite && (i_ex_mem_rd != 5'd0) &&
        (i_ex_mem_rd == i_id_ex_rs1)) begin
      o_forward_a = 2'b10;
    end

    if (i_ex_mem_regwrite && (i_ex_mem_rd != 5'd0) &&
        (i_ex_mem_rd == i_id_ex_rs2)) begin
      o_forward_b = 2'b10;
    end

    // MEM hazard (forward từ MEM/WB) – không override EX/MEM
    if (i_mem_wb_regwrite && (i_mem_wb_rd != 5'd0) &&
        ~( i_ex_mem_regwrite && (i_ex_mem_rd != 5'd0) &&
           (i_ex_mem_rd == i_id_ex_rs1) ) &&
        (i_mem_wb_rd == i_id_ex_rs1)) begin
      o_forward_a = 2'b01;
    end

    if (i_mem_wb_regwrite && (i_mem_wb_rd != 5'd0) &&
        ~( i_ex_mem_regwrite && (i_ex_mem_rd != 5'd0) &&
           (i_ex_mem_rd == i_id_ex_rs2) ) &&
        (i_mem_wb_rd == i_id_ex_rs2)) begin
      o_forward_b = 2'b01;
    end
  end

endmodule
