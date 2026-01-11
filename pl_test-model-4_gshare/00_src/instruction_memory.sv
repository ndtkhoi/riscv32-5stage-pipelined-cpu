module instruction_memory #(
  parameter int ADDR_WIDTH = 16   // byte address width (64 KB @ 4B/word -> 16K words)
) (
	input  logic                   i_clk,
	input  logic                   i_reset,     // active-low ở hệ thống, nhưng RAM không reset nội dung
	input  logic [ADDR_WIDTH-1:0]  i_addr,      // byte address
	output logic [31:0]            o_rdata
);
  // ---------------- Memory array (word-addressed) ----------------
	localparam int DEPTH = (1 << ADDR_WIDTH) >> 2;  // bytes -> words (compile-time)
	logic [31:0] imem [0:DEPTH-1];

	initial $readmemh("./../02_test/isa_4b.hex", imem);
	
  // ---------------- Địa chỉ word (word-aligned) -----------------
	wire [ADDR_WIDTH-1:2] word_addr = i_addr[ADDR_WIDTH-1:2];

  // ---------------- Sync read + byte-enable write ---------------
	always_ff @(posedge i_clk) begin
		if (~i_reset) begin
			o_rdata <= 32'b0;
		end else begin
			// đọc đồng bộ
			o_rdata <= imem[word_addr];
		end
	end

endmodule
