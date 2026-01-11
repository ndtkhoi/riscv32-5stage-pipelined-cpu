module memory #(
  parameter int ADDR_W   = 16,
  parameter int MEM_SIZE = (1 << ADDR_W)
)(
  input  logic              i_clk,
  input  logic              i_reset,
  input  logic [ADDR_W-1:0] i_addr,
  input  logic [ADDR_W-1:0] i_addr2,     // Second read port for misaligned access
  input  logic [31:0]       i_wdata,
  input  logic [3:0]        i_bmask,
  input  logic              i_wren,
  output logic [31:0]       o_rdata,
  output logic [31:0]       o_rdata2     // Second read output
);

  logic [7:0] mem_cell [0:MEM_SIZE-1];

  integer i;
  initial begin
    for (i = 0; i < MEM_SIZE; i++) mem_cell[i] = 8'h00;
  end

  // Address calculation for port 1
  logic [ADDR_W-1:0] a0, a1, a2, a3;
/* 
  always_comb begin
    a0 = i_addr;
    a1 = i_addr + 1;
    a2 = i_addr + 2;
    a3 = i_addr + 3;
  end */
  
  assign a0 = i_addr;
  
  addsub32 addsub_a1 ( // a1 = i_addr + 1;
		.i_a(i_addr),
		.i_b(15'd1),
		.Cin(1'b0),		//add
		.Cout(),
		.o_s(a1)
	);
	
	addsub32 addsub_a2 ( // a2 = i_addr + 2;
		.i_a(i_addr),
		.i_b(15'd2),
		.Cin(1'b0),		//add
		.Cout(),
		.o_s(a2)
	);
	
	addsub32 addsub_a3 ( // a3 = i_addr + 3;
		.i_a(i_addr),
		.i_b(15'd3),
		.Cin(1'b0),		//add
		.Cout(),
		.o_s(a3)
	);

  // Address calculation for port 2
  logic [ADDR_W-1:0] b0, b1, b2, b3;
/*
  always_comb begin
    b0 = i_addr2;
    b1 = i_addr2 + 1;
    b2 = i_addr2 + 2;
    b3 = i_addr2 + 3;
  end */
  
  assign b0 = i_addr2;
  
  addsub32 addsub_b1 ( // b1 = i_addr2 + 1;
		.i_a(i_addr2),
		.i_b(15'd1),
		.Cin(1'b0),		//add
		.Cout(),
		.o_s(b1)
	);
	
	addsub32 addsub_b2 ( // b2 = i_addr2 + 2;
		.i_a(i_addr2),
		.i_b(15'd2),
		.Cin(1'b0),		//add
		.Cout(),
		.o_s(b2)
	);
	
	addsub32 addsub_b3 ( // b3 = i_addr2 + 3;
		.i_a(i_addr2),
		.i_b(15'd3),
		.Cin(1'b0),		//add
		.Cout(),
		.o_s(b3)
	);

  // Synchronous write (port 1 only)
  always_ff @(posedge i_clk) begin
    if (i_wren) begin
      if (i_bmask[0]) mem_cell[a0] <= i_wdata[7:0];
      if (i_bmask[1]) mem_cell[a1] <= i_wdata[15:8];
      if (i_bmask[2]) mem_cell[a2] <= i_wdata[23:16];
      if (i_bmask[3]) mem_cell[a3] <= i_wdata[31:24];
    end
	 o_rdata  <= {mem_cell[a3], mem_cell[a2], mem_cell[a1], mem_cell[a0]};
    o_rdata2 <= {mem_cell[b3], mem_cell[b2], mem_cell[b1], mem_cell[b0]};
  end

  // Asynchronous read (dual port)
  always_comb begin
    //o_rdata  = {mem_cell[a3], mem_cell[a2], mem_cell[a1], mem_cell[a0]};
    //o_rdata2 = {mem_cell[b3], mem_cell[b2], mem_cell[b1], mem_cell[b0]};
  end		

endmodule
