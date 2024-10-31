`timescale 1ns / 1ps

/*
LCD datasheet:
tsSI/thSI, setup time should be 227ns, hold time should be 525ns
CS must be high for at least 1842 clk12M cycs

Missing:
Create external PWM module for EXTCOMIN
Create external PWM module for CS
Create external module for SCK/SI
Squash state machine
parameterize row width
*/

module lcd_sequencer(
    // Global 12MHz clock
    input  wire       i_clk,
    // LCD Power btn
    input  wire       i_lcd_pwr,
    // LCD interface
    output wire       o_sclk,
    output wire       o_si,
    output wire       o_scs,
    output wire       o_extcomin,
    output wire       o_disp,
    output wire       o_vdda,
    output wire       o_vdd,
    output wire       o_extmode,
    output wire       o_vss,
    output wire       o_vssa,
    // LCD state, controls CmodA7 RGB LED
    output wire [3:0] o_lcd_state,
    // Pixel RAM
    output wire        o_ram_en,
    output wire [5:0]  o_ram_addr,
    input  wire        i_ram_din
);

    // Setup-states timings
    localparam  [3:0] p_rise_fall_cycs =  4'd11;   // 1us for 3V rise/fall (check with scope)
    localparam [10:0] p_com_init_cycs  = 11'd1199; // 100us for TCOM/VCOM init (at least 30us)
    
    // LCD serial interface frequency dividers
    localparam  [2:0] p_sclk_cycs      = 3'd5;  // Toggle SCLK every 500ns ( 6 clk12m cycs)
    localparam  [3:0] p_si_cycs        = 4'd11; // SI changes every 1us    (12 clk12m cycs)
    
    // State mod-counters
    reg  [3:0] r_rise_fall_cnt   =  4'b0; // rise/fall 3V
    reg [10:0] r_com_init_cnt    = 11'b0; // 30us for TCOM Latch/Polarity init
    
    // Counters to divide clk12m to generate LCD serial interface signals
    reg  [2:0] r_sclk_cnt        = 3'b0; // clk12m count for generating SCLK
    reg  [3:0] r_si_cnt          = 4'b0; // clk12m count for generating SI
    
    // Additional counts for LCD data transfering sequence timing
    reg [16:0] r_normal_idle_cnt = 18'b0; // normal idle clk12m cycs count
    reg  [2:0] r_mode_per_cnt    =  3'b0; // mode period width
    reg [18:0] r_extcomin_cnt    = 19'b0; // control EXTCOMIN frquency and pulse
    
    // CS control counter (need to meet setup/hold times and hit min high/low times)
    reg [19:0] r_cs_cnt          = 20'b0;
    
    // LCD serial interface signal enables
    reg        r_en_sclk         = 1'b0;
    reg        r_en_si           = 1'b0;
    reg        r_en_extcomin     = 1'b0;
    
    // LCD interface supply voltage
    // EXTMODE should be tied to VDD for external HW pulse mode
    reg        r_vdd             = 1'b0;
    reg        r_vdda            = 1'b0;
    reg        r_extmode         = 1'b0;
    
    // Set a flag when we are on the last clk12m cyc of final bit flag
    reg        r_last_cyc        = 1'b0;
    
    // Set a flag when we are on the last clk12m cyc of final bit flag
    reg        r_fetch_ram_flag  = 1'b0;
    
    // Current bit in serial data transfer period (down counter)
    reg  [6:0] r_curr_bit        = 7'b0;
    
    // Number of rows in LCD data update period
    reg  [6:0] r_row_cnt         = 7'b0;
    
    // Pixel row address
    reg  [7:0] r_lcd_row_addr    = 8'b0;
    
    // Register a power button event
    reg  [1:0] sr_pwr_event      = 1'b0; // Power button event detected
    reg        r_pwr_down_flag   = 1'b0; // LCD power down flag
    
    // Registered LCD serial interface signals (avoid glitches)
    reg        r_disp            = 1'b0; // registered display level
    reg        r_scs             = 1'b0; // registered chip select level
    reg        r_si              = 1'b0; // registered serial data level
    reg        r_sclk            = 1'b0; // registered serial clock level
    reg        r_extcomin        = 1'b0; // registered external com input level
    
    // Pixel RAM registered values
    reg        r_ram_en          = 1'b0;
    reg  [5:0] r_ram_addr        = 6'b0;
    
    // States
    localparam off          = 0, 
               risefall3v   = 1, // 3V rise/fall time
               pmem_init    = 2, // Pixel memory init
               com_init     = 3, // TCOM latch, TCOM polarity, VA, VB, VCOM init
               normal_idle  = 4, // Period between serial data transfer, CS is low, shift data into sr
               mode_per     = 5, //   8-bit LCD serial data transfer mode period
               addr_per     = 6, //   8-bit LCD pixel row addr period
               dummy_per    = 7, //   8-bit LCD serial data transfer of 0's
               data_wr_per  = 8, // 128-bit LCD pixel write data period
               transfer_per = 9; //  16-bit LCD internal pixel data update period
              
    reg [3:0] r_state = off;
    
    always@ (posedge i_clk) // or posedge i_lcd_pwr ?
        begin
            sr_pwr_event <= {sr_pwr_event[0], i_lcd_pwr};        
            if ((sr_pwr_event == 2'b10) && r_state)
                r_pwr_down_flag <= 1'b1;
            
            // TODO: Should we set counters to 0 up here ?
            
            // Drive EXTCOMIN pulse
            r_extcomin_cnt <= r_extcomin_cnt == 19'd399999 ? r_extcomin_cnt <= 1'b0 : r_extcomin_cnt + 1'b1;
            r_extcomin     <= (r_en_extcomin & (r_extcomin_cnt < 11'd1200));
            
            // LCD interface clock and data control
            if (r_en_sclk == 1'b1)
            begin
                r_sclk_cnt <= r_sclk_cnt + 1'b1;
                if (r_sclk_cnt == p_sclk_cycs)
                begin
                    r_sclk_cnt <= 1'b0;
                    r_sclk     <= ~r_sclk;
                end
            end
            else
            begin
                r_sclk_cnt <= 1'b0;
                r_sclk     <= 1'b0;
            end
            // Dividing clk12m for proper LCD interface SI width
            if (r_en_si == 1'b1)
            begin
                r_si_cnt         <= r_si_cnt + 1'b1;
                r_last_cyc       <= (r_si_cnt == 4'd10 && r_curr_bit == 1'b0) ? 1'b1 : 1'b0;
                r_fetch_ram_flag <= (r_si_cnt == 4'd8) ? 1'b1 : 1'b0;
                if (r_si_cnt == p_si_cycs)
                begin
                    r_curr_bit <= r_curr_bit - 1'b1;
                    r_si_cnt   <= 1'b0;
                end
            end
            else
                r_si_cnt <= 1'b0;
            
            // LCD state machine
            case (r_state)
                off :
                    begin
                        r_extcomin_cnt  <= 1'b0;
                        r_pwr_down_flag <= 1'b0;
                        r_state         <= sr_pwr_event == 2'b10 ? risefall3v : off;
                    end
                risefall3v :
                    begin
                        r_vdd           <= ~r_pwr_down_flag;
                        r_vdda          <= ~r_pwr_down_flag;
                        r_extmode       <= ~r_pwr_down_flag;
                        r_rise_fall_cnt <= r_rise_fall_cnt + 1'b1;
                        // Wait 1us for 3V rise time
                        if (r_rise_fall_cnt == p_rise_fall_cycs)
                        begin
                            r_rise_fall_cnt <= 4'b0;
                            r_state         <= r_pwr_down_flag ? off : pmem_init;
                        end
                    end
                pmem_init :
                    begin
                        r_scs    <= 1'b1;
                        r_cs_cnt <= r_cs_cnt + 1'b1;
                        r_si     <= r_curr_bit == 5'd21 ? 1'b1: 1'b0;
                        if (r_cs_cnt == 11'd1199) // 10us
                            r_en_sclk  <= 1'b1;
                        else if (r_cs_cnt == 11'd1200) // 1 cyc after 10us mark
                        begin
                            r_curr_bit <= 5'd23;
                            r_en_si    <= 1'b1;
                        end
                        if (r_last_cyc)
                        begin
                            r_en_si    <= 1'b0;
                            r_en_sclk  <= 1'b0;
                        end
                        if (r_cs_cnt == 11'd1999) // Meet min high width/SCS hold time
                        begin
                            r_cs_cnt   <= 1'b0;
                            r_scs      <= 1'b0;
                            r_state    <= com_init;
                        end
                    end
                com_init :
                    begin
                        // Set DISP high
                        // Wait for at least 30us for COM latch init
                        // We wait 100us to be safe
                        // If powering on, then start sending EXTCOMIN signal
                        // Wait for at least 30us
                        // We will wait 100us
                        r_disp         <= ~r_pwr_down_flag;
                        r_com_init_cnt <= r_com_init_cnt + 1'b1;
                        if (r_com_init_cnt == p_com_init_cycs)
                        begin
                            r_com_init_cnt <= 11'b0;
                            // can use any init extcomin cnt value that works,
                            // 393216 has a simple binary representation,
                            // as timing gets tighter we may need to change this
                            if (r_pwr_down_flag)
                                r_state        <= risefall3v;
                            else
                            begin
                                r_extcomin_cnt <= 19'd393216;
                                r_en_extcomin  <= 1'b1;
                                r_state        <= normal_idle;
                            end
                        end
                    end
                normal_idle :
                    begin
                        // Need to set CS low after a transfer (be sure to meet SCS hold time)
                        // Wait for at least twSCSL (6us)
                        // Wait for enough time between next transfer for EXTCOMIN pulse
                        // Check if we need to begin power down sequence
                        
                        r_normal_idle_cnt <= r_normal_idle_cnt + 1'b1;
                        if (r_normal_idle_cnt == 11'd1199)
                            r_scs <= 1'b0;
                        else if (r_pwr_down_flag & (r_normal_idle_cnt == 16'd48798))
                        begin
                            r_en_extcomin <= 1'b0;
                            r_state       <= pmem_init;
                        end
                        else if (r_normal_idle_cnt == 16'd48799)
                            r_scs <= 1'b1;
                        // Start outputing SCLK
                        else if (r_normal_idle_cnt == 17'd96126)
                            r_en_sclk  <= 1'b1;
                        else if (r_normal_idle_cnt == 17'd96127)
                        begin
                            r_normal_idle_cnt <= 1'b0;
                            r_curr_bit        <= 3'd7;
                            r_en_si           <= 1'b1;
                            r_state           <= mode_per;
                        end
                    end
                mode_per :
                    begin
                        // M0, M1, M2, 5xdummy
                        // For data update mode, the period should be precisely:
                        //     { 1, 0, 0, 0, 0, 0, 0, 0 }
                        // at end of period, set curr_bit to 3'b111
                        // move to addr period state
                        r_mode_per_cnt <= r_mode_per_cnt + 1'b1;
                        r_si           <= r_curr_bit == 3'd7 ? 1'b1: 1'b0;
                        if (r_last_cyc)
                        begin
                            r_mode_per_cnt <= 1'b0;
                            r_row_cnt      <= 1'b0;
                            r_curr_bit     <= 3'd7;
                            r_state        <= addr_per;
                        end
                    end
                addr_per :
                    begin
                        // 8-bit address
                        r_si <= r_lcd_row_addr[r_curr_bit];
                        if (r_last_cyc)
                        begin
                            r_lcd_row_addr <= (r_lcd_row_addr + 1'b1) & 7'b1111111;
                            r_curr_bit     <= 7'd127;
                            r_ram_en       <= 1'b1;
                            r_state        <= data_wr_per;
                        end
                    end
                dummy_per :
                    begin
                        r_si <= 1'b0;
                        if (r_last_cyc)
                        begin
                            r_curr_bit <= 3'd7;
                            r_state    <= addr_per;
                        end
                    end
                data_wr_per :
                    begin
                        // 128-bit LCD pixel row
                        // Move to dummy period for another pixel row update
                        // or move to transfer period if done updating.
                        // deassert RAM enable at end of period
                        if (r_fetch_ram_flag)
                            r_ram_addr  <= r_ram_addr + 1'b1;
                        r_si <= i_ram_din;
                        if (r_last_cyc)
                        begin
                            r_ram_en  <= 1'b0;
                            r_row_cnt <= r_row_cnt + 1'b1;
                            if (r_row_cnt == 6'd59)
                            begin
                                r_curr_bit <= 4'd15;
                                r_state    <= transfer_per;
                            end
                            else
                            begin
                                r_curr_bit <= 3'd7;
                                r_state    <= dummy_per;
                            end
                        end
                    end
                transfer_per :
                    begin
                        // 16-bit transfer at end of data update mode
                        r_si <= 1'b0;
                        if (r_last_cyc)
                        begin
                            r_en_si   <= 1'b0;
                            r_en_sclk <= 1'b0;
                            r_state   <= normal_idle;
                        end
                    end
            endcase
        end
        
    // LCD serial lines
    assign o_disp      = r_disp;
    assign o_scs       = r_scs;
    assign o_si        = r_si;
    assign o_sclk      = r_sclk;
    assign o_extcomin  = r_extcomin;
    
    // LCD power lines
    assign o_vdda      = r_vdda;    // 3.3V when LCD to be powered on
    assign o_vdd       = r_vdd;     // 3.3V when LCD to be powered on
    assign o_extmode   = r_extmode; // Tie to VDD (3.3V)
    assign o_vss       = 1'b0;      // GND
    assign o_vssa      = 1'b0;      // GND
    
    // internal LCD state
    assign o_lcd_state = r_state;
    
    // RAM inputs
    assign o_ram_en    = r_ram_en;
    assign o_ram_addr  = r_ram_addr;
    
endmodule
