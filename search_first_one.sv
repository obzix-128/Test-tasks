`timescale 1ns / 1ps

module search_first_one #(
    parameter int WIDTH = 8,
    parameter int R_WIDTH = $clog2(WIDTH + 1),
    parameter int DIR = 0
)(
    input  logic                clk_i,
    input  logic                resetn_i,
    input  logic [WIDTH-1:0]    data_bus_i,
    output logic [R_WIDTH-1:0]  result_index_o
);

    logic [R_WIDTH-1:0] next_index;

    always_comb 
    begin
        // Значение по умолчанию: единицы не найдены
        next_index = WIDTH[R_WIDTH-1:0]; 

        if (DIR == 0) 
        begin
            // Поиск от LSB к MSB.
            for (int i = WIDTH - 1; i >= 0; i--) 
            begin
                if (data_bus_i[i]) 
                begin
                    next_index = i[R_WIDTH-1:0];
                end
            end
        end 
        else 
        begin
            // Поиск от MSB к LSB.
            for (int i = 0; i < WIDTH; i++) 
            begin
                if (data_bus_i[i]) 
                begin
                    next_index = i[R_WIDTH-1:0];
                end
            end
        end
    end

    always_ff @(posedge clk_i) 
    begin
        if (!resetn_i) 
        begin
            result_index_o <= '0;
        end 
        else 
        begin
            result_index_o <= next_index;
        end
    end

endmodule
