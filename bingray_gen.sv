`timescale 1ns / 1ps

module bingray_gen #(
    parameter WIDTH = 4
)(
    input  logic             clk_i,
    input  logic             rst_i,
    input  logic             is_binnary, // Орфография ТЗ сохранена
    input  logic [WIDTH-1:0] a_i,
    output logic [WIDTH-1:0] result_o
);

    logic [WIDTH-1:0] next_result;
    logic [WIDTH-1:0] gray_to_bin_val;

    always_comb 
    begin
        gray_to_bin_val[WIDTH-1] = a_i[WIDTH-1];
        for (int i = WIDTH-2; i >= 0; i--) 
        begin
            gray_to_bin_val[i] = gray_to_bin_val[i+1] ^ a_i[i];
        end
    end

    always_comb 
    begin
        if (is_binnary) 
        begin
            next_result = a_i ^ (a_i >> 1);
        end 
        else 
        begin
            next_result = gray_to_bin_val;
        end
    end

    always_ff @(posedge clk_i or posedge rst_i) 
    begin
        if (rst_i) 
        begin
            result_o <= '0;
        end 
        else 
        begin
            result_o <= next_result;
        end
    end

endmodule

