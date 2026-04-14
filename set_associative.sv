`timescale 1ns / 1ps

module set_associative #(
    parameter int BLK_WIDTH     = 4,
    parameter int WAY_CNT       = 4,
    parameter int ADDR_WIDTH    = 32,
    parameter int SET_IDX_WIDTH = 4 
)(
    input  logic                     clk_i,
    input  logic                     resetn_i,
    input  logic [ADDR_WIDTH-1:0]    wr_addr_i,
    input  logic [ADDR_WIDTH-1:0]    read_addr_i,
    input  logic [WAY_CNT-1:0]       wr_en_i,
    input  logic                     read_en_i,
    input  logic [BLK_WIDTH*8-1:0]   data_i,
    
    output logic                     hit_miss_o,
    output logic [BLK_WIDTH*8-1:0]   data_o
);

    localparam int SET_CNT   = 1 << SET_IDX_WIDTH;
    localparam int TAG_WIDTH = ADDR_WIDTH - SET_IDX_WIDTH;
    localparam int DATA_W    = BLK_WIDTH * 8;

    logic [SET_IDX_WIDTH-1:0] wr_set, rd_set;
    logic [TAG_WIDTH-1:0]     wr_tag, rd_tag;

    // Декодирование адреса: разделение на индекс набора (младшие) и тег (старшие)
    assign wr_set = wr_addr_i[SET_IDX_WIDTH-1:0];
    assign wr_tag = wr_addr_i[ADDR_WIDTH-1:SET_IDX_WIDTH];
    assign rd_set = read_addr_i[SET_IDX_WIDTH-1:0];
    assign rd_tag = read_addr_i[ADDR_WIDTH-1:SET_IDX_WIDTH];

    logic                     rd_en_reg;
    logic [TAG_WIDTH-1:0]     rd_tag_reg;
    logic [WAY_CNT-1:0]       rd_val_read;
    logic [TAG_WIDTH-1:0]     rd_tag_read  [WAY_CNT];
    logic [DATA_W-1:0]        rd_data_read [WAY_CNT];

    generate
        // Имплементация независимых банков памяти для каждого пути (way) 
        // для обеспечения параллельного доступа при поиске
        for (genvar w = 0; w < WAY_CNT; w++) 
        begin : way_mem
            logic [TAG_WIDTH-1:0] tag_mem   [SET_CNT];
            logic [DATA_W-1:0]    data_mem  [SET_CNT];
            logic                 valid_mem [SET_CNT];

            initial for (int i = 0; i < SET_CNT; i++) valid_mem[i] = 0;

            always_ff @(posedge clk_i) 
            begin
                if (!resetn_i) 
                begin
                    // При сбросе очищаются только valid-биты, массивы данных не трогаем для экономии ресурсов
                    for (int i = 0; i < SET_CNT; i++) valid_mem[i] <= 0;
                end 
                else if (wr_en_i[w]) 
                begin
                    tag_mem[wr_set]   <= wr_tag;
                    data_mem[wr_set]  <= data_i;
                    valid_mem[wr_set] <= 1'b1;
                end
                
                rd_tag_read[w]  <= tag_mem[rd_set];
                rd_data_read[w] <= data_mem[rd_set];
                rd_val_read[w]  <= valid_mem[rd_set];
            end
        end
    endgenerate

    // Конвейеризация запроса на чтение (задержка 1 такт по ТЗ)
    always_ff @(posedge clk_i) 
    begin
        if (!resetn_i) rd_en_reg <= 1'b0;
        else 
        begin
            rd_en_reg  <= read_en_i;
            rd_tag_reg <= rd_tag;
        end
    end

    // Комбинаторная логика проверки попадания (Cache Hit)
    always_comb begin
        hit_miss_o = 1'b0;
        data_o     = '0;
        if (rd_en_reg) 
        begin
            // Параллельное сравнение тегов по всем путям выбранного набора
            for (int w = 0; w < WAY_CNT; w++) 
            begin
                if (rd_val_read[w] && (rd_tag_read[w] == rd_tag_reg)) 
                begin
                    hit_miss_o = 1'b1;
                    data_o     = rd_data_read[w];
                end
            end
        end
    end
endmodule
