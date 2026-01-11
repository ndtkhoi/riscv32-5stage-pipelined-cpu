module branch_predictor (
    input  logic        i_clk,
    input  logic        i_reset_n,

    // --- READ PORT (ID Stage) ---
    input  logic [31:0] i_pc_read,
    output logic        o_pred_taken,   // 1: predict taken

    // --- UPDATE PORT (EX Stage) ---
    input  logic        i_wen,          // update enable (branch)
    input  logic [31:0] i_pc_write,
    input  logic        i_actual_taken
);

    // BHT 1024 dòng, mỗi dòng 2 bit
    logic [1:0] bht [0:1023];

    // Indexing
    wire [9:0] read_idx  = i_pc_read[11:2];
    wire [9:0] write_idx = i_pc_write[11:2];

    // 1. Logic Dự đoán (READ)
    // MSB là bit quyết định: 1x -> Taken, 0x -> Not Taken
    assign o_pred_taken = bht[read_idx][1];

    // 2. Logic Cập nhật (WRITE) - Dùng FSM thay vì cộng trừ
    always_ff @(posedge i_clk) begin
        if (!i_reset_n) begin
            // Reset toàn bộ về Weakly Not Taken (01)
            for (int i = 0; i < 1024; i++) begin
                bht[i] <= 2'b01;
            end
        end else if (i_wen) begin
            // Xét giá trị hiện tại của entry cần update
            case (bht[write_idx])
                2'b00: begin // Strongly Not Taken
                    if (i_actual_taken) bht[write_idx] <= 2'b01; // Tăng lên Weakly Not Taken
                    else                bht[write_idx] <= 2'b00; // Giữ nguyên (Bão hòa)
                end

                2'b01: begin // Weakly Not Taken
                    if (i_actual_taken) bht[write_idx] <= 2'b10; // Tăng lên Weakly Taken
                    else                bht[write_idx] <= 2'b00; // Giảm về Strongly Not Taken
                end

                2'b10: begin // Weakly Taken
                    if (i_actual_taken) bht[write_idx] <= 2'b11; // Tăng lên Strongly Taken
                    else                bht[write_idx] <= 2'b01; // Giảm về Weakly Not Taken
                end

                2'b11: begin // Strongly Taken
                    if (i_actual_taken) bht[write_idx] <= 2'b11; // Giữ nguyên (Bão hòa)
                    else                bht[write_idx] <= 2'b10; // Giảm về Weakly Taken
                end
            endcase
        end
    end

endmodule
