//==============================================================
// Hazard + Forwarding Unit
//==============================================================
module hazard_fwd_unit (
  // IF/ID stage (Current decoding instruction)
  input  logic [4:0] i_if_id_rs1,
  input  logic [4:0] i_if_id_rs2,

  // ID/EX stage (Previous instruction)
  input  logic [4:0] i_id_ex_rs1,
  input  logic [4:0] i_id_ex_rs2,
  input  logic [4:0] i_id_ex_rd,
  input  logic       i_id_ex_memread,

  // EX/MEM stage
  input  logic       i_ex_mem_regwrite,
  input  logic [4:0] i_ex_mem_rd,

  // MEM/WB stage
  input  logic       i_mem_wb_regwrite,
  input  logic [4:0] i_mem_wb_rd,

  // Outputs
  output logic       o_stall_pc,
  output logic       o_stall_if_id,
  output logic       o_flush_id_ex,
  output logic [1:0] o_forward_a,
  output logic [1:0] o_forward_b
);

  //=============================================================
  // 1. HELPER SIGNALS (Structural Equality Checks)
  //=============================================================
  
  // --- Check Non-Zero (Thay thế: != 0) ---
  // Sử dụng Reduction OR (|): Nếu có bất kỳ bit nào là 1, kết quả là 1.
  wire id_ex_rd_nz  = |i_id_ex_rd;
  wire ex_mem_rd_nz = |i_ex_mem_rd;
  wire mem_wb_rd_nz = |i_mem_wb_rd;

  // --- Check Equality (Thay thế: ==) ---
  // A == B tương đương với ~(|(A ^ B)) (NOR của XOR)
  
  // Hazard Detection Checks:
  wire match_id_ex_rd_rs1 = ~|(i_id_ex_rd ^ i_if_id_rs1);
  wire match_id_ex_rd_rs2 = ~|(i_id_ex_rd ^ i_if_id_rs2);

  // Forwarding Checks (EX/MEM -> ID/EX):
  wire match_ex_mem_rd_rs1 = ~|(i_ex_mem_rd ^ i_id_ex_rs1);
  wire match_ex_mem_rd_rs2 = ~|(i_ex_mem_rd ^ i_id_ex_rs2);

  // Forwarding Checks (MEM/WB -> ID/EX):
  wire match_mem_wb_rd_rs1 = ~|(i_mem_wb_rd ^ i_id_ex_rs1);
  wire match_mem_wb_rd_rs2 = ~|(i_mem_wb_rd ^ i_id_ex_rs2);


  //=============================================================
  // 2. LOAD-USE HAZARD DETECTION
  //=============================================================
  logic load_use_hazard;

  always_comb begin
    // Logic gốc: if (i_id_ex_memread && (i_id_ex_rd != 0) && ((rd == rs1) || (rd == rs2)))
    // Logic mới: Sử dụng các dây tín hiệu đã tạo ở trên
    if (i_id_ex_memread && 
        id_ex_rd_nz && 
        (match_id_ex_rd_rs1 || match_id_ex_rd_rs2)) begin
      load_use_hazard = 1'b1;
    end else begin
      load_use_hazard = 1'b0;
    end

    // Outputs
    o_stall_pc    = load_use_hazard;
    o_stall_if_id = load_use_hazard;
    o_flush_id_ex = load_use_hazard;
  end


  //=============================================================
  // 3. FORWARDING LOGIC
  //=============================================================
  always_comb begin
    // Default: No forwarding
    o_forward_a = 2'b00;
    o_forward_b = 2'b00;

    // --- EX HAZARD (Forward from EX/MEM) ---
    // if (regwrite && rd != 0 && rd == rs1)
    if (i_ex_mem_regwrite && ex_mem_rd_nz && match_ex_mem_rd_rs1) begin
      o_forward_a = 2'b10;
    end

    // if (regwrite && rd != 0 && rd == rs2)
    if (i_ex_mem_regwrite && ex_mem_rd_nz && match_ex_mem_rd_rs2) begin
      o_forward_b = 2'b10;
    end

    // --- MEM HAZARD (Forward from MEM/WB) ---
    // ForwardA
    // if (wb_regwrite && wb_rd != 0 && !(ex_regwrite && ex_rd != 0 && ex_rd == rs1) && wb_rd == rs1)
    if (i_mem_wb_regwrite && mem_wb_rd_nz && 
        !(i_ex_mem_regwrite && ex_mem_rd_nz && match_ex_mem_rd_rs1) && 
        match_mem_wb_rd_rs1) begin
      o_forward_a = 2'b01;
    end

    // ForwardB
    // if (wb_regwrite && wb_rd != 0 && !(ex_regwrite && ex_rd != 0 && ex_rd == rs2) && wb_rd == rs2)
    if (i_mem_wb_regwrite && mem_wb_rd_nz && 
        !(i_ex_mem_regwrite && ex_mem_rd_nz && match_ex_mem_rd_rs2) && 
        match_mem_wb_rd_rs2) begin
      o_forward_b = 2'b01;
    end
  end

endmodule
