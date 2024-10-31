`timescale 1ns / 1ps

module lcd_sequence_tb();

    reg        r_clk,
               r_lcd_pwr,
               r_ram_din;
    
    wire       w_sclk,
               w_si,
               w_scs,
               w_extcomin,
               w_disp,
               w_vdda,
               w_vdd,
               w_extmode,
               w_vss,
               w_vssa,
               w_ram_en;
               
    wire [5:0] w_ram_addr;
    wire [3:0] w_lcd_state;

    lcd_sequencer UUT (.i_clk(r_clk),
                       .i_lcd_pwr(r_lcd_pwr),
                       .o_sclk(w_sclk),
                       .o_si(w_si),
                       .o_scs(w_scs),
                       .o_extcomin(w_extcomin),
                       .o_disp(w_disp),
                       .o_vdda(w_vdda),
                       .o_vdd(w_vdd),
                       .o_extmode(w_extmode),
                       .o_vss(w_vss),
                       .o_vssa(w_vssa),
                       .o_lcd_state(w_lcd_state),
                       .o_ram_en(w_ram_en),
                       .o_ram_addr(w_ram_addr),
                       .i_ram_din(r_ram_din));

    initial begin
        r_clk     <= 1'b0;
        forever begin
            #40 r_clk <= ~r_clk; // 12.5MHz clk
        end
    end
    
    initial begin
        r_lcd_pwr <= 1'b0;
        #8000
        r_lcd_pwr <= 1'b1;
        #200000000
        r_lcd_pwr <= 1'b0;
        #600000000
        r_lcd_pwr <= 1'b1;
        #100000000
        r_lcd_pwr <= 1'b0;
    end
    
endmodule
