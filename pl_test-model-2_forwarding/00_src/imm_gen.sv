module imm_gen(
  input  logic [31:0] i_instr,
  output logic [31:0] o_imm
);

  wire [2:0] funct3 = i_instr[14:12];
  wire [6:0] opcode = i_instr[6:0];

  always_comb begin
    case(opcode)
      7'b0010011: begin // I-type (Arithmetic)
        // Shift instructions: SLLI, SRLI, SRAI - chỉ lấy 5 bit shamt
        if (funct3 == 3'b001 || funct3 == 3'b101) begin
          o_imm = {27'd0, i_instr[24:20]};
        end else begin
          // Other I-type: sign-extend 12 bits
          o_imm = {{20{i_instr[31]}}, i_instr[31:20]};
        end
      end
      
      7'b0000011: begin // I-type (Load)
        o_imm = {{20{i_instr[31]}}, i_instr[31:20]};
      end
      
      7'b1100111: begin // I-type (JALR)
        o_imm = {{20{i_instr[31]}}, i_instr[31:20]};
      end
      
      7'b0100011: begin // S-type (Store)
        o_imm = {{20{i_instr[31]}}, i_instr[31:25], i_instr[11:7]};
      end
      
      7'b1100011: begin // B-type (Branch)
        o_imm = {{19{i_instr[31]}}, i_instr[31], i_instr[7], i_instr[30:25], i_instr[11:8], 1'b0};
      end
      
      7'b1101111: begin // J-type (JAL)
        o_imm = {{11{i_instr[31]}}, i_instr[31], i_instr[19:12], i_instr[20], i_instr[30:21], 1'b0};
      end
      
      7'b0110111: o_imm = {i_instr[31:12], 12'h0}; // U-Type (LUI)
      
      7'b0010111: o_imm = {i_instr[31:12], 12'h0}; // U-Type (AUIPC)
      
      default: o_imm = 32'h0;
    endcase
  end
endmodule
