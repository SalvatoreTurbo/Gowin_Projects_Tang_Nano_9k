// ============================================================================
// MODULE: sccb_write_master
// DESCRIPTION: Executes one OV5640 SCCB register-write transaction.
//
// Transaction format:
//   START
//   device address + write bit
//   register address high byte
//   register address low byte
//   register value
//   STOP
//
// SCL and SDA use open-drain signaling:
//   drive low -> output 0
//   release   -> output Z, external pull-up produces logic 1
// ============================================================================

module sccb_write_master #(
    parameter int CLK_HZ  = 27_000_000,
    parameter int SCCB_HZ = 100_000,

    parameter logic [6:0] DEVICE_ADDR = 7'h3C
)(
    input  logic clk,
    input  logic rst_n,

    input  logic start,

    input  logic [15:0] reg_addr,
    input  logic [7:0]  reg_data,

    output logic busy,
    output logic done,
    output logic ack_error,

    inout  wire scl,
    inout  wire sda
);

    // =========================================================================
    // Generating ticks per clock cycle at 2 * SCCB_HZ for SCL
    // 
    // Each SCL period consists of two phases:
    // - one tick with SCL low;
    // - one tick with SCL high.
    //
    // A tick is generated for every edges of SCL. Therefore the tick frequency is 2 * SCCB_HZ.
    // =========================================================================

    localparam int TICK_DIV_RAW = CLK_HZ / (SCCB_HZ * 2);  //=135; So a tick is generated every 135 cycles of the 27 MHz clock
    localparam int TICK_DIV     = (TICK_DIV_RAW < 1) ? 1 : TICK_DIV_RAW;   //Prevents the divisor from becoming zero if an SCCB frequency that is too high is requested
    localparam int DIV_BITS     = (TICK_DIV <= 1) ? 1 : $clog2(TICK_DIV);  //Avoid vectors with zero magnitude.

    logic [DIV_BITS-1:0] tick_counter;  //Count the clock cycles at 27 MHz
    logic tick;                         //High for a single FPGA clock cycle every TICK_DIV

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tick_counter <= '0;
            tick         <= 1'b0;
        end
        else begin
            tick <= 1'b0;

            if (tick_counter == TICK_DIV - 1) begin
                tick_counter <= '0;
                tick         <= 1'b1;     //Generates a tick every TICK_DIV cycles
            end
            else begin
                tick_counter <= tick_counter + 1'b1;
            end
        end
    end

    // =========================================================================
    // Open-drain line control
    // =========================================================================

    logic scl_drive_low;
    logic sda_drive_low;

    assign scl = scl_drive_low ? 1'b0 : 1'bz;  // When the SCL is set to high impedance, it is pulled up to 1 by the pull-up resistor
    assign sda = sda_drive_low ? 1'b0 : 1'bz;  // Same as scl

    wire sda_input = sda;  //This is necessary because the SDA line must also be read. It's needed for the ACK.

    // =========================================================================
    // SCCB transaction FSM. The FSM SCCB changes state only when tick=1
    // =========================================================================

    typedef enum logic [3:0] {
        SCCB_IDLE,

        SCCB_START_0,
        SCCB_START_1,

        SCCB_BIT_LOW,
        SCCB_BIT_HIGH,

        SCCB_ACK_LOW,
        SCCB_ACK_HIGH,

        SCCB_NEXT_BYTE,

        SCCB_STOP_0,
        SCCB_STOP_1,

        SCCB_FINISH
    } sccb_state_t;

    sccb_state_t state;

    //Preparing the four bytes to be sent
    //tx_bytes[0] <= {DEVICE_ADDR, 1'b0};
    //tx_bytes[1] <= reg_addr[15:8];
    //tx_bytes[2] <= reg_addr[7:0];
    //tx_bytes[3] <= reg_data;

    logic [7:0] tx_bytes [0:3];

    logic [1:0] byte_index;   //Indicate which of the 4 bytes is in transmission
    logic [2:0] bit_index;    //Indicate which bit of the byte is in transmission
 
    logic [7:0] tx_byte;      //Contains the byte currently in transmission

    // =========================================================================
    // SCCB transaction
    // =========================================================================

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= SCCB_IDLE;

            scl_drive_low <= 1'b0;
            sda_drive_low <= 1'b0;

            byte_index    <= 2'd0;
            bit_index     <= 3'd7;
            tx_byte       <= 8'd0;

            busy          <= 1'b0;
            done          <= 1'b0;
            ack_error     <= 1'b0;

            tx_bytes[0]   <= 8'd0;
            tx_bytes[1]   <= 8'd0;
            tx_bytes[2]   <= 8'd0;
            tx_bytes[3]   <= 8'd0;
        end
        else begin
            // done is a one-clock pulse
            done <= 1'b0;

            // ================================================================
            // Wait for a new transaction. 
            // SCCB_IDLE is managed by an external IF so that it can accept a "start" command immediately, 
            // without waiting for the next tick -> so SCCB_IDLE is controlled at a frequency of 27 MHz
            // ================================================================

            if (state == SCCB_IDLE) begin
                scl_drive_low <= 1'b0;
                sda_drive_low <= 1'b0;

                busy <= 1'b0;

                if (start) begin
                    // Prepare the four transaction bytes. the transmission is MSB first
                    tx_bytes[0] <= {DEVICE_ADDR, 1'b0};
                    tx_bytes[1] <= reg_addr[15:8];
                    tx_bytes[2] <= reg_addr[7:0];
                    tx_bytes[3] <= reg_data;

                    byte_index <= 2'd0;
                    bit_index  <= 3'd7;   //the transmission is MSB first -> from 7 to 0
                    tx_byte    <= {DEVICE_ADDR, 1'b0};

                    ack_error <= 1'b0;
                    busy      <= 1'b1;

                    state <= SCCB_START_0;
                end
            end

            // All protocol-state transitions occur on the SCCB timing tick.
            else if (tick) begin
                case (state)

                    // --------------------------------------------------------
                    // Bus idle before START: SCL high, SDA high.
                    // --------------------------------------------------------

                    SCCB_START_0: begin
                        scl_drive_low <= 1'b0;
                        sda_drive_low <= 1'b0;

                        state <= SCCB_START_1;
                    end

                    // --------------------------------------------------------
                    // START: SDA falls while SCL is high.
                    // --------------------------------------------------------

                    SCCB_START_1: begin   //START CONDITION: SDA goes from high to low, while SCL is high
                        scl_drive_low <= 1'b0;
                        sda_drive_low <= 1'b1; //start condition

                        state <= SCCB_BIT_LOW;
                    end

                    // --------------------------------------------------------
                    // SCL low: place the current bit on SDA.
                    //
                    // SCL is pulled low. During the low phase, SDA is prepared.
                    // --------------------------------------------------------

                    SCCB_BIT_LOW: begin
                        scl_drive_low <= 1'b1;

                        // Open-drain behavior:
                        // bit 0 -> drive SDA low
                        // bit 1 -> release SDA
                        sda_drive_low <= ~tx_byte[bit_index];  //The bit to be transferred is prepared

                        state <= SCCB_BIT_HIGH;
                    end

                    // --------------------------------------------------------
                    // The FPGA releases SCL, and the pull-up resistor pulls the line high. The camera samples SDA during this phase
                    // --------------------------------------------------------

                    SCCB_BIT_HIGH: begin
                        scl_drive_low <= 1'b0;

                        if (bit_index == 0) begin   //Whole byte has been transmitted
                            state <= SCCB_ACK_LOW;
                        end
                        else begin
                            bit_index <= bit_index - 1'b1;  //MSB first trasnmission
                            state     <= SCCB_BIT_LOW;
                        end
                    end

                    // --------------------------------------------------------
                    // Release SDA so the camera can generate ACK (camra force SDA at zero during the ninth SCL pulse).
                    // --------------------------------------------------------

                    SCCB_ACK_LOW: begin
                        scl_drive_low <= 1'b1;
                        sda_drive_low <= 1'b0;  //SDA is released => camera can force 0 on SDA

                        state <= SCCB_ACK_HIGH;
                    end

                    // --------------------------------------------------------
                    // Sample ACK while SCL is released high.
                    // ACK = SDA low.
                    // --------------------------------------------------------

                    SCCB_ACK_HIGH: begin
                        scl_drive_low <= 1'b0;
                        sda_drive_low <= 1'b0;

//                        if (sda_input !== 1'b0) //If the value on SDA is not 0, the camera did not generate the ACK
//                            ack_error <= 1'b1;

                        state <= SCCB_NEXT_BYTE;
                    end

                    // --------------------------------------------------------
                    // Load the next byte, or start the STOP condition.
                    // --------------------------------------------------------

                    SCCB_NEXT_BYTE: begin
                        
                        // SCL has remained high for one complete tick.
                        // Sample ACK before pulling SCL low again.
                        if (sda_input !== 1'b0)
                            ack_error <= 1'b1;

                        scl_drive_low <= 1'b1;  //SCL goes low to prepare the next byte

                        if (byte_index == 2'd3) begin
                            sda_drive_low <= 1'b1;    //Prepare STOP with both lines low
                            state         <= SCCB_STOP_0;
                        end
                        else begin
                            byte_index <= byte_index + 1'b1;
                            bit_index  <= 3'd7;

                            tx_byte <= tx_bytes[byte_index + 1'b1];  //load next byte

                            state <= SCCB_BIT_LOW;
                        end
                    end

                    // --------------------------------------------------------
                    // Release SCL high while SDA remains low.
                    // --------------------------------------------------------

                    SCCB_STOP_0: begin
                        scl_drive_low <= 1'b0;
                        sda_drive_low <= 1'b1;

                        state <= SCCB_STOP_1;
                    end

                    // --------------------------------------------------------
                    // STOP: SDA rises while SCL is high. The STOP CONDITION is triggered
                    // --------------------------------------------------------

                    SCCB_STOP_1: begin
                        scl_drive_low <= 1'b0;
                        sda_drive_low <= 1'b0;

                        state <= SCCB_FINISH;
                    end

                    // --------------------------------------------------------
                    // Signal completion.
                    // --------------------------------------------------------

                    SCCB_FINISH: begin
                        busy  <= 1'b0;
                        done  <= 1'b1;

                        state <= SCCB_IDLE;
                    end

                    default: begin
                        scl_drive_low <= 1'b0;
                        sda_drive_low <= 1'b0;

                        busy  <= 1'b0;
                        state <= SCCB_IDLE;
                    end

                endcase
            end
        end
    end

endmodule