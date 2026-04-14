`timescale 1ns / 1ps

module tb_crossbar;

    parameter int INPORT_NUM  = 4;
    parameter int ADDR_W      = 3;
    parameter int DATA_W      = 8;
    parameter int OUTPORT_NUM = 6;

    logic [INPORT_NUM-1:0][ADDR_W-1:0]         addrin_i;
    logic [INPORT_NUM-1:0][DATA_W-1:0]         datain_i;
    logic [INPORT_NUM-1:0]                     validin_i;
    logic [OUTPORT_NUM-1:0][DATA_W-1:0]        dataout_o;

    crossbar #(
        .INPORT_NUM(INPORT_NUM),
        .ADDR_W(ADDR_W),
        .DATA_W(DATA_W),
        .OUTPORT_NUM(OUTPORT_NUM)
    ) dut (
        .addrin_i(addrin_i),
        .datain_i(datain_i),
        .validin_i(validin_i),
        .dataout_o(dataout_o)
    );

    // Вспомогательная функция для сброса входов
    task clear_inputs();
        addrin_i  = '0;
        datain_i  = '0;
        validin_i = '0;
    endtask

    initial 
    begin
        $display("--- Starting Crossbar Tests ---");
        
        // Тест 1: Разрешение конфликтов (Все пишут в 5-й выход)
        clear_inputs();
        for (int i = 0; i < INPORT_NUM; i++) 
        begin
            validin_i[i] = 1'b1;
            addrin_i[i]  = 3'd5;
            datain_i[i]  = 8'hA0 + DATA_W'(i); 
        end
        #10; 
        if (dataout_o[5] !== 8'hA3) 
            $error("Test 1 Failed: Priority error! Got %h", dataout_o[5]);
        else 
            $display("Test 1 Passed: Priority to highest index (Port 3 wins).");

        // Тест 2: Разрешение конфликтов (Порт 1 и Порт 3 пишут в Выход 2)
        clear_inputs();
        validin_i[1] = 1'b1; addrin_i[1] = 3'd2; datain_i[1] = 8'h11;
        validin_i[3] = 1'b1; addrin_i[3] = 3'd2; datain_i[3] = 8'h33;
        #10;
        if (dataout_o[2] !== 8'h33) 
            $error("Test 2 Failed: Expected 0x33 on out[2]");
        else 
            $display("Test 2 Passed: Partial conflict resolved.");

        // Тест 3: Отсутствие конфликтов
        clear_inputs();
        validin_i[0] = 1'b1; addrin_i[0] = 3'd5; datain_i[0] = 8'h55;
        validin_i[1] = 1'b1; addrin_i[1] = 3'd0; datain_i[1] = 8'h00;
        validin_i[2] = 1'b1; addrin_i[2] = 3'd3; datain_i[2] = 8'h33;
        #10;
        if (dataout_o[5] !== 8'h55 || dataout_o[0] !== 8'h00 || dataout_o[3] !== 8'h33) 
            $error("Test 3 Failed: Normal routing error!");
        else 
            $display("Test 3 Passed: Non-conflicting routing works.");

        // Тест 4: Защита от несуществующего адреса 
        clear_inputs();
        validin_i[1] = 1'b1; addrin_i[1] = 3'b111; datain_i[1] = 8'hFF;
        #10;
        if (dataout_o !== '0) 
            $error("Test 4 Failed: Out of bounds address leaked!");
        else 
            $display("Test 4 Passed: Out-of-bounds address ignored.");

        // Тест 5: Крайний случай - нет активных validin 
        clear_inputs();
        validin_i = '0; 
        for (int i = 0; i < INPORT_NUM; i++) 
        begin
            addrin_i[i] = i[ADDR_W-1:0]; 
            datain_i[i] = 8'hFF; // Пытаемся передать данные без valid
        end
        #10;
        if (dataout_o !== '0) 
            $error("Test 5 Failed: Outputs should be zero when no inputs are valid!");
        else 
            $display("Test 5 Passed: No active valid inputs.");

        // Тест 6: Крайний случай - конфликт на адресах вне диапазона
        clear_inputs();
        for (int i = 0; i < INPORT_NUM; i++) 
        begin
            validin_i[i] = 1'b1;
            addrin_i[i]  = (i % 2 == 0) ? 3'd6 : 3'd7; 
            datain_i[i]  = 8'hC0 + DATA_W'(i);
        end
        #10;
        if (dataout_o !== '0) 
            $error("Test 6 Failed: Outputs should be zero for out-of-bounds addresses!");
        else 
            $display("Test 6 Passed: Mass out-of-bounds addresses ignored.");

        $display("--- All Tests Finished ---");
        $finish;
    end

endmodule