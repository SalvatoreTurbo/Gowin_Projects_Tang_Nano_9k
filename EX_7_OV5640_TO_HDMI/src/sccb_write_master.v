// ============================================================================
// MODULE: sccb_write_master
// DESCRIPTION:
// Performs one OV5640 SCCB register-write transaction.
//
// Transaction:
//   START
//   device address + write bit
//   register address high byte
//   register address low byte
//   register value
//   STOP
//
// SCL and SDA are driven as open-drain signals:
//   drive 0 -> line is low
//   drive Z -> external pull-up makes line high
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

    inout wire scl,
    inout wire sda
);

    // Four internal steps are used for every SCCB clock period.
    localparam int TICK_DIV = CLK_HZ / (SCCB_HZ * 4);
    localparam int DIV_BITS = $clog2(TICK_DIV);

    logic [DIV_BITS-1:0] tick_counter;
    logic tick;

    // =========================================================================
    // Quarter-period clock enable
    // =========================================================================

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tick_counter <= '0;
            tick         <= 1'b0;
        end
        else begin
            tick <= 1'b0;

            if (tick_counter == TICK_DIV - 1) begin
                tick_counter <= '0;
                tick         <= 1'b1;
            end
            else begin
                tick_counter <= tick_counter + 1'b1;
            end
        end
    end

    // =========================================================================
    // Open-drain outputs
    // =========================================================================

    logic scl_drive_low;
    logic sda_drive_low;

    assign scl = scl_drive_low ? 1'b0 : 1'bz;
    assign sda = sda_drive_low ? 1'b0 : 1'bz;

    wire sda_input = sda;

    // =========================================================================
    // State machine
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
        SCCB_STOP_2,
        SCCB_FINISH
    } sccb_state_t;

    sccb_state_t state;

    logic [7:0] tx_bytes [0:3];

    logic [2:0] byte_index;
    logic [2:0] bit_index;
    logic [7:0] tx_byte;

    // =========================================================================
    // SCCB transaction logic
    // =========================================================================

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= SCCB_IDLE;

            scl_drive_low <= 1'b0;
            sda_drive_low <= 1'b0;

            byte_index    <= '0;
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
            done <= 1'b0;

            if (state == SCCB_IDLE) begin
                scl_drive_low <= 1'b0;
                sda_drive_low <= 1'b0;
                busy          <= 1'b0;

                if (start) begin
                    // OV5640 address followed by write bit = 0.
                    tx_bytes[0] <= {DEVICE_ADDR, 1'b0};
                    tx_bytes[1] <= reg_addr[15:8];
                    tx_bytes[2] <= reg_addr[7:0];
                    tx_bytes[3] <= reg_data;

                    byte_index <= 3'd0;
                    bit_index  <= 3'd7;
                    tx_byte    <= {DEVICE_ADDR, 1'b0};

                    ack_error  <= 1'b0;
                    busy       <= 1'b1;
                    state      <= SCCB_START_0;
                end
            end
            else if (tick) begin
                case (state)

                    // Bus idle: SCL = 1, SDA = 1.
                    SCCB_START_0: begin
                        scl_drive_low <= 1'b0;
                        sda_drive_low <= 1'b0;
                        state         <= SCCB_START_1;
                    end

                    // START: SDA falls while SCL is high.
                    SCCB_START_1: begin
                        sda_drive_low <= 1'b1;
                        state         <= SCCB_BIT_LOW;
                    end

                    // SCL low: set next data bit on SDA.
                    SCCB_BIT_LOW: begin
                        scl_drive_low <= 1'b1;

                        // Open-drain:
                        // data 0 -> drive line low
                        // data 1 -> release line
                        sda_drive_low <= ~tx_byte[bit_index];

                        state <= SCCB_BIT_HIGH;
                    end

                    // Release SCL high; data is sampled by camera.
                    SCCB_BIT_HIGH: begin
                        scl_drive_low <= 1'b0;

                        if (bit_index == 0) begin
                            state <= SCCB_ACK_LOW;
                        end
                        else begin
                            bit_index <= bit_index - 1'b1;
                            state     <= SCCB_BIT_LOW;
                        end
                    end

                    // Release SDA so camera can produce ACK.
                    SCCB_ACK_LOW: begin
                        scl_drive_low <= 1'b1;
                        sda_drive_low <= 1'b0;
                        state         <= SCCB_ACK_HIGH;
                    end

                    // Sample ACK while SCL is high.
                    SCCB_ACK_HIGH: begin
                        scl_drive_low <= 1'b0;

                        // ACK is normally low.
                        if (sda_input !== 1'b0)
                            ack_error <= 1'b1;

                        state <= SCCB_NEXT_BYTE;
                    end

                    // Select the next transaction byte.
                    SCCB_NEXT_BYTE: begin
                        scl_drive_low <= 1'b1;

                        if (byte_index == 3) begin
                            sda_drive_low <= 1'b1;
                            state         <= SCCB_STOP_0;
                        end
                        else begin
                            byte_index <= byte_index + 1'b1;
                            bit_index  <= 3'd7;
                            tx_byte    <= tx_bytes[byte_index + 1'b1];
                            state      <= SCCB_BIT_LOW;
                        end
                    end

                    // STOP preparation: SCL low, SDA low.
                    SCCB_STOP_0: begin
                        scl_drive_low <= 1'b1;
                        sda_drive_low <= 1'b1;
                        state         <= SCCB_STOP_1;
                    end

                    // Release SCL high while SDA remains low.
                    SCCB_STOP_1: begin
                        scl_drive_low <= 1'b0;
                        sda_drive_low <= 1'b1;
                        state         <= SCCB_STOP_2;
                    end

                    // STOP: SDA rises while SCL is high.
                    SCCB_STOP_2: begin
                        scl_drive_low <= 1'b0;
                        sda_drive_low <= 1'b0;
                        state         <= SCCB_FINISH;
                    end

                    SCCB_FINISH: begin
                        busy  <= 1'b0;
                        done  <= 1'b1;
                        state <= SCCB_IDLE;
                    end

                    default: begin
                        state <= SCCB_IDLE;
                    end

                endcase
            end
        end
    end

endmodule