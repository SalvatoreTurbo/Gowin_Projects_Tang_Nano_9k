// ============================================================================
// MODULE: ov5640_sccb_init
// DESCRIPTION: Configures all the internal OV5640 registers through the SCCB interface.
//
// Each configuration entry contains:
//   [23:8] = 16-bit OV5640 register address
//   [7:0]  = 8-bit register value
//
// Special register addresses used by this module:
//   16'hFFFE = delay 10 ms
//   16'hFFFF = end of configuration
//
// The actual SCCB transaction is performed by sccb_write_master.
// ============================================================================

module ov5640_sccb_init #(
    parameter int CLK_HZ  = 27_000_000,
    parameter int SCCB_HZ = 100_000   //SCCB communication frequency
)(
    input  logic clk,
    input  logic rst_n,
    input  logic start,

    inout  wire scl,
    inout  wire sda,

    output logic done,   //1 when the configuration is completed
    output logic error
);

    // OV5640 7-bit SCCB address.
    localparam logic [6:0] OV5640_ADDR = 7'h3C;

    // Number of addressed entries in the configuration ROM.
    localparam int ROM_ADDR_BITS = 8;

    // =========================================================================
    // Register ROM interface
    // =========================================================================

    logic [ROM_ADDR_BITS-1:0] rom_index;  //Current configuration index

    logic [15:0] current_reg_addr;
    logic [7:0]  current_reg_data;
    logic [23:0] rom_entry;               //[23:8] = register address, 16 bit + [7:0]  = data, 8 bit

    assign current_reg_addr = rom_entry[23:8];
    assign current_reg_data = rom_entry[7:0];

    // =========================================================================
    // SCCB master interface
    // =========================================================================
    //ov5640_controller decide quando inizializzare;
    //ov5640_sccb_init decide quali registri scrivere e in quale ordine;
    //sccb_write_master genera fisicamente la comunicazione su SCL e SDA.

    logic sccb_start;
    logic sccb_busy;
    logic sccb_done;
    logic sccb_ack_error;

    sccb_write_master #(
        .CLK_HZ     (CLK_HZ),
        .SCCB_HZ    (SCCB_HZ),
        .DEVICE_ADDR(OV5640_ADDR)
    ) sccb_master_inst (
        .clk      (clk),
        .rst_n    (rst_n),

        .start    (sccb_start),        //1 when a new SCCB communication should start
        .reg_addr (current_reg_addr),
        .reg_data (current_reg_data),

        .busy     (sccb_busy),         //1: Transmission in progress, busy: 0: master free
        .done     (sccb_done),         //1 when the transmission is completed
        .ack_error(sccb_ack_error),    //1 if camera did not respond correctly with an ACK

        .scl      (scl),
        .sda      (sda)
    );

    // =========================================================================
    // Fixed initialization delay
    // Every ROM entry with address 16'hFFFE introduces a fixed 10 ms delay.
    // =========================================================================

    localparam int DELAY_MS = 10;   //fixed ms to wait
    localparam int DELAY_CYCLES = (CLK_HZ / 1000) * DELAY_MS;  //num of clk cycle to wait DELAY_MS time
    localparam int DELAY_CNT_BITS = $clog2(DELAY_CYCLES + 1);

    logic [DELAY_CNT_BITS-1:0] delay_counter;           //Count the number of cycles spent in the INIT_DELAY state

    // =========================================================================
    // FSM
    // =========================================================================

    typedef enum logic [2:0] {
        INIT_IDLE,
        INIT_LOAD,
        INIT_START_WRITE,
        INIT_WAIT_WRITE,
        INIT_DELAY,
        INIT_DONE,
        INIT_ERROR
    } init_state_t;

    init_state_t state;
    
    //Finite State Machine Sequence
    //
    //INIT_IDLE
    //    ↓ start
    //INIT_LOAD
    //    ↓ registro normale
    //INIT_START_WRITE
    //    ↓
    //INIT_WAIT_WRITE
    //    ↓ scrittura completata
    //INIT_LOAD
    //    ↓
    //...
    //    ↓ marker finale
    //INIT_DONE

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= INIT_IDLE;
            rom_index     <= '0;
            sccb_start    <= 1'b0;
            delay_counter <= '0;

            done          <= 1'b0;
            error         <= 1'b0;
        end
        else begin
            sccb_start <= 1'b0;

            case (state)

                // -------------------------------------------------------------
                // Wait for one start pulse from ov5640_controller.
                // -------------------------------------------------------------

                INIT_IDLE: begin 
                    done      <= 1'b0;
                    error     <= 1'b0;
                    rom_index <= '0;

                    if (start)
                        state <= INIT_LOAD;
                end

                // -------------------------------------------------------------
                // Interpret current ROM entry.
                // -------------------------------------------------------------

                INIT_LOAD: begin
                    if (current_reg_addr == 16'hFFFF) begin
                        state <= INIT_DONE;
                    end
                    else if (current_reg_addr == 16'hFFFE) begin
                        delay_counter <= '0;
                        state         <= INIT_DELAY;
                    end
                    else begin
                        state <= INIT_START_WRITE;
                    end
                end

                // -------------------------------------------------------------
                // Produce a one-clock start pulse for the SCCB master.
                // -------------------------------------------------------------

                INIT_START_WRITE: begin
                    if (!sccb_busy) begin
                        sccb_start <= 1'b1;
                        state      <= INIT_WAIT_WRITE;
                    end
                end

                // -------------------------------------------------------------
                // Wait for completion of the register write.
                // -------------------------------------------------------------

                INIT_WAIT_WRITE: begin
                    if (sccb_done) begin
                        if (sccb_ack_error) begin
                            state <= INIT_ERROR;
                        end
                        else begin
                            rom_index <= rom_index + 1'b1;
                            state     <= INIT_LOAD;
                        end
                    end
                end

                // -------------------------------------------------------------
                // Execute a millisecond delay entry.
                // -------------------------------------------------------------

                INIT_DELAY: begin
                    if (delay_counter == DELAY_CYCLES - 1) begin
                        delay_counter <= '0;
                        rom_index     <= rom_index + 1'b1;
                        state         <= INIT_LOAD;
                    end
                    else begin
                        delay_counter <= delay_counter + 1'b1;
                    end
                end

                INIT_DONE: begin
                    done  <= 1'b1;
                    state <= INIT_DONE;
                end

                INIT_ERROR: begin
                    error <= 1'b1;
                    state <= INIT_ERROR;
                end

                default: begin
                    state <= INIT_IDLE;
                end

            endcase
        end
    end


    // =========================================================================
    // Configuration ROM
    //
    // This initial table establishes:
    // - software reset;
    // - DVP output;
    // - RGB565 output;
    // - 160x120 output dimensions;
    // - internal ISP operation;
    // - normal test-pattern-disabled operation.
    //
    // IMPORTANT:
    // The OV5640 normally uses a larger ISP tuning table for optimal image
    // quality. The entries below define the protocol and principal output
    // settings. Additional AWB, gamma, lens-correction and AEC entries can be
    // inserted before the END marker without changing the state machine.
    // =========================================================================

    always_comb begin
        case (rom_index)

            // -----------------------------------------------------------------
            // Software reset and clock source
            // -----------------------------------------------------------------

            8'd0:  rom_entry = {16'h3103, 8'h11};
            8'd1:  rom_entry = {16'h3008, 8'h82}; // Software reset
            8'd2:  rom_entry = {16'hFFFE, 8'd00}; // Wait 10 ms

            // Exit reset but remain in software power-down.
            8'd3:  rom_entry = {16'h3008, 8'h42};

            // -----------------------------------------------------------------
            // Enable DVP pads and internal functional blocks
            // -----------------------------------------------------------------

            8'd4:  rom_entry = {16'h3103, 8'h03};
            8'd5:  rom_entry = {16'h3017, 8'hFF};
            8'd6:  rom_entry = {16'h3018, 8'hFF};

            // Enable internal system clocks.
            8'd7:  rom_entry = {16'h3000, 8'h00};
            8'd8:  rom_entry = {16'h3002, 8'h1C};
            8'd9:  rom_entry = {16'h3004, 8'hFF};
            8'd10: rom_entry = {16'h3006, 8'hC3};

            // -----------------------------------------------------------------
            // PLL and internal clock configuration
            //
            // The breakout should be configured with XCLK = INT, which provides
            // the OV5640 with its on-board 24 MHz reference clock.
            // -----------------------------------------------------------------

            8'd11: rom_entry = {16'h3034, 8'h1A};
            8'd12: rom_entry = {16'h3035, 8'h11};
            8'd13: rom_entry = {16'h3036, 8'h3C};
            8'd14: rom_entry = {16'h3037, 8'h13};
            8'd15: rom_entry = {16'h3108, 8'h01};

            // -----------------------------------------------------------------
            // Basic sensor/analog configuration
            // -----------------------------------------------------------------

            8'd16: rom_entry = {16'h3630, 8'h36};
            8'd17: rom_entry = {16'h3631, 8'h0E};
            8'd18: rom_entry = {16'h3632, 8'hE2};
            8'd19: rom_entry = {16'h3633, 8'h12};
            8'd20: rom_entry = {16'h3621, 8'hE0};
            8'd21: rom_entry = {16'h3704, 8'hA0};
            8'd22: rom_entry = {16'h3703, 8'h5A};
            8'd23: rom_entry = {16'h3715, 8'h78};
            8'd24: rom_entry = {16'h3717, 8'h01};
            8'd25: rom_entry = {16'h370B, 8'h60};
            8'd26: rom_entry = {16'h3705, 8'h1A};

            // -----------------------------------------------------------------
            // Sensor input window
            // Use the full active sensor region and let the internal scaler
            // produce the requested 160x120 image.
            // -----------------------------------------------------------------

            8'd27: rom_entry = {16'h3800, 8'h00};
            8'd28: rom_entry = {16'h3801, 8'h00};
            8'd29: rom_entry = {16'h3802, 8'h00};
            8'd30: rom_entry = {16'h3803, 8'h04};
            8'd31: rom_entry = {16'h3804, 8'h0A};
            8'd32: rom_entry = {16'h3805, 8'h3F};
            8'd33: rom_entry = {16'h3806, 8'h07};
            8'd34: rom_entry = {16'h3807, 8'h9B};

            // -----------------------------------------------------------------
            // DVP output size: 160x120
            //
            // Horizontal: 160 = 16'h00A0
            // Vertical:   120 = 16'h0078
            // -----------------------------------------------------------------

            8'd35: rom_entry = {16'h3808, 8'h00};
            8'd36: rom_entry = {16'h3809, 8'hA0};
            8'd37: rom_entry = {16'h380A, 8'h00};
            8'd38: rom_entry = {16'h380B, 8'h78};

            // Total horizontal and vertical timing.
            // These values leave enough blanking time for the DVP interface.
            8'd39: rom_entry = {16'h380C, 8'h07};
            8'd40: rom_entry = {16'h380D, 8'h68};
            8'd41: rom_entry = {16'h380E, 8'h03};
            8'd42: rom_entry = {16'h380F, 8'hD8};

            // Horizontal/vertical ISP offsets.
            8'd43: rom_entry = {16'h3810, 8'h00};
            8'd44: rom_entry = {16'h3811, 8'h10};
            8'd45: rom_entry = {16'h3812, 8'h00};
            8'd46: rom_entry = {16'h3813, 8'h06};

            // Horizontal and vertical subsampling increments.
            8'd47: rom_entry = {16'h3814, 8'h31};
            8'd48: rom_entry = {16'h3815, 8'h31};

            // Mirror/flip and timing control.
            8'd49: rom_entry = {16'h3820, 8'h41};
            8'd50: rom_entry = {16'h3821, 8'h01};

            // -----------------------------------------------------------------
            // Black-level correction
            // -----------------------------------------------------------------

            8'd51: rom_entry = {16'h4001, 8'h02};
            8'd52: rom_entry = {16'h4004, 8'h02};
            8'd53: rom_entry = {16'h4005, 8'h1A};

            // -----------------------------------------------------------------
            // RGB565 output format
            // -----------------------------------------------------------------

            8'd54: rom_entry = {16'h4300, 8'h61}; // RGB565
            8'd55: rom_entry = {16'h501F, 8'h01}; // ISP output = RGB

            // Enable ISP blocks used for color processing.
            8'd56: rom_entry = {16'h5000, 8'hA7};
            8'd57: rom_entry = {16'h5001, 8'hA3};

            // -----------------------------------------------------------------
            // DVP output timing
            // -----------------------------------------------------------------

            8'd58: rom_entry = {16'h460B, 8'h35};
            8'd59: rom_entry = {16'h460C, 8'h22};
            8'd60: rom_entry = {16'h4713, 8'h03};
            8'd61: rom_entry = {16'h3824, 8'h02};

            // PCLK active during valid DVP data.
            8'd62: rom_entry = {16'h4740, 8'h21};

            // -----------------------------------------------------------------
            // Automatic exposure baseline
            // -----------------------------------------------------------------

            8'd63: rom_entry = {16'h3A13, 8'h43};
            8'd64: rom_entry = {16'h3A18, 8'h00};
            8'd65: rom_entry = {16'h3A19, 8'hF8};

            8'd66: rom_entry = {16'h3A0F, 8'h30};
            8'd67: rom_entry = {16'h3A10, 8'h28};
            8'd68: rom_entry = {16'h3A1B, 8'h30};
            8'd69: rom_entry = {16'h3A1E, 8'h26};
            8'd70: rom_entry = {16'h3A11, 8'h60};
            8'd71: rom_entry = {16'h3A1F, 8'h14};

            // -----------------------------------------------------------------
            // Disable camera-generated test pattern.
            //
            // For initial debugging, replace 8'h00 with 8'h80.
            // -----------------------------------------------------------------

            8'd72: rom_entry = {16'h503D, 8'h00};

            // -----------------------------------------------------------------
            // Start normal streaming.
            // -----------------------------------------------------------------

            8'd73: rom_entry = {16'h3008, 8'h02};
            8'd74: rom_entry = {16'hFFFE, 8'd00};     //wait 10 ms

            // End marker.
            8'd75: rom_entry = {16'hFFFF, 8'hFF};     //end of configuration

            default:
                rom_entry = {16'hFFFF, 8'hFF};

        endcase
    end

endmodule