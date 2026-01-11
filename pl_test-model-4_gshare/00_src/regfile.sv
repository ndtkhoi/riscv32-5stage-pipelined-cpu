//==============================================================
// Regfile - Modified for Pipelining
// FIXED: Internal Forwarding (WB->ID Bypass) to fix Data Hazard
//        Using POSEDGE only (Synchronous Design)
//==============================================================
module regfile (
    input  logic        i_clk,
    input  logic        i_reset,
    input  logic [4:0]  i_rs1_addr,
    input  logic [4:0]  i_rs2_addr,
    output logic [31:0] o_rs1_data,
    output logic [31:0] o_rs2_data,
    input  logic [4:0]  i_rd_addr,
    input  logic [31:0] i_rd_data,
    input  logic        i_rd_wren
);

    logic [31:0] regs [0:31];

    // Khởi tạo
    initial begin
      integer i;
      for (i = 0; i < 32; i = i + 1) regs[i] = 32'b0;
    end

    // GHI: Dùng posedge CLK (Theo đúng chuẩn thầy yêu cầu)
    always_ff @(posedge i_clk) begin
      if (i_rd_wren && (i_rd_addr != 5'd0)) begin
        regs[i_rd_addr] <= i_rd_data;
      end
    end

    // ĐỌC: Logic tổ hợp có tích hợp Internal Forwarding
    // Nếu đang ghi vào đúng thanh ghi muốn đọc -> Lấy ngay giá trị đang ghi (Bypass)
    
    // --- Port 1 ---
    always_comb begin
      if (i_rs1_addr == 5'd0) begin
        o_rs1_data = 32'b0;
      end else if (i_rd_wren && (i_rd_addr == i_rs1_addr)) begin
        o_rs1_data = i_rd_data; // Forwarding từ WB về ID ngay trong chu kỳ này
      end else begin
        o_rs1_data = regs[i_rs1_addr];
      end
    end

    // --- Port 2 ---
    always_comb begin
      if (i_rs2_addr == 5'd0) begin
        o_rs2_data = 32'b0;
      end else if (i_rd_wren && (i_rd_addr == i_rs2_addr)) begin
        o_rs2_data = i_rd_data; // Forwarding từ WB về ID ngay trong chu kỳ này
      end else begin
        o_rs2_data = regs[i_rs2_addr];
      end
    end

endmodule