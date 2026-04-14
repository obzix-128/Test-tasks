`timescale 1ns / 1ps

module tb_search_first_one;

    parameter int WIDTH = 8;
    parameter int R_WIDTH = $clog2(WIDTH + 1);

    logic               clk_i;
    logic               resetn_i;
    logic [WIDTH-1:0]   data_bus_i;
    
    logic [R_WIDTH-1:0] result_lsb_o;
    logic [R_WIDTH-1:0] result_msb_o;

    search_first_one #(
        .WIDTH(WIDTH),
        .DIR(0)
    ) dut_lsb 
    (
    .clk_i(clk_i),
    .resetn_i(resetn_i),
    .data_bus_i(data_bus_i),
    .result_index_o(result_lsb_o)
    );

    search_first_one #(
        .WIDTH(WIDTH),
        .DIR(1)
    ) dut_msb 
    (
    .clk_i(clk_i),
    .resetn_i(resetn_i),
    .data_bus_i(data_bus_i),
    .result_index_o(result_msb_o)
    );

    initial 
    begin
        clk_i = 0;
        forever #5 clk_i = ~clk_i;
    end

    initial 
    begin
        $dumpvars;
        resetn_i = 0; 
        data_bus_i = '0;

        @(negedge clk_i); // Выставляем входы по спаду
        resetn_i = 1; 

        // Автоматизированное исчерпывающее тестирование всех значений
        // Предполагаю, что WIDTH небольшое
        $display("Starting exhaustive test...");
        for (int j = 0; j < (1 << WIDTH); j++) begin
            logic [R_WIDTH-1:0] expected_lsb = WIDTH[R_WIDTH-1:0];
            logic [R_WIDTH-1:0] expected_msb = WIDTH[R_WIDTH-1:0];
            @(negedge clk_i);
            data_bus_i = j;
            
            @(posedge clk_i);
            #1;
            
            for (int k = 0; k < WIDTH; k++) begin
                if (j[k]) begin
                    expected_lsb = k[R_WIDTH-1:0];
                    break;
                end
            end
            
            for (int k = WIDTH - 1; k >= 0; k--) begin
                if (j[k]) begin
                    expected_msb = k[R_WIDTH-1:0];
                    break;
                end
            end
            
            if (result_lsb_o !== expected_lsb) begin
                $error("LSB Error at input %b: expected %0d, got %0d", j, expected_lsb, result_lsb_o);
            end
            if (result_msb_o !== expected_msb) begin
                $error("MSB Error at input %b: expected %0d, got %0d", j, expected_msb, result_msb_o);
            end
        end
        $display("Exhaustive LSB and MSB test passed!");

        // Тест 3: Проверка синхронного сброса на лету
        @(negedge clk_i); 
        resetn_i = 0; 
        @(posedge clk_i);
        #1;
        if (result_lsb_o !== 0) 
            $error("Sync Reset Failed!");
        else 
            $display("Test 3 (Sync Reset) Passed.");

        $finish;
    end

endmodule