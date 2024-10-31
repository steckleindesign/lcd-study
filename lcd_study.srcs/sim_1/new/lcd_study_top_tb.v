`timescale 1ns / 1ps

module lcd_study_top_tb();

    reg        r_clk,
               r_lcd_pwr;
    
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
               w_led_r,
               w_led_g,
               w_led_b;

    lcd_study_top UUT (.i_clk(r_clk),
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
                       .o_led_r(w_led_r),
                       .o_led_g(w_led_g),
                       .o_led_b(w_led_b));

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
        #1000000000
        r_lcd_pwr <= 1'b0;
    end
    
endmodule
