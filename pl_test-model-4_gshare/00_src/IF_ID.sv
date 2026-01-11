//==============================================================
// IF/ID pipeline register
// FIXED: Adjusted for Synchronous Instruction Memory
//==============================================================
module IF_ID (
  input  logic        i_clk,
  input  logic        i_reset_n,   // active-low
  input  logic        i_stall,     // (Được xử lý gián tiếp qua việc Stall PC)
  input  logic        i_flush,     // flush do branch/jump taken

  //in
  input  logic [31:0] i_pc,        // Đã được delay 1 chu kỳ từ pipelined.sv
  input  logic [31:0] i_instr,     // Đã được latch trong instruction_memory

  // out
  output logic        o_valid,
  output logic [31:0] o_pc,
  output logic [31:0] o_instr
);

  // --- LOGIC TỔ HỢP (COMBINATIONAL) ---
  // Không dùng always_ff cho instruction và PC để tránh trễ 2 chu kỳ.
  // Nếu Flush hoặc đang Reset -> chèn lệnh NOP (addi x0, x0, 0 = 0x00000013)
  // Ngược lại -> cho lệnh đi qua (Pass-through)
  assign o_instr = (i_flush || !i_reset_n) ? 32'h0000_0013 : i_instr;
  // PC đi kèm (đã được đồng bộ từ bên ngoài)
  assign o_pc = i_pc;
  // Tín hiệu Valid: Hợp lệ khi không Reset và không Flush
  assign o_valid = i_reset_n && !i_flush;

endmodule