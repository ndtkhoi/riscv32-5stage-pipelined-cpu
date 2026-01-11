module scoreboard(
  input  logic         i_clk     ,
  input  logic         i_reset   ,
  input  logic [31:0]  i_io_sw   ,
  input  logic [31:0]  o_io_ledr ,
  input  logic [31:0]  o_io_ledg ,
  input  logic [ 6:0]  o_io_hex0 ,
  input  logic [ 6:0]  o_io_hex1 ,
  input  logic [ 6:0]  o_io_hex2 ,
  input  logic [ 6:0]  o_io_hex3 ,
  input  logic [ 6:0]  o_io_hex4 ,
  input  logic [ 6:0]  o_io_hex5 ,
  input  logic [ 6:0]  o_io_hex6 ,
  input  logic [ 6:0]  o_io_hex7 ,
  input  logic [31:0]  o_io_lcd  ,
  input  logic         o_ctrl    ,
  input  logic         o_mispred ,
  input  logic [31:0]  o_pc_debug,
  input  logic         o_insn_vld
);

  real num_cycle;
  real num_insn;
  real num_ctrl;
  real num_mispred;

  initial begin
    $display("\nPIPELINE - ISA tests\n");
  end

  always @(negedge i_clk) begin : counters
      if (! i_reset) begin
        num_cycle   <= '0;
        num_ctrl    <= '0;
        num_insn    <= '0;
        num_mispred <= '0;
      end
      else begin
        num_cycle   <=              num_cycle   + 1;
        num_ctrl    <= o_ctrl     ?  num_ctrl    + 1 : num_ctrl;
        num_insn    <= o_insn_vld ? num_insn    + 1 : num_insn;
        num_mispred <= o_mispred  ? num_mispred + 1 : num_mispred;
      end
  end

  // ============ DEBUG: Track test progress ============
  reg [7:0] last_char;
  reg [7:0] prev_char;
  integer char_count;
  initial begin
    last_char = 0;
    prev_char = 0;
    char_count = 0;
  end
  
  always @(negedge i_clk) begin
    if (i_reset && o_insn_vld && (o_pc_debug == 32'h18)) begin
      prev_char = last_char;
      last_char = o_io_ledr[7:0];
      char_count = char_count + 1;
      
      // Detect ERROR - print PC when 'E' appears after newline
      if (last_char == 8'h45 && (prev_char == 8'h0A || prev_char == 8'h0D || char_count < 3)) begin
        $display("\n[ERROR DETECTED] at instruction #%0d", char_count);
      end
    end
  end
  // ============ END DEBUG ============

  always @(negedge i_clk) begin : debug
      if (o_insn_vld && (o_pc_debug == 32'h18)) begin
          $write("%s", o_io_ledr[7:0]);
      end
  end

  always @(negedge i_clk) begin : result
      if (o_insn_vld && ((o_pc_debug == 32'h1c) || (o_pc_debug == 32'h20))) begin
        $display("\n=================== Result ===================");
        if (num_cycle != 0) $display("Total Clock Cycles Executed = %1.0f", num_cycle);
        else                $display("Total Clock Cycles Executed = N/A");

        if (num_insn  != 0) $display("Total Instructions Executed = %1.0f", num_insn);
        else                $display("Total Instructions Executed = N/A");

        if (num_cycle != 0) $display("Total Branch Instructions   = %1.0f", num_ctrl);
        else                $display("Total Branch Instructions   = N/A");

        if (num_cycle != 0) $display("Total Branch Mispredictions = %1.0f", num_mispred);
        else                $display("Total Branch Mispredictions = N/A");

        $display("\n----------------------------------------------");
        if (num_cycle != 0) $display("Instruction Per Cycle (IPC) = %1.2f", num_insn/num_cycle);
        else                $display("Instruction Per Cycle (IPC) = N/A");

        if (num_ctrl != 0)  $display("Branch Misprediction Rate   = %2.2f %%", num_mispred/num_ctrl * 100);
        else                $display("Branch Misprediction Rate   = N/A");

        $display("\nEND of ISA tests\n");
        $finish;
      end
  end

endmodule : scoreboard
