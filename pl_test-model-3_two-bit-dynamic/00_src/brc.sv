module brc (
    input  logic [31:0] i_rs1_data,
    input  logic [31:0] i_rs2_data,
    input  logic        i_br_un,    // 1 = unsigned, 0 = signed  <-- aligned with ctrl_unit
    output logic        o_br_less,
    output logic        o_br_equal
);
    function automatic [32:0] add32 (
        input logic [31:0] a,
        input logic [31:0] b,
        input logic        cin
    );
        logic [31:0] s; logic c; integer i;
        begin
            c = cin;
            for (i = 0; i < 32; i++) begin
                s[i] = a[i] ^ b[i] ^ c;
                c    = (a[i] & b[i]) | (a[i] & c) | (b[i] & c);
            end
            add32 = {c, s};
        end
    endfunction

    logic [32:0] sub_res;
    assign sub_res = add32(i_rs1_data, ~i_rs2_data, 1'b1);

    assign o_br_equal = ~ ( | (i_rs1_data ^ i_rs2_data) );

    wire less_u = ~sub_res[32];

    wire sign_a = i_rs1_data[31];
    wire sign_b = i_rs2_data[31];
    wire less_s = (sign_a ^ sign_b) ? sign_a : sub_res[31];

    always_comb begin
        // NOTE: now 1 = unsigned, 0 = signed
        o_br_less = i_br_un ? less_u : less_s;
    end
endmodule
