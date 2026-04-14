`timescale 1ns / 1ps

module rob #(
    parameter int INFO_WIDTH = 32,
    parameter int DATA_WIDTH = 32,
    parameter int ID_WIDTH   = 4,
    parameter int BUF_SIZE   = 8
)(
    input  logic                  clk_i,
    input  logic                  rst_i,
    input  logic [INFO_WIDTH-1:0] master_info_i,
    input  logic                  master_vld_i,
    output logic [DATA_WIDTH-1:0] master_data_o,
    output logic                  master_vld_o,
    output logic                  buf_full_o,
    output logic [INFO_WIDTH-1:0] slave_info_o,
    output logic                  slave_vld_o,
    output logic [ID_WIDTH-1:0]   slave_id_o,
    input  logic                  slave_rdy_i,
    input  logic [DATA_WIDTH-1:0] slave_data_i,
    input  logic                  slave_vld_i,
    input  logic [ID_WIDTH-1:0]   slave_id_i
);

    localparam int PTR_W = $clog2(BUF_SIZE);
    localparam int CTR_W = $clog2(BUF_SIZE) + 1; // Доп. бит для детекции полного буфера

    logic [INFO_WIDTH-1:0] info_mem [BUF_SIZE-1:0];
    logic [DATA_WIDTH-1:0] data_mem [BUF_SIZE-1:0];
    logic                  done_mem [BUF_SIZE-1:0];

    logic [PTR_W-1:0] alloc_ptr, issue_ptr, retire_ptr;
    logic [CTR_W-1:0] occ_count;
    logic [CTR_W-1:0] unissued_count;

    function automatic logic [PTR_W-1:0] next_ptr(logic [PTR_W-1:0] ptr);
        return (ptr == PTR_W'(BUF_SIZE - 1)) ? PTR_W'(0) : ptr + 1'b1;
    endfunction

    assign buf_full_o = (occ_count == CTR_W'(BUF_SIZE));
    
    wire alloc_en  = master_vld_i && !buf_full_o;
    wire retire_en = (occ_count != '0) && done_mem[retire_ptr];
    wire slave_hsk = slave_vld_o && slave_rdy_i;

    // Интерфейс Master (Alloc & Retire)
    always_ff @(posedge clk_i) 
    begin
        if (rst_i) 
        begin
            alloc_ptr     <= '0;
            retire_ptr    <= '0;
            occ_count     <= '0;
            master_vld_o  <= 1'b0;
            master_data_o <= '0;
            for (int i = 0; i < BUF_SIZE; i++) done_mem[i] <= 1'b0;
        end 
        else 
        begin
            // Разрешение коллизий счетчика заполненности
            if (alloc_en && !retire_en) 
                occ_count <= occ_count + 1'b1;
            else if (!alloc_en && retire_en) 
                occ_count <= occ_count - 1'b1;

            if (alloc_en) 
            begin
                info_mem[alloc_ptr] <= master_info_i;
                done_mem[alloc_ptr] <= 1'b0;
                alloc_ptr <= next_ptr(alloc_ptr);
            end

            // Сохранение ответов Slave (Out-of-Order). ID транзакции = адрес в памяти.
            if (slave_vld_i && (slave_id_i < ID_WIDTH'(BUF_SIZE))) 
            begin
                data_mem[slave_id_i[PTR_W-1:0]] <= slave_data_i;
                done_mem[slave_id_i[PTR_W-1:0]] <= 1'b1;
            end

            if (retire_en) 
            begin
                master_vld_o  <= 1'b1;
                master_data_o <= data_mem[retire_ptr];
                retire_ptr    <= next_ptr(retire_ptr);
            end else 
            begin
                master_vld_o  <= 1'b0;
            end
        end
    end

    // Интерфейс Slave (Issue)
    always_ff @(posedge clk_i) 
    begin
        if (rst_i) 
        begin
            slave_vld_o    <= 1'b0;
            issue_ptr      <= '0;
            unissued_count <= '0;
            slave_info_o   <= '0;
            slave_id_o     <= '0;
        end else 
        begin
            if (alloc_en && !slave_hsk)
                unissued_count <= unissued_count + 1'b1;
            else if (!alloc_en && slave_hsk)
                unissued_count <= unissued_count - 1'b1;

            if (slave_hsk || !slave_vld_o) 
            begin
                if (unissued_count > 0 || alloc_en) 
                begin
                    // Блокируем комбинаторную передачу в текущем такте для соблюдения задержки >= 1
                    if (unissued_count > 0) 
                    begin
                        slave_vld_o  <= 1'b1;
                        slave_info_o <= info_mem[issue_ptr];
                        slave_id_o   <= ID_WIDTH'(issue_ptr);
                        issue_ptr    <= next_ptr(issue_ptr);
                    end else 
                    begin
                        slave_vld_o  <= 1'b0;
                    end
                end else 
                begin
                    slave_vld_o  <= 1'b0;
                end
            end
        end
    end
endmodule

