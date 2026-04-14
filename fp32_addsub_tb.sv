`timescale 1ns / 1ps

module tb_fp32_addsub;

    logic        clk_i;
    logic        rst_i;
    logic        is_add_i;
    logic [31:0] a_i;
    logic [31:0] b_i;
    logic [31:0] result_o;
    logic        nv_o;

    fp32_addsub dut 
    (
        .clk_i    (clk_i),
        .rst_i    (rst_i),
        .is_add_i (is_add_i),
        .a_i      (a_i),
        .b_i      (b_i),
        .result_o (result_o),
        .nv_o     (nv_o)
    );

    initial 
    begin
        clk_i = 0;
        forever #5 clk_i = ~clk_i;
    end

    task run_test(input string name, input logic add, input [31:0] a, input [31:0] b, input [31:0] exp_res, input exp_nv);
        @(negedge clk_i); 
        is_add_i = add;
        a_i = a;
        b_i = b;
        
        @(negedge clk_i); 
        if (result_o !== exp_res || nv_o !== exp_nv) 
        begin
            $error("Test %s FAILED. Expected: res=%h, nv=%b. Got: res=%h, nv=%b", 
                   name, exp_res, exp_nv, result_o, nv_o);
        end 
        else 
        begin
            $display("Test %s PASSED.", name);
        end
    endtask

    initial 
    begin
        $dumpfile("dump.vcd"); $dumpvars;
        rst_i = 1;
        is_add_i = 0; a_i = 0; b_i = 0;
        
        @(negedge clk_i); 
        rst_i = 0; 

        // В примере из ТЗ, вероятно, была опечатка
        run_test("TZ Ex 1 (Sub 0)", 1'b0, 32'hff7fffff, 32'h00000000, 32'hff7fffff, 1'b0);
        
        // Исправлено ожидаемое значение на математически корректное 0xD770FDC0 (отрицательный результат)
        run_test("TZ Ex 2 (Normal Add)", 1'b1, 32'hd7627b5f, 32'hd5682615, 32'hD770FDC0, 1'b0);
        
        run_test("TZ Ex 3 (NaN - 0)",    1'b0, 32'h7fc00000, 32'h00000000, 32'h7fc00000, 1'b0);
        run_test("TZ Ex 4 (+Inf + -Inf)",1'b1, 32'h7f800000, 32'hff800000, 32'h7fc00000, 1'b1);

        run_test("Overflow Saturation", 1'b1, 32'h7F7FFFFF, 32'h7F7FFFFF, 32'h7F7FFFFF, 1'b0); 

        run_test("Catastrophic Cancellation", 1'b0, 32'h3F800002, 32'h3F800001, 32'h34000000, 1'b0);

        run_test("Massive Align Shift Out", 1'b1, 32'h4C000000, 32'h3F800000, 32'h4C000000, 1'b0);

        run_test("Subnormal + Subnormal", 1'b1, 32'h00000001, 32'h00000002, 32'h00000003, 1'b0);
        
        run_test("Subnormal to Normal", 1'b1, 32'h007FFFFF, 32'h00000001, 32'h00800000, 1'b0);

        run_test("-0 + -0 = -0", 1'b1, 32'h80000000, 32'h80000000, 32'h80000000, 1'b0);
        run_test("-0 - -0 = +0", 1'b0, 32'h80000000, 32'h80000000, 32'h00000000, 1'b0);

        run_test("+Inf + Normal = +Inf", 1'b1, 32'h7F800000, 32'h3F800000, 32'h7F800000, 1'b0);
        
        run_test("Normal + qNaN = qNaN", 1'b1, 32'h3F800000, 32'h7FC00000, 32'h7FC00000, 1'b0);
        
        $finish;
    end

endmodule