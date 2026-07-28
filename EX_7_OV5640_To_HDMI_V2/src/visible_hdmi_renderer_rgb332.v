// ============================================================================
// MODULE: visible_hdmi_renderer_rgb332
// DESCRIPTION:
// Reads RGB332 pixels from the visible-camera framebuffer and converts them
// to RGB888 for HDMI.
//
// Default configuration:
// - framebuffer: 160x120
// - HDMI active area: 640x480
// - SCALE = 4
// ============================================================================

module visible_hdmi_renderer_rgb332 #(
    parameter int H_ACTIVE  = 640,
    parameter int V_ACTIVE  = 480,

    parameter int H_BITS    = $clog2(H_ACTIVE),
    parameter int V_BITS    = $clog2(V_ACTIVE),

    parameter int IMG_W     = 160,
    parameter int IMG_H     = 120,
    parameter int SCALE     = 4,   //Each pixel in the camera will be replicated 6 times vertically and 6 times horizontally

    parameter int FRAME_PIX = IMG_W * IMG_H,
    parameter int ADDR_BITS = $clog2(FRAME_PIX)
)(
    input  logic clk_pixel,
    input  logic rst_n,

    input  logic [H_BITS-1:0] cx,
    input  logic [V_BITS-1:0] cy,
    input  logic vde,

    output logic rd_req,
    output logic [ADDR_BITS-1:0] rd_addr,

    input  logic [7:0] rd_pixel,
    input  logic rd_valid,

    output logic [7:0] red,
    output logic [7:0] green,
    output logic [7:0] blue
);

    // Display dimensions after scaling
    localparam int DISPLAY_W = IMG_W * SCALE;
    localparam int DISPLAY_H = IMG_H * SCALE;

    // Center image on screen
    localparam int X_OFFSET = (H_ACTIVE - DISPLAY_W) / 2;
    localparam int Y_OFFSET = (V_ACTIVE - DISPLAY_H) / 2;

    // Camera pixels that we want to read
    logic [$clog2(IMG_W)-1:0] source_x;
    logic [$clog2(IMG_H)-1:0] source_y;

    logic in_image_area;    // high within the camera’s valid image area
    logic in_image_area_d;  // signal delayed by 1 clock cycle because SDP RAM is synchronous

    logic [7:0] converted_red;
    logic [7:0] converted_green;
    logic [7:0] converted_blue;

    // =========================================================================
    // RGB332 -> RGB888 conversion
    // =========================================================================

    rgb332_to_rgb888 rgb_converter_inst (
        .pixel_in (rd_pixel),

        .red      (converted_red),
        .green    (converted_green),
        .blue     (converted_blue)
    );

    // =========================================================================
    // Address generation
    // =========================================================================

    always_comb begin
        //default values
        in_image_area = 1'b0;

        source_x = '0;
        source_y = '0;

        rd_req  = 1'b0;    //don’t read from RAM
        rd_addr = '0;

        if (vde &&
            (cx >= X_OFFSET) && (cx < X_OFFSET + DISPLAY_W) &&
            (cy >= Y_OFFSET) && (cy < Y_OFFSET + DISPLAY_H)) begin

            in_image_area = 1'b1;

            //Conversion of HDMI coordinates to camera coordinates
            source_x = (cx - X_OFFSET) / SCALE;
            source_y = (cy - Y_OFFSET) / SCALE;

            rd_req  = 1'b1;
            rd_addr = (source_y * IMG_W) + source_x;
        end
    end

    // =========================================================================
    // RAM latency alignment and RGB output
    // =========================================================================

    always_ff @(posedge clk_pixel or negedge rst_n) begin
        if (!rst_n) begin
            in_image_area_d <= 1'b0;

            red   <= 8'd0;
            green <= 8'd0;
            blue  <= 8'd0;
        end
        else begin
            in_image_area_d <= in_image_area;

            if (in_image_area_d && rd_valid) begin
                red   <= converted_red;
                green <= converted_green;
                blue  <= converted_blue;
            end
            else begin    //out of image : black
                red   <= 8'd0;
                green <= 8'd0;
                blue  <= 8'd0;
            end
        end
    end

endmodule