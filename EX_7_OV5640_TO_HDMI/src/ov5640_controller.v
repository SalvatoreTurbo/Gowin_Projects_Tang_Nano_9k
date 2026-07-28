// ============================================================================
// MODULE: ov5640_controller
// DESCRIPTION: Controls OV5640 power-up, hardware reset and register initialization.
//
//Initialization sequence:
//  Reset FPGA (global reset, rst_n)
//      ↓
//  POWER_DOWN
//      ↓ 10 ms
//  RESET_ACTIVE (camera reset, ov_reset_n)
//      ↓ 10 ms
//  RESET_RELEASED 
//      ↓ 10 ms
//  START_SCCB
//      ↓
//  WAIT_SCCB
//      ↓
//  READY
// ============================================================================

module ov5640_controller #(
    parameter int CLK_HZ = 27_000_000  // ≈ 37 ns
)(
    input logic clk,   //connected to 27MHz board clk
    input logic rst_n,

    output logic ov_reset_n,
    output logic ov_pwdn,  //puts the camera into low-power mode and disables operation

    inout wire ov_scl,
    inout wire ov_sda,

    output logic camera_initialized
);
    localparam int SCCB_HZ = 100_000;   //SCCB bus sets at 100 kHz

    //since 1 / 100 s = 10 ms, we have to wait 27.000.000 / 100 = 270.000 cycles to wait 10 ms
    localparam int START_DELAY_CYCLES = CLK_HZ / 100; // 10 ms
    localparam int RESET_DELAY_CYCLES = CLK_HZ / 100; // 10 ms

    logic [$clog2(START_DELAY_CYCLES + 1)-1:0] delay_counter;  //for counting clk cycles during the delays phases

    typedef enum logic [2:0] {
        POWER_DOWN,
        RESET_ACTIVE,
        RESET_RELEASED,
        START_SCCB,
        WAIT_SCCB,
        READY
    } state_t;

    state_t state;

    logic init_start;   //a single-cycle pulse that triggers ov5640_sccb_init
    logic init_done;    //1 if is fully configured
    logic init_error;   //1 if an error occurred during an SCCB write operation


//The controller doesn't know which registers need to be written to. It only knows:
//when to start configuration;
//when it is complete;
//if an error has occurred.
//The register table belongs exclusively to ov5640_sccb_init.

    ov5640_sccb_init #(
        .CLK_HZ(CLK_HZ),
        .SCCB_HZ(SCCB_HZ)
    ) sccb_init_inst (
        .clk       (clk),
        .rst_n     (rst_n),
        .start     (init_start),

        .scl       (ov_scl),
        .sda       (ov_sda),

        .done      (init_done),
        .error     (init_error)
    );


    //FSM controller
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state              <= POWER_DOWN;
            delay_counter      <= '0;
            
            //The camera is disabled and kept in a reset state
            ov_pwdn            <= 1'b1;
            ov_reset_n         <= 1'b0;

            init_start         <= 1'b0;
            camera_initialized <= 1'b0;
        end
        else begin
            init_start <= 1'b0;

            case (state)

                POWER_DOWN: begin
                    //The camera is disabled and kept in a reset state
                    ov_pwdn    <= 1'b1;
                    ov_reset_n <= 1'b0;

                    if (delay_counter == START_DELAY_CYCLES - 1) begin  //waiting of 10 ms
                        delay_counter <= '0;
                        state         <= RESET_ACTIVE;
                    end
                    else begin
                        delay_counter <= delay_counter + 1'b1;
                    end
                end

                RESET_ACTIVE: begin
                    //The camera comes out of power-down mode->internal circuits can be powered up and stabilize, 
                    //but the logic remains locked in a reset state
                    ov_pwdn    <= 1'b0;
                    ov_reset_n <= 1'b0;

                    if (delay_counter == RESET_DELAY_CYCLES - 1) begin
                        delay_counter <= '0;
                        state         <= RESET_RELEASED;
                    end
                    else begin
                        delay_counter <= delay_counter + 1'b1;
                    end
                end

                RESET_RELEASED: begin
                    //Camera is powered up and out of reset
                    //The controller waits other 10 ms to allow the logic and the SCCB bus to become operational
                    ov_pwdn    <= 1'b0;
                    ov_reset_n <= 1'b1;

                    if (delay_counter == RESET_DELAY_CYCLES - 1) begin
                        delay_counter <= '0;
                        state         <= START_SCCB;
                    end
                    else begin
                        delay_counter <= delay_counter + 1'b1;
                    end
                end

                START_SCCB: begin
                    //ov5640_sccb_init begins writing camera registers
                    init_start <= 1'b1;
                    state      <= WAIT_SCCB;
                end

                WAIT_SCCB: begin
                    //The controller waits for the result of configurations
                    if (init_done) begin
                        camera_initialized <= 1'b1;
                        state              <= READY;
                    end

                    else if (init_error) begin
                        camera_initialized <= 1'b0;
                        state              <= POWER_DOWN;
                        delay_counter      <= '0;
                    end
                end

                READY: begin
                    //The camera is: powered on, out of reset mode and configured;
                    ov_pwdn            <= 1'b0;
                    ov_reset_n         <= 1'b1;
                    camera_initialized <= 1'b1;
                end

                default: begin
                    state <= POWER_DOWN;
                end
            endcase
        end
    end

endmodule