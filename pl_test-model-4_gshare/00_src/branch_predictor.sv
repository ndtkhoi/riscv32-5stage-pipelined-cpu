//==================================================
// G-share Branch Predictor - by: Huynh Trung Kien
//==================================================
module branch_predictor (
    input  logic        i_clk,
    input  logic        i_reset_n,
	 //input  logic 			i_is_jal,

    // --- READ PORT (ID Stage) ---
    input  logic [31:0] i_pc_read,
    output logic        o_pred_taken,   // 1: predict taken

    // --- UPDATE PORT (EX Stage) ---
    input  logic        i_wen,          // update enable (branch)
    input  logic [31:0] i_pc_write,
    input  logic        i_actual_taken
);

    // fixed 10-bit index -> 1024-entry BHT
    // BHT entries: 2-bit saturating counters
    logic [1:0] bht [0:1023];
	 
	 logic [9:0] ghr;			// bảng gshare
	 logic [9:0] ghr_old;	// ghr cũ dùng cho write index
	 
	 initial	for (integer i = 0; i < 1024; i = i + 1) bht[i] <= 2'b01;	// khởi tạo

    // Indexing: drop low 2 PC bits, take bits [11:2] -> 10 bits
    wire [9:0] read_idx  = i_pc_read[11:2] ^ ghr;
    wire [9:0] write_idx = i_pc_write[11:2] ^ ghr;

    // Predict: MSB of counter = 1 => predict taken
    //	assign o_pred_taken = bht[read_idx][1];
	 
	
	assign o_pred_taken = bht[read_idx][1];
	
	
	logic [1:0] bht_inc;
	logic [1:0] bth_dec;
	
	addsub32 add_bht_inc ( // bht[write_idx] + 2'b01;
		.i_a(bht[write_idx]),
		.i_b(2'd1),
		.Cin(1'b0),		//add
		.Cout(),
		.o_s(bht_inc)
	);
	
	addsub32 sub_bht_dec ( // bht[write_idx] + 2'b01;
		.i_a(bht[write_idx]),
		.i_b(2'd1),
		.Cin(1'b1),		//sub
		.Cout(),
		.o_s(bth_dec)
	);


    // Sequential update / init
    // integer i;
    always_ff @(posedge i_clk) begin
        if (!i_reset_n) begin
				ghr <= 10'b0;
				ghr_old <= 10'b0;
            // init all entries to Weakly Not Taken = 2'b01
            for (integer i = 0; i < 1024; i = i + 1) begin
                bht[i] <= 2'b01;
            end
        end else if (i_wen) begin
				ghr_old <= ghr;	// ghr cũ dùng cho write index
				ghr <= { ghr[9:1], i_actual_taken };
            if (i_actual_taken) begin
                // actual taken: increment (saturate at 2'b11)
                if (bht[write_idx] != 2'b11)
                    bht[write_idx] <= bht_inc; // bht[write_idx] + 2'b01;
            end else begin
                // actual not taken: decrement (saturate at 2'b00)
                if (bht[write_idx] != 2'b00)
                    bht[write_idx] <= bth_dec; // bht[write_idx] - 2'b01;
            end
        end
    end

endmodule
