`timescale 1ns / 1ps

module blk_mem_tb();

    reg       r_clk;
    reg       r_en;
    reg       r_we;
    reg [5:0] r_addr;
    reg       r_din;
    
    wire      w_dout;
    
    blk_mem_gen_0 UUT (.clka( r_clk ),
                       .ena(  r_en  ),
                       .wea(  r_we  ),
                       .addra(r_addr),
                       .dina( r_din ),
                       .douta(w_dout));

    initial begin
        r_clk  <= 1'b0;
        forever begin
            #40 r_clk  <= ~r_clk;
        end
    end
    
    initial begin
        r_addr <= 6'b0;
        r_en   <= 1'b1;
        r_we   <= 1'b0;
        r_din  <= 1'b0;
        forever begin
            #80 r_addr <= r_addr + 1'b1;
        end
    end
    
endmodule
