`timescale 1ns / 1ps

module tb_rob;
    parameter int INFO_WIDTH = 16, DATA_WIDTH = 16, ID_WIDTH = 4, BUF_SIZE = 4;

    logic clk_i = 0, rst_i;
    logic [INFO_WIDTH-1:0] master_info_i; 
    logic master_vld_i;
    logic [DATA_WIDTH-1:0] master_data_o; 
    logic master_vld_o, buf_full_o;
    logic [INFO_WIDTH-1:0] slave_info_o; 
    logic slave_vld_o, slave_rdy_i;
    logic [ID_WIDTH-1:0] slave_id_o;
    logic [DATA_WIDTH-1:0] slave_data_i; 
    logic slave_vld_i; 
    logic [ID_WIDTH-1:0] slave_id_i;

    rob #(
    INFO_WIDTH, DATA_WIDTH, ID_WIDTH, BUF_SIZE
    ) dut (
        .clk_i(clk_i),
        .rst_i(rst_i),
        .master_info_i(master_info_i),
        .master_vld_i(master_vld_i),
        .master_data_o(master_data_o),
        .master_vld_o(master_vld_o),
        .buf_full_o(buf_full_o),
        .slave_info_o(slave_info_o),
        .slave_vld_o(slave_vld_o),
        .slave_rdy_i(slave_rdy_i),
        .slave_id_o(slave_id_o),
        .slave_data_i(slave_data_i),
        .slave_vld_i(slave_vld_i),
        .slave_id_i(slave_id_i)
    );

    initial forever #5 clk_i = ~clk_i;

    int retire_chk_cnt = 0;
    logic [DATA_WIDTH-1:0] exp_data [8];

    // Автоматический мониторинг in-order возврата данных
    always @(posedge clk_i) 
    begin
        if (master_vld_o) 
        begin
            if (master_data_o !== exp_data[retire_chk_cnt])
                $error("Mismatch! Got %h, Exp %h", master_data_o, exp_data[retire_chk_cnt]);
            retire_chk_cnt++;
        end
    end

    initial 
    begin        
        rst_i = 1; master_vld_i = 0; slave_rdy_i = 1; slave_vld_i = 0;
        repeat(2) @(negedge clk_i);
        rst_i = 0;

      $display("--- Test 1: Out-of-Order ---");
        for (int i = 0; i < 4; i++) 
        begin
            @(negedge clk_i);
            master_info_i = INFO_WIDTH'(16'hA000 + i);
            exp_data[i]    = DATA_WIDTH'(16'hB000 + i);
            master_vld_i = 1;
        end
        @(negedge clk_i); master_vld_i = 0;

        for (int i = 3; i >= 0; i--) 
        begin
            @(negedge clk_i);
            slave_vld_i = 1;
            slave_id_i  = ID_WIDTH'(i);
            slave_data_i = DATA_WIDTH'(16'hB000 + i);
        end
        @(negedge clk_i); slave_vld_i = 0;
        
        wait(retire_chk_cnt == 4);

      $display("--- Test 2: Conflict ---");
        @(negedge clk_i);
        master_info_i = 16'hDA7A; exp_data[4] = 16'h1111;
        master_vld_i = 1;
        @(negedge clk_i);
        master_vld_i = 0;
        
        wait(slave_vld_o);
        @(negedge clk_i);
        slave_vld_i = 1; slave_id_i = slave_id_o; slave_data_i = 16'h1111;
        @(negedge clk_i);
        slave_vld_i = 0;

        @(negedge clk_i);
        master_vld_i = 1; master_info_i = 16'hE000; exp_data[5] = 16'h2222;
        
        @(posedge clk_i);
        if (master_vld_o && master_vld_i) 
            $display("Conflict state detected: Alloc and Retire at the same time.");
        
        @(negedge clk_i);
        master_vld_i = 0;

        repeat(10) @(negedge clk_i);
        $display("Final check: retire_cnt = %0d", retire_chk_cnt);
       
      $display("--- Test 3: Overflow ---");
        retire_chk_cnt = 0;
        slave_rdy_i = 0; 
        
        for (int i = 0; i < BUF_SIZE + 2; i++) 
        begin
            master_info_i = INFO_WIDTH'(16'hF000 + i);
            exp_data[i]    = DATA_WIDTH'(16'hE000 + i);
            master_vld_i = 1;
            @(negedge clk_i);
        end
        master_vld_i = 0;

        if (buf_full_o !== 1'b1) 
            $display("WARNING: buf_full_o should be HIGH now");
        
        $display("Starting retirement of overflow test...");
        slave_rdy_i = 1;

        for (int i = 0; i < BUF_SIZE; i++) 
        begin
            while (!slave_vld_o) @(negedge clk_i); 
            
            slave_vld_i  = 1;
            slave_id_i   = slave_id_o;
            slave_data_i = DATA_WIDTH'(16'hE000 + slave_id_o);
            @(negedge clk_i);
            slave_vld_i  = 0;
        end

        // Ожидание полной выгрузки буфера (min = BUF_SIZE)
        repeat (BUF_SIZE + 2) @(negedge clk_i);

        if (retire_chk_cnt != BUF_SIZE) 
            $error("FAIL: Expected %0d retires, got %0d", BUF_SIZE, retire_chk_cnt);
        else 
            $display("PASS: Overflow test passed. %0d transactions processed.", retire_chk_cnt);

      $display("--- Test 4: Reset Recovery ---");
        @(negedge clk_i);
        master_vld_i = 1; master_info_i = 16'h1234;
        repeat(2) @(negedge clk_i);
        
        rst_i = 1;
        @(negedge clk_i);
        rst_i = 0;
        
        if (buf_full_o !== 0 || dut.occ_count !== 0) 
            $error("FAIL: Module did not reset internal counters!");
        else
            $display("PASS: Reset recovery successful");

        $display("--- All Tests Finished ---");
        $finish;
    end
endmodule