// ============================================================================
// MODULE: ov5640_visible_manager
// DESCRIPTION: Top-level manager for the Adafruit OV5640 parallel camera breakout
//
// The module:
// - initializes the OV5640 through SCCB/I2C;
// - receives the DVP RGB565 video stream;
// - converts RGB565 to RGB332;
// - stores complete frames in a double framebuffer;
// - provides a read interface to the HDMI renderer.
//
// Recommended initial camera configuration:
// - 160x120
// - RGB565
// - internal 24 MHz XCLK on the Adafruit breakout
// ============================================================================

module ov5640_visible_manager #(
    parameter int IMG_W      = 160,
    parameter int IMG_H      = 120,
    parameter int FRAME_PIX  = IMG_W * IMG_H,
    parameter int ADDR_BITS  = $clog2(FRAME_PIX)
)(
    input  logic rst_n,          //global reset active low
    input  logic sys_clk,        //board clock (used during camera configuration)

    // ========================================================================
    // OV5640 parallel/DVP interface
    // ========================================================================
    input  logic       ov_pclk,   //Camera clock
    input  logic       ov_vsync,  //identifies the vertical boundary of the frame: In other word: frame has ended
    input  logic       ov_href,   //Indicates valid portion of a row (1:valid data; 0:blanking)
    input  logic [7:0] ov_data,   //Parallel data bus

    output logic ov_reset_n,   //camera reset, active low. Reset the camera's internal logic(register,...)
    output logic ov_pwdn,      //puts the camera into a low-power state. (1: camera off; 0: camera on)

    // ========================================================================
    // OV5640 SCCP/I2C interface  (to configure camera)
    // ======================================================================== 
    //I2C communication is open-drain, so the wires must work as both inputs and outputs
    inout  wire ov_scl,   //clock I2C
    inout  wire ov_sda,   //serial data I2C. The FPGA uses it as an output when sending data and as an input when checking for the ACK

    // ========================================================================
    // HDMI/read side
    // ========================================================================
    input  logic rd_clk,                    //pixel clock to HDMI
    input  logic rd_swap_point,             //indicates when swap framebuffer (when cx=cy=0)
    input  logic rd_req,                    //read request sent by renderer
    input  logic [ADDR_BITS-1:0] rd_addr,

    output logic [7:0] rd_pixel,   //RGB332 pixel
    output logic rd_valid,         //1 when the pixel is valid. Gowin RAM is synchronous, data is not available in the same cycle as the request

    // ========================================================================
    // Status/debug
    // ========================================================================
    output logic camera_initialized,  //1 when the SCCB configuration has completed successfully
    output logic frame_available,     //1 after the first frame available. Signals that at least 1 frame is received
    output logic writing_allowed      //copy of wr_allow for debug
);

    // =========================================================================
    // Capture -> framebuffer interface
    // =========================================================================

    logic [ADDR_BITS-1:0] wr_addr;
    logic [7:0] wr_data;         //converted 8 bit data
    logic       wr_valid;        //high when the data is converted in 8 bit and is ready to be memorized
    logic       wr_frame_done;   //high when the full frame just received and can be saved in memory
    logic       wr_allow;        //used to not overwrite the frame that HDMI is reading ( 1: save frame; 0: discard frame )

    assign writing_allowed = wr_allow;

    // =========================================================================
    // OV5640 reset and SCCB initialization
    // =========================================================================

    ov5640_controller ov5640_controller_inst (
        .clk               (sys_clk),
        .rst_n             (rst_n),

        .ov_reset_n        (ov_reset_n),
        .ov_pwdn           (ov_pwdn),

        .ov_scl            (ov_scl),
        .ov_sda            (ov_sda),

        .camera_initialized(camera_initialized)
    );

    
    // camera_initialized is generated in the sys_clk domain but used by the
    // DVP capture logic in the ov_pclk domain. The two flip-flops prevent
    // metastability and provide a synchronized capture-enable signal

    logic camera_initialized_pclk_meta;
    logic camera_initialized_pclk_sync;

    always_ff @(posedge ov_pclk or negedge rst_n) begin
        if (!rst_n) begin
            camera_initialized_pclk_meta <= 1'b0;
            camera_initialized_pclk_sync <= 1'b0;
        end
        else begin
            camera_initialized_pclk_meta <= camera_initialized;
            camera_initialized_pclk_sync <= camera_initialized_pclk_meta;
        end
    end


    // =========================================================================
    // DVP RGB565 receiver
    // =========================================================================

    ov5640_dvp_rgb565_capture #(
        .IMG_W      (IMG_W),
        .IMG_H      (IMG_H),
        .FRAME_PIX  (FRAME_PIX),
        .ADDR_BITS  (ADDR_BITS),

        // Adafruit/CircuitPython names HS as HREF.
        // Polarity may be changed here if required by the selected register set.
        .VSYNC_ACTIVE(1'b1),
        .HREF_ACTIVE (1'b1)
    ) capture_inst (
        .rst_n             (rst_n),
        .capture_ready     (camera_initialized_pclk_sync),

        .cam_pclk          (ov_pclk),
        .cam_vsync         (ov_vsync),
        .cam_href          (ov_href),
        .cam_data          (ov_data),

        .wr_allow          (wr_allow),

        .pix_valid         (wr_valid),
        .pix_addr          (wr_addr),
        .pix_data          (wr_data),
        .frame_done        (wr_frame_done)
    );

    // =========================================================================
    // Same double framebuffer architecture used for VIGIL80
    // =========================================================================

    double_framebuffer_gowin_sdp #(
        .FRAME_PIX (FRAME_PIX),
        .ADDR_BITS (ADDR_BITS)
    ) double_framebuffer_inst (
        .rst_n          (rst_n),

        // Write side: OV5640 pixel-clock domain
        .wr_clk         (ov_pclk),
        .wr_valid       (wr_valid),
        .wr_addr        (wr_addr),
        .wr_data        (wr_data),
        .wr_frame_done  (wr_frame_done),
        .wr_allow       (wr_allow),

        // Read side: HDMI pixel-clock domain
        .rd_clk         (rd_clk),
        .rd_swap_point  (rd_swap_point),
        .rd_req         (rd_req),
        .rd_addr        (rd_addr),
        .rd_data        (rd_pixel),
        .rd_valid       (rd_valid),

        .frame_available(frame_available)
    );

endmodule