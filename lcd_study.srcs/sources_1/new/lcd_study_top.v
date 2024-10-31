`timescale 1ns / 1ps

/*
TODO: RGB LED shall represent: LCD power on, LCD powering on, LCD powering off, LCD power off
      EXTCOMIN, DISP are bouncy -> capacitor study needed
      Voltage divider study -> can we limit voltages to 3.0V without affecting timings
*/

module lcd_study_top(
    // 12 MHz clock from cmodA7 board
    input  wire i_clk,
    // Pushbutton input to power on/off LCD
    input  wire i_lcd_pwr,
    // LCD interface
    output wire o_sclk,
    output wire o_si,
    output wire o_scs,
    output wire o_extcomin,
    output wire o_disp,
    output wire o_vdda,
    output wire o_vdd,
    output wire o_extmode,
    output wire o_vss,
    output wire o_vssa,
    // LED color => LCD state
    output wire o_led_r,
    output wire o_led_g,
    output wire o_led_b
);

    wire       w_pix_ram_en;
    wire [5:0] w_pix_ram_addr;
    wire       w_pix_ram_dout;
    wire       w_lcd_pwr;
    wire       w_btn;
    wire [3:0] w_lcd_state;

    // btn dbnc
    btn_dbnc dbnc0     (.i_clk(i_clk),
                        .i_bin(i_lcd_pwr),
                        .o_bout(w_btn));
                        
    blk_mem_gen_0 ram0 (.clka(i_clk),
                        .ena(1'b1),
                        .wea(1'b0),
                        .addra(w_pix_ram_addr),
                        .dina(1'b0),
                        .douta(w_pix_ram_dout));
    
    // LCD state machine
    lcd_sequencer lcd0 (.i_clk(i_clk),
                        .i_lcd_pwr(w_btn),
                        .o_sclk(o_sclk),
                        .o_si(o_si),
                        .o_scs(o_scs),
                        .o_extcomin(o_extcomin),
                        .o_disp(o_disp),
                        .o_vdda(o_vdda),
                        .o_vdd(o_vdd),
                        .o_extmode(o_extmode),
                        .o_vss(o_vss),
                        .o_vssa(o_vssa),
                        .o_lcd_state(w_lcd_state),
                        .o_ram_en(w_pix_ram_en),
                        .o_ram_addr(w_pix_ram_addr),
                        .i_ram_din(w_pix_ram_dout));

    assign o_led_r = 1'b1; // w_lcd_state[2];
    assign o_led_g = 1'b0; // ~w_lcd_state[2];
    assign o_led_b = 1'b1;
    
endmodule
