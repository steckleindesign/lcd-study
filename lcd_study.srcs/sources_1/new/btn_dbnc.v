`timescale 1ns / 1ps

module btn_dbnc
#( parameter [16:0] p_DBNC_CYCS = 17'd120000 )
(
    // Global 12MHz clock
    input  wire i_clk,
    input  wire i_bin,
    output wire o_bout
);

    reg [16:0] cnt        = 17'b0;
    reg        curr_state =  1'b0;
    
    always @ (posedge i_clk)
    begin
        cnt <= 1'b0;
        if (i_bin != curr_state)
        begin
            if (cnt == p_DBNC_CYCS)
            begin
                curr_state <= i_bin;
            end
            else
            begin
                cnt <= cnt + 1'b1;
            end
        end
    end
    
    assign o_bout = curr_state;

endmodule
