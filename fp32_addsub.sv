`timescale 1ns / 1ps

module fp32_addsub (
    input  logic        clk_i,
    input  logic        rst_i,
    input  logic        is_add_i,
    input  logic [31:0] a_i,
    input  logic [31:0] b_i,
    output logic [31:0] result_o,
    output logic        nv_o
);

    logic [31:0] next_result;
    logic        next_nv;

    typedef struct packed {
        logic        sign;
        logic [7:0]  exp;
        logic [22:0] mant;
    } fp32_t;

    fp32_t a, b;
    assign a = fp32_t'(a_i);
    assign b = fp32_t'(b_i);

    localparam logic [31:0] QNAN = 32'h7FC00000;
    localparam logic [31:0] MAX_POS = 32'h7F7FFFFF;
    localparam logic [31:0] MAX_NEG = 32'hFF7FFFFF;

    logic        a_is_inf;
    logic        b_is_inf;
    logic        a_is_nan;
    logic        b_is_nan;
    logic        a_hidden_bit;
    logic        b_hidden_bit;
    logic [23:0] a_mant_full;
    logic [23:0] b_mant_full;
    logic        eff_sub;
    logic        res_sign;
    
    logic [7:0]  a_exp_work;
    logic [7:0]  b_exp_work;
    logic [7:0]  exp_diff;
    logic [7:0]  res_exp;
    logic [23:0] a_m_aligned;
    logic [23:0] b_m_aligned;
    logic        swap;
    logic [24:0] mant_sum;
    logic [7:0]  final_exp;
    logic [22:0] final_mant;
    
    logic [7:0]  shift_left; 

    always_comb 
    begin
        next_result = '0;
        next_nv     = 1'b0;
        a_exp_work  = '0;
        b_exp_work  = '0;
        exp_diff    = '0;
        res_exp     = '0;
        a_m_aligned = '0;
        b_m_aligned = '0;
        swap        = 1'b0;
        mant_sum    = '0;
        final_exp   = '0;
        final_mant  = '0;
        shift_left  = '0;

        a_is_inf  = (a.exp == 8'hFF) && (a.mant == 0);
        b_is_inf  = (b.exp == 8'hFF) && (b.mant == 0);
        a_is_nan  = (a.exp == 8'hFF) && (a.mant != 0);
        b_is_nan  = (b.exp == 8'hFF) && (b.mant != 0);
        
        a_hidden_bit = (a.exp != 0);
        b_hidden_bit = (b.exp != 0);
        
        a_mant_full = {a_hidden_bit, a.mant};
        b_mant_full = {b_hidden_bit, b.mant};
        
        // Определение эффективной операции с учетом флага и знаков операндов
        eff_sub = a.sign ^ (b.sign ^ ~is_add_i);
        res_sign = a.sign; 

        if (a_is_nan || b_is_nan) 
        begin
            next_result = QNAN;
        end 
        else if (a_is_inf && b_is_inf && eff_sub) 
        begin
            // Исключение: вычитание бесконечностей одного знака
            next_result = QNAN;
            next_nv = 1'b1;
        end 
        else if (a_is_inf) 
        begin
            next_result = a_i;
        end 
        else if (b_is_inf) 
        begin
            next_result = { (b.sign ^ ~is_add_i), b.exp, b.mant };
        end 
        else 
        begin
            // Поддержка субнормальных чисел: сдвиг экспоненты для корректного выравнивания
            a_exp_work = (a.exp == 0) ? 8'd1 : a.exp;
            b_exp_work = (b.exp == 0) ? 8'd1 : b.exp;

            // Сравнение абсолютных значений для выравнивания мантисс
            if ({a_exp_work, a_mant_full} < {b_exp_work, b_mant_full}) 
            begin
                swap = 1'b1;
                exp_diff = 8'(b_exp_work - a_exp_work); 
                res_exp  = b_exp_work;
                res_sign = b.sign ^ ~is_add_i;
                a_m_aligned = a_mant_full >> exp_diff; 
                b_m_aligned = b_mant_full;
            end 
            else 
            begin
                exp_diff = 8'(a_exp_work - b_exp_work); 
                res_exp  = a_exp_work;
                a_m_aligned = a_mant_full;
                b_m_aligned = b_mant_full >> exp_diff;
            end

            if (eff_sub) 
            begin
                if (swap) mant_sum = b_m_aligned - a_m_aligned;
                else      mant_sum = a_m_aligned - b_m_aligned;
            end 
            else 
            begin
                mant_sum = a_m_aligned + b_m_aligned;
            end

            if (mant_sum == 0) 
            begin
                next_result = {(eff_sub ? 1'b0 : res_sign), 31'd0}; 
            end 
            else 
            begin
                final_exp = res_exp;
                
                // Нормализация результата
                if (mant_sum[24]) 
                begin 
                    // Переполнение мантиссы (+1 бит)
                    final_exp = 8'(res_exp + 1);
                    final_mant = mant_sum[23:1];
                end 
                else if (!mant_sum[23]) 
                begin 
                    // Катастрофическая потеря значимости: поиск новой ведущей единицы
                    for (int i = 22; i >= 0; i--) 
                    begin
                        if (mant_sum[i]) 
                        begin
                            shift_left = 8'(23 - i);
                            break;
                        end
                    end
                    
                    if (final_exp > shift_left) 
                    begin
                        final_exp = 8'(final_exp - shift_left);
                        final_mant = 23'(mant_sum << shift_left); 
                    end 
                    else 
                    begin
                        shift_left = 8'(final_exp - 1);
                        final_exp = '0; // Уход в субнормальные числа
                        final_mant = 23'(mant_sum << shift_left);
                    end
                end 
                else 
                begin 
                    final_mant = mant_sum[22:0];
                end

                // По ТЗ: при переполнении формата возвращается максимально возможное значение, а не Inf
                if (final_exp == 8'hFF) 
                begin
                    next_result = res_sign ? MAX_NEG : MAX_POS;
                end 
                else 
                begin
                    next_result = {res_sign, final_exp, final_mant};
                end
            end
        end
    end

    always_ff @(posedge clk_i or posedge rst_i) 
    begin
        if (rst_i) 
        begin
            result_o <= '0;
            nv_o     <= 1'b0;
        end 
        else 
        begin
            result_o <= next_result;
            nv_o     <= next_nv;
        end
    end

endmodule
