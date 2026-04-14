`timescale 1ns / 1ps

module tb_set_associative;
    parameter int BLK_WIDTH = 4, WAY_CNT = 4, ADDR_WIDTH = 32, SET_IDX_WIDTH = 4;

    logic clk_i = 0, resetn_i = 0;
    logic read_en_i = 0, hit_miss_o;
    logic [ADDR_WIDTH-1:0] wr_addr_i = 0, read_addr_i = 0;
    logic [WAY_CNT-1:0] wr_en_i = 0;
    logic [BLK_WIDTH*8-1:0] data_i = 0, data_o;

    set_associative #(
        .BLK_WIDTH(BLK_WIDTH), 
        .WAY_CNT(WAY_CNT), 
        .ADDR_WIDTH(ADDR_WIDTH), 
        .SET_IDX_WIDTH(SET_IDX_WIDTH)
    ) dut (
        .clk_i      (clk_i),
        .resetn_i   (resetn_i),
        .read_en_i  (read_en_i),
        .read_addr_i(read_addr_i),
        .wr_en_i    (wr_en_i),
        .wr_addr_i  (wr_addr_i),
        .data_i     (data_i),
        .hit_miss_o (hit_miss_o),
        .data_o     (data_o)
    );

    initial forever #5 clk_i = ~clk_i;

    // Автоматизированная проверка результатов 
    task check_result(input logic exp_hit, input [BLK_WIDTH*8-1:0] exp_data, input string msg);
        if (hit_miss_o !== exp_hit)
            $error("FAIL: %s | Hit Mismatch! Got %b, Exp %b", msg, hit_miss_o, exp_hit);
        else if (exp_hit && (data_o !== exp_data))
            $error("FAIL: %s | Data Mismatch! Got %h, Exp %h", msg, data_o, exp_data);
        else
            $display("PASS: %s", msg);
    endtask

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_set_associative);

        resetn_i = 0;
        repeat(3) @(negedge clk_i);
        resetn_i = 1;
        repeat(2) @(negedge clk_i);
        
        $display("--- Test 1: Read Empty (Miss) ---");
        // Проверка поведения при "холодном" старте 
        read_addr_i = 32'hAABB_CC05;
        read_en_i   = 1;
        @(negedge clk_i);
        read_en_i   = 0;
        check_result(1'b0, 32'h0, "Cold start read");

        $display("--- Test 2: Write & Read Hit ---");
        // Базовая проверка сквозной записи и чтения
        wr_addr_i = 32'hAABB_CC05;
        wr_en_i   = 4'b0001;
        data_i    = 32'hDEADBEEF;
        @(negedge clk_i);
        wr_en_i   = 0;
        
        read_addr_i = 32'hAABB_CC05;
        read_en_i   = 1;
        @(negedge clk_i);
        read_en_i   = 0;
        check_result(1'b1, 32'hDEADBEEF, "Read Way 0 after write");

        $display("--- Test 3: Associativity (Multiple Ways) ---");
        // Проверка отсутствия перезаписи между разными путями одного набора
        wr_addr_i = 32'h1122_3305;
        wr_en_i   = 4'b0010;
        data_i    = 32'hCAFEBABE;
        @(negedge clk_i);
        wr_en_i   = 0;

        read_addr_i = 32'h1122_3305;
        read_en_i   = 1;
        @(negedge clk_i);
        read_en_i   = 0;
        check_result(1'b1, 32'hCAFEBABE, "Read Way 1 hit");

        read_addr_i = 32'hAABB_CC05;
        read_en_i   = 1;
        @(negedge clk_i);
        read_en_i   = 0;
        check_result(1'b1, 32'hDEADBEEF, "Verify Way 0 still present");

        $display("--- Test 4: Tag Miss ---");
        // Имитация коллизии: совпадение индекса набора при разных тегах
        read_addr_i = 32'h9999_9905;
        read_en_i   = 1;
        @(negedge clk_i);
        read_en_i   = 0;
        check_result(1'b0, 32'h0, "Read with non-existent tag");

        $display("--- Test 5: Simultaneous Read and Write ---");
        // Убеждаемся в отсутствии структурных конфликтов портов
        wr_en_i     = 4'b0100;
        wr_addr_i   = 32'h5555_550A;
        data_i      = 32'h12345678;
        read_en_i   = 1;
        read_addr_i = 32'h1122_3305;
        @(negedge clk_i);
        wr_en_i     = 0;
        read_en_i   = 0;
        
        check_result(1'b1, 32'hCAFEBABE, "Simultaneous read check");
        
        read_addr_i = 32'h5555_550A;
        read_en_i   = 1;
        @(negedge clk_i);
        read_en_i   = 0;
        check_result(1'b1, 32'h12345678, "Check simultaneous write result");

        $display("--- Test 6: Reset Recovery ---");
        // Проверка корректной инвалидации кэша аппаратным сбросом
        @(negedge clk_i);
        resetn_i = 0;
        @(negedge clk_i);
        resetn_i = 1;
        
        read_addr_i = 32'hAABB_CC05;
        read_en_i   = 1;
        @(negedge clk_i);
        read_en_i   = 0;
        
        if (hit_miss_o !== 1'b0)
            $error("FAIL: Cache did not clear valid bits after reset!");
        else
            $display("PASS: Reset recovery successful");

        $display("--- All Tests Finished ---");
        $finish;
    end

endmodule