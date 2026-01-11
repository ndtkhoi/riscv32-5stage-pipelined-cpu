//==============================================================
// Load Store Unit  
// FIXED V9: Support misaligned word access
//==============================================================
module lsu(
  input  logic         i_clk,
  input  logic         i_reset,
  input  logic [31:0]  i_lsu_addr,
  input  logic [31:0]  i_st_data,
  input  logic         i_lsu_wren,
  output logic [31:0]  o_ld_data,

  output logic [31:0]  o_io_ledr,
  output logic [31:0]  o_io_ledg,
  output logic [ 6:0]  o_io_hex0,
  output logic [ 6:0]  o_io_hex1,
  output logic [ 6:0]  o_io_hex2,
  output logic [ 6:0]  o_io_hex3,
  output logic [ 6:0]  o_io_hex4,
  output logic [ 6:0]  o_io_hex5,
  output logic [ 6:0]  o_io_hex6,
  output logic [ 6:0]  o_io_hex7,
  output logic [31:0]  o_io_lcd,
  input  logic [31:0]  i_io_sw,
  input  logic [2:0]   i_funct3
);

  logic [31:0] dmem_rdata_lo, dmem_rdata_hi;
  logic [3:0]  bmask;
  logic [31:0] wdata_aligned;
  logic        dmem_wren; 

  localparam [19:0] ADDR_LEDR   = 20'h10000;
  localparam [19:0] ADDR_LEDG   = 20'h10001;
  localparam [19:0] ADDR_HEX3_0 = 20'h10002;
  localparam [19:0] ADDR_HEX7_4 = 20'h10003;
  localparam [19:0] ADDR_LCD    = 20'h10004;
  localparam [19:0] ADDR_SW     = 20'h10010;

  wire [19:0] addr_hi  = i_lsu_addr[31:12];
  wire [1:0]  addr_lo  = i_lsu_addr[1:0];
  wire        is_ledr  = (addr_hi == ADDR_LEDR);
  wire        is_ledg  = (addr_hi == ADDR_LEDG);
  wire        is_hex3_0= (addr_hi == ADDR_HEX3_0);
  wire        is_hex7_4= (addr_hi == ADDR_HEX7_4);
  wire        is_lcd   = (addr_hi == ADDR_LCD);
  wire        is_sw    = (addr_hi == ADDR_SW);
  wire        is_ram   = (i_lsu_addr[31:16] == 16'h0000);

  assign dmem_wren = i_lsu_wren & is_ram;

  // Word-aligned addresses for memory access
  wire [15:0] mem_addr_lo = {i_lsu_addr[15:2], 2'b00};       // Current word
  wire [15:0] mem_addr_hi = mem_addr_lo + 16'd4;             // Next word

  // ============================================================
  // Byte mask and data alignment for store
  // ============================================================
  always_comb begin
    case (i_funct3[1:0])
      2'b00: begin  // SB - Store Byte
        bmask = 4'b0001 << addr_lo;
        wdata_aligned = {4{i_st_data[7:0]}};
      end
      2'b01: begin  // SH - Store Half
        bmask = addr_lo[1] ? 4'b1100 : 4'b0011;
        wdata_aligned = {2{i_st_data[15:0]}};
      end
      2'b10: begin  // SW - Store Word
        bmask = 4'b1111;
        wdata_aligned = i_st_data;
      end
      default: begin
        bmask = 4'b0000;
        wdata_aligned = i_st_data;
      end
    endcase
  end

  // Dual-port memory for misaligned access support
  memory #(. ADDR_W(16), .MEM_SIZE(65536)) datamem (
    .i_clk(i_clk), .i_reset(i_reset),
    .i_addr(mem_addr_lo),
    .i_addr2(mem_addr_hi),
    .i_wdata(wdata_aligned),
    . i_bmask(bmask), .i_wren(dmem_wren),
    . o_rdata(dmem_rdata_lo),
    .o_rdata2(dmem_rdata_hi)
  );

  function automatic [6:0] hex7seg(input logic [3:0] v);
    case (v)
      4'h0: hex7seg = 7'b1000000; 4'h1: hex7seg = 7'b1111001; 4'h2: hex7seg = 7'b0100100; 4'h3: hex7seg = 7'b0110000;
      4'h4: hex7seg = 7'b0011001; 4'h5: hex7seg = 7'b0010010; 4'h6: hex7seg = 7'b0000010; 4'h7: hex7seg = 7'b1111000;
      4'h8: hex7seg = 7'b0000000; 4'h9: hex7seg = 7'b0010000; 4'hA: hex7seg = 7'b0001000; 4'hB: hex7seg = 7'b0000011;
      4'hC: hex7seg = 7'b1000110; 4'hD: hex7seg = 7'b0100001; 4'hE: hex7seg = 7'b0000110; 4'hF: hex7seg = 7'b0001110;
      default: hex7seg = 7'b1111111;
    endcase
  endfunction

  // I/O write logic
  always_ff @(posedge i_clk or negedge i_reset) begin
    if (~i_reset) begin
      o_io_ledr <= 32'b0; o_io_ledg <= 32'b0; o_io_lcd <= 32'b0;
      o_io_hex0 <= 7'b1111111; o_io_hex1 <= 7'b1111111; o_io_hex2 <= 7'b1111111; o_io_hex3 <= 7'b1111111;
      o_io_hex4 <= 7'b1111111; o_io_hex5 <= 7'b1111111; o_io_hex6 <= 7'b1111111; o_io_hex7 <= 7'b1111111;
    end else begin
      if (i_lsu_wren) begin
        if (is_ledr) o_io_ledr <= i_st_data;
        else if (is_ledg) o_io_ledg <= i_st_data;
        else if (is_hex3_0) begin
          o_io_hex0 <= hex7seg(i_st_data[3:0]); o_io_hex1 <= hex7seg(i_st_data[7:4]);
          o_io_hex2 <= hex7seg(i_st_data[11:8]); o_io_hex3 <= hex7seg(i_st_data[15:12]);
        end else if (is_hex7_4) begin
          o_io_hex4 <= hex7seg(i_st_data[3:0]); o_io_hex5 <= hex7seg(i_st_data[7:4]);
          o_io_hex6 <= hex7seg(i_st_data[11:8]); o_io_hex7 <= hex7seg(i_st_data[15:12]);
        end else if (is_lcd) o_io_lcd <= i_st_data;
      end
    end
  end

  // ============================================================
  // Store-to-Load Forwarding
  // ============================================================
  logic [31:0] prev_st_addr_r;
  logic [31:0] prev_st_data_r;
  logic        prev_st_valid_r;
  logic [3:0]  prev_st_bmask_r;
  
  always_ff @(posedge i_clk or negedge i_reset) begin
    if (~i_reset) begin
      prev_st_addr_r  <= 32'b0;
      prev_st_data_r  <= 32'b0;
      prev_st_valid_r <= 1'b0;
      prev_st_bmask_r <= 4'b0;
    end else begin
      prev_st_valid_r <= dmem_wren;
      prev_st_addr_r  <= i_lsu_addr;
      prev_st_data_r  <= wdata_aligned;
      prev_st_bmask_r <= bmask;
    end
  end

  // Check forwarding match for both words
  wire st_ld_fwd_match_lo = prev_st_valid_r && is_ram &&
                            (prev_st_addr_r[15:2] == i_lsu_addr[15:2]);
  wire st_ld_fwd_match_hi = prev_st_valid_r && is_ram &&
                            (prev_st_addr_r[15:2] == (i_lsu_addr[15:2] + 14'd1));

  // ============================================================
  // Load Data Path with Misaligned Support
  // ============================================================
  logic [31:0] ld_data_raw;
  logic [7:0]  ld_byte;
  logic [15:0] ld_half;
  
  // Merge previous store data with memory read for forwarding (low word)
  logic [31:0] merged_ram_data_lo;
  always_comb begin
    merged_ram_data_lo = dmem_rdata_lo;
    if (st_ld_fwd_match_lo) begin
      if (prev_st_bmask_r[0]) merged_ram_data_lo[7:0]   = prev_st_data_r[7:0];
      if (prev_st_bmask_r[1]) merged_ram_data_lo[15:8]  = prev_st_data_r[15:8];
      if (prev_st_bmask_r[2]) merged_ram_data_lo[23:16] = prev_st_data_r[23:16];
      if (prev_st_bmask_r[3]) merged_ram_data_lo[31:24] = prev_st_data_r[31:24];
    end
  end

  // Merge previous store data with memory read for forwarding (high word)
  logic [31:0] merged_ram_data_hi;
  always_comb begin
    merged_ram_data_hi = dmem_rdata_hi;
    if (st_ld_fwd_match_hi) begin
      if (prev_st_bmask_r[0]) merged_ram_data_hi[7:0]   = prev_st_data_r[7:0];
      if (prev_st_bmask_r[1]) merged_ram_data_hi[15:8]  = prev_st_data_r[15:8];
      if (prev_st_bmask_r[2]) merged_ram_data_hi[23:16] = prev_st_data_r[23:16];
      if (prev_st_bmask_r[3]) merged_ram_data_hi[31:24] = prev_st_data_r[31:24];
    end
  end

  // Combine two words for misaligned word access
  logic [31:0] misaligned_word;
  always_comb begin
    case (addr_lo)
      2'b00: misaligned_word = merged_ram_data_lo;
      2'b01: misaligned_word = {merged_ram_data_hi[7:0],  merged_ram_data_lo[31:8]};
      2'b10: misaligned_word = {merged_ram_data_hi[15:0], merged_ram_data_lo[31:16]};
      2'b11: misaligned_word = {merged_ram_data_hi[23:0], merged_ram_data_lo[31:24]};
    endcase
  end

  // Select data source
  always_comb begin
    if (is_sw)        ld_data_raw = i_io_sw;
    else if (is_ledr) ld_data_raw = o_io_ledr;
    else if (is_ledg) ld_data_raw = o_io_ledg;
    else if (is_lcd)  ld_data_raw = o_io_lcd;
    else              ld_data_raw = misaligned_word;
  end

  // Correct byte/half extraction for load
  always_comb begin
    // For LB/LBU/LH/LHU, extract from position 0 of misaligned_word
    // (misaligned_word already shifted the correct byte/half to position 0)
    ld_byte = ld_data_raw[7:0];
    ld_half = ld_data_raw[15:0];
    
    case (i_funct3)
      3'b000: o_ld_data = {{24{ld_byte[7]}}, ld_byte};   // LB
      3'b001: o_ld_data = {{16{ld_half[15]}}, ld_half};  // LH
      3'b010: o_ld_data = ld_data_raw;                   // LW
      3'b100: o_ld_data = {24'b0, ld_byte};              // LBU
      3'b101: o_ld_data = {16'b0, ld_half};              // LHU
      default: o_ld_data = ld_data_raw;
    endcase
  end

endmodule
