//==============================================================
// Load Store Unit
// FINAL FIX: Combinational Write Enable & Pipelined Read
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

  logic [31:0] dmem_rdata;
  logic [3:0]  bmask;

  // FIX: dmem_wren phải là wire (combinational), không được là reg
  logic        dmem_wren;

  // ---------------- Address Decoding ----------------
  localparam [19:0] ADDR_LEDR   = 20'h10000;
  localparam [19:0] ADDR_LEDG   = 20'h10001;
  localparam [19:0] ADDR_HEX3_0 = 20'h10002;
  localparam [19:0] ADDR_HEX7_4 = 20'h10003;
  localparam [19:0] ADDR_LCD    = 20'h10004;
  localparam [19:0] ADDR_SW     = 20'h10010;

  wire [19:0] addr_hi  = i_lsu_addr[31:12];
  wire        is_ledr  = (addr_hi == ADDR_LEDR);
  wire        is_ledg  = (addr_hi == ADDR_LEDG);
  wire        is_hex3_0= (addr_hi == ADDR_HEX3_0);
  wire        is_hex7_4= (addr_hi == ADDR_HEX7_4);
  wire        is_lcd   = (addr_hi == ADDR_LCD);
  wire        is_sw    = (addr_hi == ADDR_SW);

  // *** FIX QUAN TRỌNG: vùng RAM 64 KiB: 0x0000_0000 – 0x0000_FFFF ***
  // Dùng 16 bit cao để decode RAM, không dùng addr_hi (20 bit)
  wire        is_ram   = (i_lsu_addr[31:16] == 16'h0000);

  // ---------------- RAM write enable (combinational) ----------------
  assign dmem_wren = i_lsu_wren & is_ram;

  // ---------------- Byte mask logic ----------------
  always_comb begin
    unique case (i_funct3)
      3'b000: bmask = 4'b0001; // SB
      3'b001: bmask = 4'b0011; // SH
      3'b010: bmask = 4'b1111; // SW
      default: bmask = 4'b0000;
    endcase
  end

  // ---------------- Data Memory (sync read & write) ----------------
  memory #(.ADDR_W(16), .MEM_SIZE(65536)) datamem (
    .i_clk   (i_clk),
    .i_reset (i_reset),
    .i_addr  (i_lsu_addr[15:0]),
    .i_wdata (i_st_data),
    .i_bmask (bmask),
    .i_wren  (dmem_wren),
    .o_rdata (dmem_rdata)
  );

  // ---------------- HEX Encoder ----------------
  function automatic [6:0] hex7seg(input logic [3:0] v);
    case (v)
      4'h0: hex7seg = 7'b1000000;
      4'h1: hex7seg = 7'b1111001;
      4'h2: hex7seg = 7'b0100100;
      4'h3: hex7seg = 7'b0110000;
      4'h4: hex7seg = 7'b0011001;
      4'h5: hex7seg = 7'b0010010;
      4'h6: hex7seg = 7'b0000010;
      4'h7: hex7seg = 7'b1111000;
      4'h8: hex7seg = 7'b0000000;
      4'h9: hex7seg = 7'b0010000;
      4'hA: hex7seg = 7'b0001000;
      4'hB: hex7seg = 7'b0000011;
      4'hC: hex7seg = 7'b1000110;
      4'hD: hex7seg = 7'b0100001;
      4'hE: hex7seg = 7'b0000110;
      4'hF: hex7seg = 7'b0001110;
      default: hex7seg = 7'b1111111;
    endcase
  endfunction

  // ---------------- IO Write Logic ----------------
  // Vẫn dùng always_ff vì IO là các thanh ghi output
  always_ff @(posedge i_clk or negedge i_reset) begin
    if (~i_reset) begin
      o_io_ledr <= 32'b0;
      o_io_ledg <= 32'b0;
      o_io_lcd  <= 32'b0;

      o_io_hex0 <= 7'b1111111;
      o_io_hex1 <= 7'b1111111;
      o_io_hex2 <= 7'b1111111;
      o_io_hex3 <= 7'b1111111;
      o_io_hex4 <= 7'b1111111;
      o_io_hex5 <= 7'b1111111;
      o_io_hex6 <= 7'b1111111;
      o_io_hex7 <= 7'b1111111;
    end else begin
      if (i_lsu_wren) begin
        if (is_ledr)       o_io_ledr <= i_st_data;
        else if (is_ledg)  o_io_ledg <= i_st_data;
        else if (is_hex3_0) begin
          o_io_hex0 <= hex7seg(i_st_data[3:0]);
          o_io_hex1 <= hex7seg(i_st_data[7:4]);
          o_io_hex2 <= hex7seg(i_st_data[11:8]);
          o_io_hex3 <= hex7seg(i_st_data[15:12]);
        end else if (is_hex7_4) begin
          o_io_hex4 <= hex7seg(i_st_data[3:0]);
          o_io_hex5 <= hex7seg(i_st_data[7:4]);
          o_io_hex6 <= hex7seg(i_st_data[11:8]);
          o_io_hex7 <= hex7seg(i_st_data[15:12]);
        end else if (is_lcd) begin
          o_io_lcd <= i_st_data;
        end
      end
    end
  end

  // ---------------- Read Path Pipeline (for sync mem) ----------------
  logic [2:0] funct3_r;
  logic       is_sw_r, is_ledr_r, is_ledg_r, is_lcd_r;

  always_ff @(posedge i_clk or negedge i_reset) begin
    if (!i_reset) begin
      funct3_r  <= 3'b000;
      is_sw_r   <= 1'b0;
      is_ledr_r <= 1'b0;
      is_ledg_r <= 1'b0;
      is_lcd_r  <= 1'b0;
    end else begin
      funct3_r  <= i_funct3;
      is_sw_r   <= is_sw;
      is_ledr_r <= is_ledr;
      is_ledg_r <= is_ledg;
      is_lcd_r  <= is_lcd;
    end
  end

  // ---------------- Load Data Mux & Sign/Zero Extend ----------------
  logic [31:0] ld_data_raw;

  always_comb begin
    if (is_sw_r)        ld_data_raw = i_io_sw;
    else if (is_ledr_r) ld_data_raw = o_io_ledr;
    else if (is_ledg_r) ld_data_raw = o_io_ledg;
    else if (is_lcd_r)  ld_data_raw = o_io_lcd;
    else                ld_data_raw = dmem_rdata;

    unique case (funct3_r)
      3'b000: o_ld_data = {{24{ld_data_raw[7]}},  ld_data_raw[7:0]};   // LB
      3'b001: o_ld_data = {{16{ld_data_raw[15]}}, ld_data_raw[15:0]};  // LH
      3'b010: o_ld_data = ld_data_raw;                                 // LW
      3'b100: o_ld_data = {24'b0, ld_data_raw[7:0]};                   // LBU
      3'b101: o_ld_data = {16'b0, ld_data_raw[15:0]};                  // LHU
      default: o_ld_data = 32'b0;
    endcase
  end

endmodule
