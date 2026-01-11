module memory #(
  parameter int ADDR_W   = 16,
  parameter int MEM_SIZE = 65536 
)(
  input  logic              i_clk,
  input  logic              i_reset,
  input  logic [ADDR_W-1:0] i_addr,
  input  logic [ADDR_W-1:0] i_addr2,
  input  logic [31:0]       i_wdata,
  input  logic [3:0]        i_bmask,
  input  logic              i_wren,
  output logic [31:0]       o_rdata,
  output logic [31:0]       o_rdata2
);
  logic [7:0] mem_cell [0:MEM_SIZE-1];

  integer i;
  // Khối initial 
  initial begin
    for (i = 0; i < MEM_SIZE; i++) mem_cell[i] = 8'h00;
  end

  // Address calculation logic
  logic [ADDR_W-1:0] a0, a1, a2, a3;
  logic [ADDR_W-1:0] b0, b1, b2, b3;
  
  // Dây nối tạm cho kết quả 32-bit từ bộ cộng
  logic [31:0] a1_32, a2_32, a3_32;
  logic [31:0] b1_32, b2_32, b3_32;

  // --- PORT 1 ADDRESS CALCULATION ---
  assign a0 = i_addr;

  // a1 = i_addr + 1
  addsub32 u_add_a1 (
    .i_a    ( { {(32-ADDR_W){1'b0}}, i_addr } ), // Mở rộng i_addr lên 32-bit
    .i_b    ( 32'd1 ),
    .Cin    ( 1'b0 ), // 0: Add
    .Cout   (),
    .o_s    ( a1_32 )
  );
  assign a1 = a1_32[ADDR_W-1:0]; // Cắt lại về 16-bit

  // a2 = i_addr + 2
  addsub32 u_add_a2 (
    .i_a    ( { {(32-ADDR_W){1'b0}}, i_addr } ),
    .i_b    ( 32'd2 ),
    .Cin    ( 1'b0 ),
    .Cout   (),
    .o_s    ( a2_32 )
  );
  assign a2 = a2_32[ADDR_W-1:0];

  // a3 = i_addr + 3
  addsub32 u_add_a3 (
    .i_a    ( { {(32-ADDR_W){1'b0}}, i_addr } ),
    .i_b    ( 32'd3 ),
    .Cin    ( 1'b0 ),
    .Cout   (),
    .o_s    ( a3_32 )
  );
  assign a3 = a3_32[ADDR_W-1:0];


  // --- PORT 2 ADDRESS CALCULATION ---
  assign b0 = i_addr2;

  // b1 = i_addr2 + 1
  addsub32 u_add_b1 (
    .i_a    ( { {(32-ADDR_W){1'b0}}, i_addr2 } ),
    .i_b    ( 32'd1 ),
    .Cin    ( 1'b0 ),
    .Cout   (),
    .o_s    ( b1_32 )
  );
  assign b1 = b1_32[ADDR_W-1:0];

  // b2 = i_addr2 + 2
  addsub32 u_add_b2 (
    .i_a    ( { {(32-ADDR_W){1'b0}}, i_addr2 } ),
    .i_b    ( 32'd2 ),
    .Cin    ( 1'b0 ),
    .Cout   (),
    .o_s    ( b2_32 )
  );
  assign b2 = b2_32[ADDR_W-1:0];

  // b3 = i_addr2 + 3
  addsub32 u_add_b3 (
    .i_a    ( { {(32-ADDR_W){1'b0}}, i_addr2 } ),
    .i_b    ( 32'd3 ),
    .Cin    ( 1'b0 ),
    .Cout   (),
    .o_s    ( b3_32 )
  );
  assign b3 = b3_32[ADDR_W-1:0];


  // Synchronous Write & Read (Milestone 3 Requirement)
  always_ff @(posedge i_clk) begin
    // Write Port 1
    if (i_wren) begin
      // Sử dụng if riêng biệt thay vì logic shift
      if (i_bmask[0]) mem_cell[a0] <= i_wdata[7:0];
      if (i_bmask[1]) mem_cell[a1] <= i_wdata[15:8];
      if (i_bmask[2]) mem_cell[a2] <= i_wdata[23:16];
      if (i_bmask[3]) mem_cell[a3] <= i_wdata[31:24];
    end
    
    // Read Port 1 & 2 (Registered Output)
    o_rdata  <= {mem_cell[a3], mem_cell[a2], mem_cell[a1], mem_cell[a0]};
    o_rdata2 <= {mem_cell[b3], mem_cell[b2], mem_cell[b1], mem_cell[b0]};
  end

endmodule
