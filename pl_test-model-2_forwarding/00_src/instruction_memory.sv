module instruction_memory #(
  parameter int ADDR_WIDTH = 16   // byte address width (64 KB @ 4B/word -> 16K words)
) (
  input  logic                   i_clk,
  input  logic                   i_reset,     // active-low ở hệ thống, nhưng RAM không reset nội dung
  input  logic [ADDR_WIDTH-1:0]  i_addr,      // byte address
  input  logic [31:0]            i_wdata,
  input  logic [3:0]             i_bmask,     // 1: enable byte write
  input  logic                   i_wren,      // 1: write, 0: read
  output logic [31:0]            o_rdata
);
  // ---------------- Memory array (word-addressed) ----------------
  localparam int DEPTH = (1 << ADDR_WIDTH) >> 2;  // bytes -> words (compile-time)
  logic [31:0] mem [0:DEPTH-1];

`ifndef MEM_INIT_FILE
  // default file nếu testbench không truyền plusarg MEM_INIT_FILE
  `define MEM_INIT_FILE "./../02_test/isa_4b.hex"
`endif

  // ---------------- Init từ file (dùng plusarg nếu có) ----------
  string mem_init_file;
  initial begin
    if (!$value$plusargs("MEM_INIT_FILE=%s", mem_init_file)) begin
      mem_init_file = `MEM_INIT_FILE;
    end
    $display("[instruction_memory] Loading %s", mem_init_file);
    $readmemh(mem_init_file, mem);
    
    // --- DEBUG CHECK ---
    if (mem[0] == 32'h0) begin
        $display("[ERROR] Memory[0] is 0! Readmemh failed or file is empty.");
        $display("[DEBUG] Looking for file at: %s", mem_init_file);
    end else begin
        $display("[SUCCESS] Memory[0] loaded: %h", mem[0]);
    end
    // -------------------
  end

  // ---------------- Địa chỉ word (word-aligned) -----------------
  wire [ADDR_WIDTH-1:2] word_addr = i_addr[ADDR_WIDTH-1:2];

  // ---------------- Sync read + byte-enable write ---------------
  always_ff @(posedge i_clk) begin
    if (~i_reset) begin
      o_rdata <= 32'b0;
    end else begin
      // đọc đồng bộ
      o_rdata <= mem[word_addr];

      // ghi đồng bộ (self-modifying code nếu cần)
      if (i_wren) begin
        if (i_bmask[0]) mem[word_addr][7:0]   <= i_wdata[7:0];
        if (i_bmask[1]) mem[word_addr][15:8]  <= i_wdata[15:8];
        if (i_bmask[2]) mem[word_addr][23:16] <= i_wdata[23:16];
        if (i_bmask[3]) mem[word_addr][31:24] <= i_wdata[31:24];
      end
    end
  end

endmodule
