`timescale 1ns / 1ps

module btn_dbnc_tb();

    reg  r_clk,
         r_bin;
        
    wire w_bout;
    
    btn_dbnc UUT (.i_clk(r_clk),
                  .i_bin(r_bin),
                  .o_bout(w_bout));
    
    initial begin
        r_clk <= 1'b0;
        forever begin
            #40 r_clk <= ~r_clk;
        end
    end
    
    initial begin
        r_bin <= 1'b0;
        #990
        r_bin <= 1'b1;
        #12000000
        r_bin <= 1'b0;
        #48000000
        r_bin <= 1'b1;
        #200000
        r_bin <= 1'b0;
        #120000
        r_bin <= 1'b1;
        #20000000
        r_bin <= 1'b0;
    end
    
endmodule
