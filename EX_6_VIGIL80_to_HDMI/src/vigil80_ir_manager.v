// ============================================================================
// MODULE: vigil80_ir_manager
// DESCRIPTION:
// Top-level manager for VIGIL80 infrared camera.
//
// It includes:
// - SPI data reception from VIGIL80
// - 16-bit thermal pixel to 8-bit grayscale conversion
// - double framebuffer logic
// - two Gowin_SDP RAM instances
// - read interface for HDMI renderer
//
// VIGIL80 frame:
// - 80 x 80 active pixels = 6400 pixels
// - 23 footer words are discarded
// ============================================================================

module vigil80_ir_manager #(
    parameter int IMG_W         = 80,
    parameter int IMG_H         = 80,
    parameter int FRAME_PIX     = IMG_W * IMG_H,      // 6400
    parameter int FOOTER_WORDS  = 23,
    parameter int TOTAL_WORDS   = FRAME_PIX + FOOTER_WORDS,

    // Gowin_SDP IP configured as 6400 x 8, address [12:0]
    //parameter int RAM_ADDR_BITS = $clog2(FRAME_PIX),  //dipende dal numero di pixel real
    parameter int ADDR_BITS     = $clog2(FRAME_PIX),      //non utile

    // Thermal conversion parameters
    // TEMP_MIN = 27315 means about 0 degC in Kelvin x100
    parameter int TEMP_MIN      = 16'd27315,   //Minimum Temp used as reference for conversion
    parameter int TEMP_SHIFT    = 5
)(
    input  logic rst_n,

    // ========================================================================
    // VIGIL80 physical SPI-like video interface
    // Camera is SPI master
    // ========================================================================
    input  logic vigil_sck,  //clock camera IR (4.6 Mbits/s)
    input  logic vigil_csb,  //chip select active low
    input  logic vigil_mosi, //data 

    // ========================================================================
    // HDMI/read side
    // ========================================================================
    input  logic rd_clk,            // pixel clock
    input  logic rd_swap_point,     // usually HDMI frame start: cx==0 && cy==0
    input  logic rd_req,
    input  logic [ADDR_BITS-1:0] rd_addr,

    output logic [7:0] rd_pixel,
    output logic rd_valid,

    // ========================================================================
    // Optional debug/status outputs
    // ========================================================================
    output logic frame_available,
    output logic writing_allowed
);

    // ========================================================================
    // Internal write-side signals from SPI receiver to double framebuffer
    // ========================================================================

    logic [ADDR_BITS-1:0] wr_addr;
    logic [7:0] wr_data;         //converted 8 bit data
    logic       wr_valid;        //high when the data is converted in 8 bit and is ready to be memorized
    logic       wr_frame_done;   //high when the full frame just received can be saved in memory
    logic       wr_allow;        //used to not overwrite the frame that HDMI is reading ( 1: save frame; 0: discard frame )

    assign writing_allowed = wr_allow;

    // ========================================================================
    // 1. VIGIL80 SPI receiver + 16-bit to 8-bit conversion
    // ========================================================================

    vigil80_spi_receiver_16to8 #(
        .FRAME_PIX     (FRAME_PIX),
        .FOOTER_WORDS  (FOOTER_WORDS),
        .TOTAL_WORDS   (TOTAL_WORDS),
        .ADDR_BITS     (ADDR_BITS),
        .TEMP_MIN      (TEMP_MIN),
        .TEMP_SHIFT    (TEMP_SHIFT)
    ) spi_rx_inst (
        .rst_n          (rst_n),

        .video_sck      (vigil_sck),
        .video_csb      (vigil_csb),
        .video_mosi     (vigil_mosi),

        .wr_allow       (wr_allow),

        .pix_valid      (wr_valid),
        .pix_addr       (wr_addr),
        .pix_data       (wr_data),      
        .frame_done     (wr_frame_done)
    );

    // ========================================================================
    // 2. Double framebuffer with two Gowin_SDP RAMs
    // ========================================================================

    double_framebuffer_gowin_sdp #(
        .FRAME_PIX     (FRAME_PIX),
        .ADDR_BITS     (ADDR_BITS)
        //.RAM_ADDR_BITS (RAM_ADDR_BITS)
    ) double_fb_inst (
        .rst_n          (rst_n),

        // Write side - VIGIL80/SPI clock domain
        .wr_clk         (vigil_sck),       //clock camera IR (4.6 Mbits/s)
        .wr_valid       (wr_valid),        //high when the pixel is ready to be memorized
        .wr_addr        (wr_addr),
        .wr_data        (wr_data),
        .wr_frame_done  (wr_frame_done),   //high when the frame is completed -> swap frambuffer
        .wr_allow       (wr_allow),        //high when the frame received should be saved

        // Read side - HDMI pixel clock domain
        .rd_clk         (rd_clk),
        .rd_swap_point  (rd_swap_point),   //high when the framebuffer needs to be updated
        .rd_req         (rd_req),
        .rd_addr        (rd_addr),
        .rd_data        (rd_pixel),
        .rd_valid       (rd_valid),

        .frame_available(frame_available)
    );

endmodule