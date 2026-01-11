//==============================================================
// Load Store Unit - Sync Memory Version
// FIXED: Corrected Reset Polarity (!i_reset)
//==============================================================
module lsu(
  input  logic         i_clk,
  input  logic         i_reset,      // Active Low
  input  logic [31:0]  i_lsu_addr,
  input  logic [31:0]  i_st_data,
  input  logic         i_lsu_wren,
  output logic [31:0]  o_ld_data,

  output logic [31:0]  o_io_ledr,
  output logic [31:0]  o_io_ledg,
  output logic [ 6:0]  o_io_hex0, output logic [ 6:0]  o_io_hex1,
  output logic [ 6:0]  o_io_hex2, output logic [ 6:0]  o_io_hex3,
  output logic [ 6:0]  o_io_hex4, output logic [ 6:0]  o_io_hex5,
  output logic [ 6:0]  o_io_hex6, output logic [ 6:0]  o_io_hex7,
  output logic [31:0]  o_io_lcd,
  input  logic [31:0]  i_io_sw,
  input  logic [2:0]   i_funct3
);

  // ============================================================
  // 1. Address Decoding & Write Enable
  // ============================================================
  localparam [19:0] ADDR_LEDR   = 20'h10000;
  localparam [19:0] ADDR_LEDG   = 20'h10001;
  localparam [19:0] ADDR_HEX3_0 = 20'h10002;
  localparam [19:0] ADDR_HEX7_4 = 20'h10003;
  localparam [19:0] ADDR_LCD    = 20'h10004;
  localparam [19:0] ADDR_SW     = 20'h10010;

  wire [19:0] addr_hi   = i_lsu_addr[31:12];
  wire [1:0]  addr_lo   = i_lsu_addr[1:0];
  
  wire        is_ledr   = (addr_hi == ADDR_LEDR);
  wire        is_ledg   = (addr_hi == ADDR_LEDG);
  wire        is_hex3_0 = (addr_hi == ADDR_HEX3_0);
  wire        is_hex7_4 = (addr_hi == ADDR_HEX7_4);
  wire        is_lcd    = (addr_hi == ADDR_LCD);
  wire        is_sw     = (addr_hi == ADDR_SW);
  wire        is_ram    = (i_lsu_addr[31:16] == 16'h0000);

  wire        dmem_wren = i_lsu_wren & is_ram;

  // ============================================================
  // 2. Control Signal Pipeline (Delayed 1 Cycle)
  // ============================================================
  logic [2:0] funct3_r;
  logic [1:0] addr_lo_r;
  logic       is_sw_r, is_ledr_r, is_ledg_r, is_lcd_r;

  always_ff @(posedge i_clk) begin
    if (!i_reset) begin  // <--- FIXED: Active Low Reset
      funct3_r  <= 3'b0;
      addr_lo_r <= 2'b0;
      is_sw_r   <= 1'b0;
      is_ledr_r <= 1'b0;
      is_ledg_r <= 1'b0;
      is_lcd_r  <= 1'b0;
    end else begin
      funct3_r  <= i_funct3;
      addr_lo_r <= addr_lo;
      is_sw_r   <= is_sw;
      is_ledr_r <= is_ledr;
      is_ledg_r <= is_ledg;
      is_lcd_r  <= is_lcd;
    end
  end

  // ============================================================
  // 3. Memory Interface
  // ============================================================
  logic [3:0]  bmask;
  logic [31:0] wdata_aligned;
  logic [31:0] dmem_rdata_lo, dmem_rdata_hi;

  wire [15:0] mem_addr_lo = {i_lsu_addr[15:2], 2'b00};
  wire [15:0] mem_addr_hi = mem_addr_lo + 16'd4;

  always_comb begin
    case (i_funct3[1:0])
      2'b00: begin // SB
        bmask = 4'b0001 << addr_lo;
        wdata_aligned = {4{i_st_data[7:0]}};
      end
      2'b01: begin // SH
        bmask = addr_lo[1] ? 4'b1100 : 4'b0011;
        wdata_aligned = {2{i_st_data[15:0]}};
      end
      default: begin // SW
        bmask = 4'b1111;
        wdata_aligned = i_st_data;
      end
    endcase
  end

  memory #(.ADDR_W(16), .MEM_SIZE(65536)) datamem (
    .i_clk(i_clk), 
    .i_reset(i_reset),
    .i_addr(mem_addr_lo),
    .i_addr2(mem_addr_hi),
    .i_wdata(wdata_aligned),
    .i_bmask(bmask), 
    .i_wren(dmem_wren),
    .o_rdata(dmem_rdata_lo),
    .o_rdata2(dmem_rdata_hi)
  );

  // ============================================================
  // 4. I/O Write Logic
  // ============================================================
  function automatic [6:0] hex7seg(input logic [3:0] v);
    case (v)
      4'h0: hex7seg = 7'b1000000; 4'h1: hex7seg = 7'b1111001; 4'h2: hex7seg = 7'b0100100; 4'h3: hex7seg = 7'b0110000;
      4'h4: hex7seg = 7'b0011001; 4'h5: hex7seg = 7'b0010010; 4'h6: hex7seg = 7'b0000010; 4'h7: hex7seg = 7'b1111000;
      4'h8: hex7seg = 7'b0000000; 4'h9: hex7seg = 7'b0010000; 4'hA: hex7seg = 7'b0001000; 4'hB: hex7seg = 7'b0000011;
      4'hC: hex7seg = 7'b1000110; 4'hD: hex7seg = 7'b0100001; 4'hE: hex7seg = 7'b0000110; 4'hF: hex7seg = 7'b0001110;
      default: hex7seg = 7'b1111111;
    endcase
  endfunction

  always_ff @(posedge i_clk or negedge i_reset) begin
    if (!i_reset) begin
      o_io_ledr <= 32'b0; o_io_ledg <= 32'b0; o_io_lcd <= 32'b0;
      o_io_hex0 <= 7'b1111111; o_io_hex1 <= 7'b1111111; o_io_hex2 <= 7'b1111111; o_io_hex3 <= 7'b1111111;
      o_io_hex4 <= 7'b1111111; o_io_hex5 <= 7'b1111111; o_io_hex6 <= 7'b1111111; o_io_hex7 <= 7'b1111111;
    end else begin
      if (i_lsu_wren) begin
        if (is_ledr)        o_io_ledr <= i_st_data;
        else if (is_ledg)   o_io_ledg <= i_st_data;
        else if (is_hex3_0) begin
          o_io_hex0 <= hex7seg(i_st_data[3:0]);   o_io_hex1 <= hex7seg(i_st_data[7:4]);
          o_io_hex2 <= hex7seg(i_st_data[11:8]);  o_io_hex3 <= hex7seg(i_st_data[15:12]);
        end else if (is_hex7_4) begin
          o_io_hex4 <= hex7seg(i_st_data[3:0]);   o_io_hex5 <= hex7seg(i_st_data[7:4]);
          o_io_hex6 <= hex7seg(i_st_data[11:8]);  o_io_hex7 <= hex7seg(i_st_data[15:12]);
        end else if (is_lcd) o_io_lcd <= i_st_data;
      end
    end
  end

  // ============================================================
  // 5. Read Data Path (Delayed Signals)
  // ============================================================
  logic [31:0] misaligned_word;
  logic [31:0] ld_data_raw;
  logic [7:0]  ld_byte;
  logic [15:0] ld_half;

  always_comb begin
    case (addr_lo_r)
      2'b00: misaligned_word = dmem_rdata_lo;
      2'b01: misaligned_word = {dmem_rdata_hi[7:0],  dmem_rdata_lo[31:8]};
      2'b10: misaligned_word = {dmem_rdata_hi[15:0], dmem_rdata_lo[31:16]};
      2'b11: misaligned_word = {dmem_rdata_hi[23:0], dmem_rdata_lo[31:24]};
    endcase
  end

  always_comb begin
    if (is_sw_r)      ld_data_raw = i_io_sw;
    else if (is_ledr_r) ld_data_raw = o_io_ledr;
    else if (is_ledg_r) ld_data_raw = o_io_ledg;
    else if (is_lcd_r)  ld_data_raw = o_io_lcd;
    else              ld_data_raw = misaligned_word;
  end

  assign ld_byte = ld_data_raw[7:0];
  assign ld_half = ld_data_raw[15:0];

  always_comb begin
    case (funct3_r)
      3'b000: o_ld_data = {{24{ld_byte[7]}}, ld_byte};   // LB
      3'b001: o_ld_data = {{16{ld_half[15]}}, ld_half};  // LH
      3'b010: o_ld_data = ld_data_raw;                   // LW
      3'b100: o_ld_data = {24'b0, ld_byte};              // LBU
      3'b101: o_ld_data = {16'b0, ld_half};              // LHU
      default: o_ld_data = ld_data_raw;
    endcase
  end

endmodule
