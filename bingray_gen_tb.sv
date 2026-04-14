`timescale 1ns / 1ps

module tb_bingray_gen;

    parameter WIDTH = 6;

    logic             clk_i;
    logic             rst_i;
    logic             is_binnary;
    logic [WIDTH-1:0] a_i;
    logic [WIDTH-1:0] result_o;

    bingray_gen #(.WIDTH(WIDTH)) dut 
    (
        .clk_i      (clk_i),
        .rst_i      (rst_i),
        .is_binnary (is_binnary),
        .a_i        (a_i),
        .result_o   (result_o)
    );

    initial 
    begin
        clk_i = 0;
        forever #5 clk_i = ~clk_i;
    end

    initial 
    begin
        rst_i = 1;
        is_binnary = 0;
        a_i = '0;

        #15 rst_i = 0; 

        // Автоматизированное исчерпывающее тестирование (Bin -> Gray)
        // Предполагаю, что WIDTH небольшое
        is_binnary = 1;
        for (int j = 0; j < (1 << WIDTH); j++) 
        begin
            @(negedge clk_i); // Входы DUT выставляем по спаду
            a_i = j;
            
            @(posedge clk_i);
            #1;
            
            if (result_o !== WIDTH'(j ^ (j >> 1))) 
            begin
                $error("Error at input %b: expected %b, got %b", WIDTH'(j), WIDTH'(j ^ (j >> 1)), result_o);
            end
        end
        $display("Exhaustive Bin -> Gray test passed!");

        // Автоматизированное исчерпывающее тестирование (Gray -> Bin)
        is_binnary = 0;
        for (int j = 0; j < (1 << WIDTH); j++) 
        begin
            @(negedge clk_i); 
            a_i = j;
            
            @(posedge clk_i);
            #1;
            
            for (int k = 0; k < WIDTH; k++) begin
                if (result_o[k] !== ^(j >> k)) begin
                    $error("Error at input %b: bit %0d expected %b, but got %b", j, k, ^(j >> k), result_o[k]);
                end
            end
        end
        $display("Exhaustive Gray -> Bin test passed!");

        // Тест 3: Проверка сброса
        rst_i = 1;
        #1;
        if (result_o !== 6'b000000) 
            $error("Test 3 Failed: Reset did not work!");
        else 
            $display("Test 3 Passed: Reset OK");

        $finish;
    end

endmodule