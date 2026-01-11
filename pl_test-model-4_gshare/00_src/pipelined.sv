//==============================================================
// Pipelined RV32I Processor (Milestone 3)
// Two-bit predictor + FIX IPC: IMEM prefetch by pc_next
// NOTE: IF_ID is combinational pass-through => flush must be gated by "pc update"
//==============================================================
module pipelined (
  input  logic        i_clk,
  input  logic        i_reset,   // active-low (as used in always_ff negedge)

  output logic [31:0] o_pc_debug,
  output logic        o_insn_vld,
  output logic        o_ctrl,
  output logic        o_mispred,

  output logic [31:0] o_io_ledr,
  output logic [31:0] o_io_ledg,
  output logic [6:0]  o_io_hex0,
  output logic [6:0]  o_io_hex1,
  output logic [6:0]  o_io_hex2,
  output logic [6:0]  o_io_hex3,
  output logic [6:0]  o_io_hex4,
  output logic [6:0]  o_io_hex5,
  output logic [6:0]  o_io_hex6,
  output logic [6:0]  o_io_hex7,
  output logic [31:0] o_io_lcd,
  input  logic [31:0] i_io_sw
);

  // ============================================================
  // Signal Declarations
  // ============================================================
  logic [31:0] pc, pc_next, pc_four, instr_if;
  logic        stall_pc, ex_stall_if_id, flush_if_id_ctrl, if_id_valid;
  logic [31:0] if_id_pc, if_id_instr;

  logic [6:0]  if_id_opcode, if_id_funct7;
  logic [4:0]  if_id_rs1_raw, if_id_rs2_raw, if_id_rd, if_id_rs1, if_id_rs2;
  logic [2:0]  if_id_funct3;
  logic [31:0] rs1_data_id, rs2_data_id, imm_id;

  logic        id_pred_taken;

  logic        id_regwrite, id_memread, id_memwrite;
  logic [1:0]  id_wb_sel;
  logic [3:0]  id_alu_op;
  logic        id_alu_src_imm, id_alu_src_pc;
  logic        id_is_branch, id_is_jal, id_is_jalr;
  logic [31:0] id_pc_branchtaken;

  logic        flush_id_ex_data, flush_id_ex_ctrl, id_ex_valid;
  logic [31:0] id_ex_pc, id_ex_rs1_data, id_ex_rs2_data, id_ex_imm;
  logic [4:0]  id_ex_rs1, id_ex_rs2, id_ex_rd;
  logic [2:0]  id_ex_funct3;
  logic [6:0]  id_ex_opcode;
  logic        id_ex_regwrite, id_ex_memread, id_ex_memwrite;
  logic [1:0]  id_ex_wb_sel;
  logic [3:0]  id_ex_alu_op;
  logic        id_ex_alu_src_imm, id_ex_alu_src_pc;
  logic        id_ex_is_branch, id_ex_is_jal, id_ex_is_jalr;
  logic        id_ex_pred_taken;

  logic        ex_mem_valid;
  logic [31:0] ex_mem_pc, ex_mem_alu_result, ex_mem_rs2_data_fwd, ex_mem_imm_data;
  logic [4:0]  ex_mem_rd;
  logic [2:0]  ex_mem_funct3;
  logic [6:0]  ex_mem_opcode;
  logic        ex_mem_regwrite, ex_mem_memread, ex_mem_memwrite;
  logic [1:0]  ex_mem_wb_sel;
  logic        ex_mem_is_ctrl, ex_mem_mispred;

  logic        branch_taken;
  logic [31:0] ex_pc_four;
  logic [31:0] ex_pc_branchtaken;

  logic        ex_mispred_flag;
  logic        ex_ctrl_redirect;
  logic        redirect_fire;

  logic        mem_wb_valid;
  logic [31:0] mem_wb_pc, mem_wb_alu_result, mem_wb_mem_data, mem_wb_imm_data;
  logic [4:0]  mem_wb_rd;
  logic        mem_wb_regwrite;
  logic [1:0]  mem_wb_wb_sel;
  logic        mem_wb_is_ctrl, mem_wb_mispred;
  logic [31:0] mem_pc_four;

  logic        mem_stall_ex_mem;
  logic        mem_stall_id_ex;
  logic        mem_stall_pc;
  logic        mem_stall_if_id;

  logic [31:0] wb_data;
  logic [31:0] wb_pc_four;

  // ============================================================
  // IF Stage: Instruction Fetch  (IMEM prefetch = pc_next)
  // ============================================================

  addsub32 addsub_if_pc4 ( // pc_four = pc + 4
    .i_a(pc),
    .i_b(32'd4),
    .Cin(1'b0),
    .Cout(),
    .o_s(pc_four)
  );

  assign o_pc_debug = mem_wb_valid ? mem_wb_pc : 32'b0;

  // pc update enable
  wire pc_en = !(stall_pc || mem_stall_pc);

  // IMPORTANT: reset pc = -4 so first pc_next (pc+4) = 0
  always_ff @(posedge i_clk or negedge i_reset) begin
    if (!i_reset) pc <= 32'hFFFF_FFFC;
    else if (pc_en) pc <= pc_next;
  end

  // When stalled, keep reading current pc; else read pc_next (prefetch)
  wire fetch_stall = (ex_stall_if_id | mem_stall_if_id | stall_pc | mem_stall_pc);

  logic [31:0] imem_addr;
  assign imem_addr = fetch_stall ? pc : pc_next;

  instruction_memory u_imem ( // IMEM synchronous
    .i_clk(i_clk),
    .i_reset(i_reset),
    .i_addr(imem_addr[15:0]),
    .o_rdata(instr_if)
  );

  // ============================================================
  // IF/ID "buffer" (combinational pass-through)
  // ============================================================
  IF_ID u_if_id (
    .i_clk(i_clk),
    .i_reset_n(i_reset),
    .i_stall(ex_stall_if_id | mem_stall_if_id),
    .i_flush(flush_if_id_ctrl),
    .i_pc(pc),              // NOW pc matches instr_if (due to prefetch scheme)
    .i_instr(instr_if),
    .o_valid(if_id_valid),
    .o_pc(if_id_pc),
    .o_instr(if_id_instr)
  );

  // ============================================================
  // ID Stage: Instruction Decode
  // ============================================================
  assign if_id_opcode  = if_id_instr[6:0];
  assign if_id_rd      = if_id_instr[11:7];
  assign if_id_funct3  = if_id_instr[14:12];
  assign if_id_rs1_raw = if_id_instr[19:15];
  assign if_id_rs2_raw = if_id_instr[24:20];
  assign if_id_funct7  = if_id_instr[31:25];

  always_comb begin
    if ((if_id_opcode == 7'b0110111) || (if_id_opcode == 7'b0010111) || (if_id_opcode == 7'b1101111))
      if_id_rs1 = 5'd0;
    else
      if_id_rs1 = if_id_rs1_raw;

    if ((if_id_opcode == 7'b0110011) || (if_id_opcode == 7'b0100011) || (if_id_opcode == 7'b1100011))
      if_id_rs2 = if_id_rs2_raw;
    else
      if_id_rs2 = 5'd0;
  end

  logic regwrite_valid;
  assign regwrite_valid = mem_wb_regwrite & mem_wb_valid & (mem_wb_rd != 5'd0);

  regfile u_regfile (
    .i_clk(i_clk),
    .i_reset(1'b0),
    .i_rs1_addr(if_id_rs1),
    .i_rs2_addr(if_id_rs2),
    .o_rs1_data(rs1_data_id),
    .o_rs2_data(rs2_data_id),
    .i_rd_addr(mem_wb_rd),
    .i_rd_data(wb_data),
    .i_rd_wren(regwrite_valid)
  );

  imm_gen u_imm (
    .i_instr(if_id_instr),
    .o_imm(imm_id)
  );

  addsub32 add_id_pc_branchtaken ( // id_pc_branchtaken = if_id_pc + imm_id
    .i_a(if_id_pc),
    .i_b(imm_id),
    .Cin(1'b0),
    .Cout(),
    .o_s(id_pc_branchtaken)
  );

  // ============================================================
  // Control Unit (Decode)
  // ============================================================
  always_comb begin
    id_regwrite = 1'b0; id_memread = 1'b0; id_memwrite = 1'b0;
    id_wb_sel = 2'b00; id_alu_op = 4'd0;
    id_alu_src_imm = 1'b0; id_alu_src_pc = 1'b0;
    id_is_branch = 1'b0; id_is_jal = 1'b0; id_is_jalr = 1'b0;

    case (if_id_opcode)
      7'b0110011: begin
        id_regwrite = (if_id_rd != 5'd0);
        case ({if_id_funct7, if_id_funct3})
          {7'b0000000, 3'b000}: id_alu_op = 4'd0;
          {7'b0100000, 3'b000}: id_alu_op = 4'd1;
          {7'b0000000, 3'b010}: id_alu_op = 4'd2;
          {7'b0000000, 3'b011}: id_alu_op = 4'd3;
          {7'b0000000, 3'b100}: id_alu_op = 4'd4;
          {7'b0000000, 3'b110}: id_alu_op = 4'd5;
          {7'b0000000, 3'b111}: id_alu_op = 4'd6;
          {7'b0000000, 3'b001}: id_alu_op = 4'd7;
          {7'b0000000, 3'b101}: id_alu_op = 4'd8;
          {7'b0100000, 3'b101}: id_alu_op = 4'd9;
          default: id_alu_op = 4'd0;
        endcase
      end

      7'b0010011: begin
        id_regwrite = (if_id_rd != 5'd0);
        id_alu_src_imm = 1'b1;
        case (if_id_funct3)
          3'b000: id_alu_op = 4'd0;
          3'b010: id_alu_op = 4'd2;
          3'b011: id_alu_op = 4'd3;
          3'b100: id_alu_op = 4'd4;
          3'b110: id_alu_op = 4'd5;
          3'b111: id_alu_op = 4'd6;
          3'b001: id_alu_op = 4'd7;
          3'b101: id_alu_op = (if_id_funct7 == 7'b0000000) ? 4'd8 : 4'd9;
          default: id_alu_op = 4'd0;
        endcase
      end

      7'b0000011: begin
        id_regwrite = (if_id_rd != 5'd0);
        id_memread = 1'b1;
        id_wb_sel = 2'b01;
        id_alu_src_imm = 1'b1;
      end

      7'b0100011: begin
        id_memwrite = 1'b1;
        id_alu_src_imm = 1'b1;
      end

      7'b1100011: begin
        id_is_branch = 1'b1;
        id_alu_op = 4'd1;
      end

      7'b1101111: begin
        id_regwrite = (if_id_rd != 5'd0);
        id_is_jal = 1'b1;
        id_wb_sel = 2'b10;
        id_alu_src_imm = 1'b1;
        id_alu_src_pc = 1'b1;
      end

      7'b1100111: begin
        id_regwrite = (if_id_rd != 5'd0);
        id_is_jalr = 1'b1;
        id_wb_sel = 2'b10;
        id_alu_src_imm = 1'b1;
        id_alu_op = 4'd0; // FIX: must be 4 bits
      end

      7'b0110111: begin
        id_regwrite = (if_id_rd != 5'd0);
        id_wb_sel = 2'b11;
        id_alu_src_imm = 1'b1;
      end

      7'b0010111: begin
        id_regwrite = (if_id_rd != 5'd0);
        id_alu_src_imm = 1'b1;
        id_alu_src_pc = 1'b1;
      end

      default: begin end
    endcase
  end

  // ============================================================
  // Branch Predictor (2-bit)
  // ============================================================
  branch_predictor BRC_PREDICTOR (
    .i_clk(i_clk),
    .i_reset_n(i_reset),
    .i_pc_read(if_id_pc),
    .o_pred_taken(id_pred_taken),

    .i_wen(id_ex_valid && id_ex_is_branch), // update only when EX valid branch
    .i_pc_write(id_ex_pc),
    .i_actual_taken(branch_taken)
  );

  // ============================================================
  // ID/EX Pipeline Register
  // ============================================================
  ID_EX u_id_ex (
    .i_pred_taken (id_pred_taken),
    .i_clk(i_clk),
    .i_reset_n(i_reset),
    .i_stall(mem_stall_id_ex),
    .i_flush(flush_id_ex_data | flush_id_ex_ctrl),
    .i_valid(if_id_valid),

    .i_pc(if_id_pc),
    .i_rs1_data(rs1_data_id),
    .i_rs2_data(rs2_data_id),
    .i_imm(imm_id),
    .i_rs1(if_id_rs1),
    .i_rs2(if_id_rs2),
    .i_rd(if_id_rd),
    .i_funct3(if_id_funct3),
    .i_opcode(if_id_opcode),

    .i_regwrite(id_regwrite),
    .i_memread(id_memread),
    .i_memwrite(id_memwrite),
    .i_wb_sel(id_wb_sel),
    .i_alu_op(id_alu_op),
    .i_alu_src_imm(id_alu_src_imm),
    .i_alu_src_pc(id_alu_src_pc),
    .i_is_branch(id_is_branch),
    .i_is_jal(id_is_jal),
    .i_is_jalr(id_is_jalr),

    .o_valid(id_ex_valid),
    .o_pc(id_ex_pc),
    .o_rs1_data(id_ex_rs1_data),
    .o_rs2_data(id_ex_rs2_data),
    .o_imm(id_ex_imm),
    .o_rs1(id_ex_rs1),
    .o_rs2(id_ex_rs2),
    .o_rd(id_ex_rd),
    .o_funct3(id_ex_funct3),
    .o_opcode(id_ex_opcode),

    .o_regwrite(id_ex_regwrite),
    .o_memread(id_ex_memread),
    .o_memwrite(id_ex_memwrite),
    .o_wb_sel(id_ex_wb_sel),
    .o_alu_op(id_ex_alu_op),
    .o_alu_src_imm(id_ex_alu_src_imm),
    .o_alu_src_pc(id_ex_alu_src_pc),
    .o_is_branch(id_ex_is_branch),
    .o_is_jal(id_ex_is_jal),
    .o_is_jalr(id_ex_is_jalr),

    .o_pred_taken(id_ex_pred_taken)
  );

  // ============================================================
  // Hazard Detection & Forwarding Unit
  // ============================================================
  logic [1:0] forward_a, forward_b;

  hazard_fwd_unit u_hfu (
    .i_if_id_rs1(if_id_rs1),
    .i_if_id_rs2(if_id_rs2),
    .i_id_ex_rs1(id_ex_rs1),
    .i_id_ex_rs2(id_ex_rs2),
    .i_id_ex_rd(id_ex_rd),
    .i_id_ex_memread(id_ex_memread),
    .i_ex_mem_regwrite(ex_mem_regwrite),
    .i_ex_mem_rd(ex_mem_rd),
    .i_mem_wb_regwrite(mem_wb_regwrite),
    .i_mem_wb_rd(mem_wb_rd),

    .o_stall_pc(stall_pc),
    .o_stall_if_id(ex_stall_if_id),
    .o_flush_id_ex(flush_id_ex_data),
    .o_forward_a(forward_a),
    .o_forward_b(forward_b)
  );

  // ============================================================
  // EX Stage: Execute
  // ============================================================
  addsub32 add_ex_pc_four ( // ex_pc_four = id_ex_pc + 4
    .i_a(id_ex_pc),
    .i_b(32'd4),
    .Cin(1'b0),
    .Cout(),
    .o_s(ex_pc_four)
  );

  logic [31:0] ex_mem_fwd_data;
  always_comb begin
    case (ex_mem_wb_sel)
      2'b00: ex_mem_fwd_data = ex_mem_alu_result;
      2'b01: ex_mem_fwd_data = ex_mem_alu_result;
      2'b10: ex_mem_fwd_data = mem_pc_four;
      2'b11: ex_mem_fwd_data = ex_mem_imm_data;
      default: ex_mem_fwd_data = ex_mem_alu_result;
    endcase
  end

  logic [31:0] rs1_fwd, rs2_fwd;
  always_comb begin
    if (id_ex_rs1 == 5'd0) rs1_fwd = 32'd0;
    else case (forward_a)
      2'b10:   rs1_fwd = ex_mem_fwd_data;
      2'b01:   rs1_fwd = wb_data;
      default: rs1_fwd = id_ex_rs1_data;
    endcase
  end

  always_comb begin
    if (id_ex_rs2 == 5'd0) rs2_fwd = 32'd0;
    else case (forward_b)
      2'b10:   rs2_fwd = ex_mem_fwd_data;
      2'b01:   rs2_fwd = wb_data;
      default: rs2_fwd = id_ex_rs2_data;
    endcase
  end

  logic [31:0] alu_in_a, alu_in_b, alu_result;
  always_comb begin
    if (id_ex_alu_src_pc) alu_in_a = id_ex_pc;
    else alu_in_a = rs1_fwd;
  end

  always_comb begin
    if (id_ex_alu_src_imm) alu_in_b = id_ex_imm;
    else alu_in_b = rs2_fwd;
  end

  alu u_alu (
    .i_op_a(alu_in_a),
    .i_op_b(alu_in_b),
    .i_alu_op(id_ex_alu_op),
    .o_alu_data(alu_result)
  );

  // Branch compare
  logic br_un;
  assign br_un = (id_ex_opcode == 7'b1100011) &&
                 ((id_ex_funct3 == 3'b110) || (id_ex_funct3 == 3'b111));

  logic br_less, br_equal;
  brc u_brc (
    .i_rs1_data(rs1_fwd),
    .i_rs2_data(rs2_fwd),
    .i_br_un(br_un),
    .o_br_less(br_less),
    .o_br_equal(br_equal)
  );

  always_comb begin
    branch_taken = 1'b0;
    if (id_ex_is_branch) begin
      case (id_ex_funct3)
        3'b000: branch_taken = br_equal;
        3'b001: branch_taken = ~br_equal;
        3'b100: branch_taken = br_less;
        3'b101: branch_taken = ~br_less;
        3'b110: branch_taken = br_less;
        3'b111: branch_taken = ~br_less;
        default: branch_taken = 1'b0;
      endcase
    end
  end

  wire ex_is_jal    = (id_ex_opcode == 7'b1101111);
  wire ex_is_jalr   = (id_ex_opcode == 7'b1100111);
  wire ex_is_branch = (id_ex_opcode == 7'b1100011);

  addsub32 add_ex_pc_branchtaken ( // ex_pc_branchtaken = id_ex_pc + id_ex_imm
    .i_a(id_ex_pc),
    .i_b(id_ex_imm),
    .Cin(1'b0),
    .Cout(),
    .o_s(ex_pc_branchtaken)
  );

  // Only BRANCH can be mispredicted
  assign ex_mispred_flag = id_ex_valid && ( ex_is_jalr | (ex_is_branch && (id_ex_pred_taken != branch_taken)) ); // set khi ex đang có lệnh và predict sai
  // Redirect only for JALR or BR mispred (JAL handled in ID)
  assign ex_ctrl_redirect = id_ex_valid && (ex_is_jalr || ex_mispred_flag);

  // Redirect/flush only when PC is allowed to update (avoid flush during stall)
  assign redirect_fire = ex_ctrl_redirect && pc_en;

  // ============================================================
  // PC NEXT (priority EX older > ID younger)
  // ============================================================
  always_comb begin
    pc_next = pc_four;

    // EX (older)
    if (id_ex_valid && ex_is_jalr) begin
      pc_next = alu_result & ~32'd1;
    end
    else if (ex_mispred_flag) begin
      if (branch_taken) pc_next = ex_pc_branchtaken;
      else              pc_next = ex_pc_four;
    end
    // ID (younger)
    else if (id_is_jal) begin
      pc_next = id_pc_branchtaken;
    end
    else if (id_is_branch && id_pred_taken) begin
      pc_next = id_pc_branchtaken;
    end
  end

  // With IMEM prefetch by pc_next:
  // - NO NEED flush for ID redirect (JAL / predicted-taken BR) anymore
  // - Only flush for EX redirect (JALR / mispred), and only when redirect_fire
  assign flush_if_id_ctrl = redirect_fire;
  assign flush_id_ex_ctrl = redirect_fire;

  logic [31:0] store_data_fwd;
  assign store_data_fwd = rs2_fwd;

  // ============================================================
  // EX/MEM Pipeline Register
  // ============================================================
  EX_MEM u_ex_mem (
    .i_clk(i_clk),
    .i_reset_n(i_reset),
    .i_stall(mem_stall_ex_mem),
    .i_flush(1'b0),

    .i_valid(id_ex_valid),
    .i_pc(id_ex_pc),
    .i_alu_result(alu_result),
    .i_rs2_data_fwd(store_data_fwd),
    .i_imm_data(id_ex_imm),
    .i_rd(id_ex_rd),
    .i_funct3(id_ex_funct3),
    .i_opcode(id_ex_opcode),
    .i_regwrite(id_ex_regwrite),
    .i_memread(id_ex_memread),
    .i_memwrite(id_ex_memwrite),
    .i_wb_sel(id_ex_wb_sel),
    .i_is_ctrl(id_ex_valid && (ex_is_branch | ex_is_jal | ex_is_jalr)),
    .i_mispred(ex_mispred_flag),

    .o_valid(ex_mem_valid),
    .o_pc(ex_mem_pc),
    .o_alu_result(ex_mem_alu_result),
    .o_rs2_data_fwd(ex_mem_rs2_data_fwd),
    .o_imm_data(ex_mem_imm_data),
    .o_rd(ex_mem_rd),
    .o_funct3(ex_mem_funct3),
    .o_opcode(ex_mem_opcode),
    .o_regwrite(ex_mem_regwrite),
    .o_memread(ex_mem_memread),
    .o_memwrite(ex_mem_memwrite),
    .o_wb_sel(ex_mem_wb_sel),
    .o_is_ctrl(ex_mem_is_ctrl),
    .o_mispred(ex_mem_mispred)
  );

  // ============================================================
  // MEM Stage: Memory Access
  // ============================================================
  addsub32 add_mem_pc_four ( // mem_pc_four = ex_mem_pc + 4
    .i_a(ex_mem_pc),
    .i_b(32'd4),
    .Cin(1'b0),
    .Cout(),
    .o_s(mem_pc_four)
  );

  logic [31:0] mem_stage_ld_data;

  lsu u_lsu (
    .i_clk(i_clk),
    .i_reset(i_reset),
    .i_lsu_addr(ex_mem_alu_result),
    .i_st_data(ex_mem_rs2_data_fwd),
    .i_lsu_wren(ex_mem_memwrite),
    .o_ld_data(mem_stage_ld_data),

    .o_io_ledr(o_io_ledr),
    .o_io_ledg(o_io_ledg),
    .o_io_hex0(o_io_hex0),
    .o_io_hex1(o_io_hex1),
    .o_io_hex2(o_io_hex2),
    .o_io_hex3(o_io_hex3),
    .o_io_hex4(o_io_hex4),
    .o_io_hex5(o_io_hex5),
    .o_io_hex6(o_io_hex6),
    .o_io_hex7(o_io_hex7),
    .o_io_lcd(o_io_lcd),
    .i_io_sw(i_io_sw),

    .i_funct3(ex_mem_funct3)
  );

  // STALL CONTROLLER (STALL CHỜ ĐỌC DMEM)
  always_comb begin
    mem_stall_ex_mem = 1'b0;
    mem_stall_id_ex  = 1'b0;
    mem_stall_pc     = 1'b0;
    mem_stall_if_id  = 1'b0;

    if (ex_mem_memread) begin
      mem_stall_ex_mem = 1'b1;
      mem_stall_id_ex  = 1'b1;
      mem_stall_pc     = 1'b1;
      mem_stall_if_id  = 1'b1;
    end
  end

  // ============================================================
  // MEM/WB Pipeline Register
  // ============================================================
  MEM_WB u_mem_wb (
    .i_clk(i_clk),
    .i_reset_n(i_reset),
    .i_stall(1'b0),
    .i_flush(1'b0),

    .i_valid(ex_mem_valid),
    .i_pc(ex_mem_pc),
    .i_alu_result(ex_mem_alu_result),
    .i_mem_data(mem_stage_ld_data),
    .i_imm_data(ex_mem_imm_data),
    .i_rd(ex_mem_rd),
    .i_regwrite(ex_mem_regwrite),
    .i_wb_sel(ex_mem_wb_sel),
    .i_is_ctrl(ex_mem_is_ctrl),
    .i_mispred(ex_mem_mispred),

    .o_valid(mem_wb_valid),
    .o_pc(mem_wb_pc),
    .o_alu_result(mem_wb_alu_result),
    .o_mem_data(mem_wb_mem_data),
    .o_imm_data(mem_wb_imm_data),
    .o_rd(mem_wb_rd),
    .o_regwrite(mem_wb_regwrite),
    .o_wb_sel(mem_wb_wb_sel),
    .o_is_ctrl(mem_wb_is_ctrl),
    .o_mispred(mem_wb_mispred)
  );

  // ============================================================
  // WB Stage: Write Back
  // ============================================================
  addsub32 add_wb_pc_four ( // wb_pc_four = mem_wb_pc + 4
    .i_a(mem_wb_pc),
    .i_b(32'd4),
    .Cin(1'b0),
    .Cout(),
    .o_s(wb_pc_four)
  );

  always_comb begin
    case (mem_wb_wb_sel)
      2'b00: wb_data = mem_wb_alu_result;
      2'b01: wb_data = mem_wb_mem_data;
      2'b10: wb_data = wb_pc_four;
      2'b11: wb_data = mem_wb_imm_data;
      default: wb_data = mem_wb_alu_result;
    endcase
  end

  // ============================================================
  // Output Signals
  // ============================================================
  assign o_insn_vld = mem_wb_valid;
  assign o_ctrl     = mem_wb_valid & mem_wb_is_ctrl;
  assign o_mispred  = mem_wb_valid & mem_wb_mispred;

endmodule
