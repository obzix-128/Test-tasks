`timescale 1ns / 1ps

module crossbar #(
    parameter int INPORT_NUM  = 4,
    parameter int ADDR_W      = 3,
    parameter int DATA_W      = 8,
    parameter int OUTPORT_NUM = 6
)(
    input  logic [INPORT_NUM-1:0][ADDR_W-1:0] addrin_i,
    input  logic [INPORT_NUM-1:0][DATA_W-1:0] datain_i,
    input  logic [INPORT_NUM-1:0]             validin_i,
    
    output logic [OUTPORT_NUM-1:0][DATA_W-1:0] dataout_o
);

    always_comb 
    begin
        // Внешний цикл: строим логику для каждого выходного порта
        for (int o_idx = 0; o_idx < OUTPORT_NUM; o_idx++) 
        begin
            dataout_o[o_idx] = '0; // Дефолтное значение

            // Внутренний цикл: ищем, кто хочет писать в этот порт.
            // Идем от старших индексов к младшим, чтобы реализовать приоритет.
            for (int i_idx = INPORT_NUM - 1; i_idx >= 0; i_idx--) 
            begin
                if (validin_i[i_idx] && (addrin_i[i_idx] == ADDR_W'(o_idx))) 
                begin
                    dataout_o[o_idx] = datain_i[i_idx];
                    break; 
                end
            end
        end
    end

endmodule
