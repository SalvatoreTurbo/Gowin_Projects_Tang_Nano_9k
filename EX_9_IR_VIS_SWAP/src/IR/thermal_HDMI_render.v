// ============================================================================
// MODULE: thermal_hdmi_renderer
// DESCRIPTION:
// Reads 8-bit grayscale pixels from the IR framebuffer and converts them to RGB888.
//
// It scales IMG_W x IMG_H to IMG_W*SCALE x IMG_H*SCALE.
// ============================================================================

module thermal_hdmi_renderer #(
    parameter int H_ACTIVE  = 640,
    parameter int V_ACTIVE  = 480,

    parameter int H_BITS    = $clog2(H_ACTIVE),
    parameter int V_BITS    = $clog2(V_ACTIVE),

    parameter int IMG_W     = 80,
    parameter int IMG_H     = 80,
    parameter int SCALE     = 6,  //Each pixel in the camera will be replicated 6 times vertically and 6 times horizontally
    
    parameter int FRAME_PIX = IMG_W * IMG_H,
    parameter int ADDR_BITS = $clog2(FRAME_PIX)
)(
    input  logic clk_pixel,
    input  logic rst_n,

    input  logic [H_BITS-1:0] cx,
    input  logic [V_BITS-1:0] cy,
    input  logic vde,

    // Read interface from framebuffer to IR manager
    output logic rd_req,
    output logic [ADDR_BITS-1:0] rd_addr,
    input  logic [7:0] rd_pixel,
    input  logic rd_valid,

    // RGB output to TMDS encoder
    output logic [7:0] red,
    output logic [7:0] green,
    output logic [7:0] blue
);


    // ============================================================================
// 8-bit thermal value to RGB thermal palette
//
// Palette:
// 0   -> black
// 64  -> red
// 128 -> yellow
// 192 -> yellow/white
// 255 -> white
// ============================================================================

function automatic logic [23:0] thermal_palette(input logic [7:0] pix);
    logic [7:0] x;
    begin
        // Local ramp inside each range: 0,4,8,...252
        x = {pix[5:0], 2'b00};

        case (pix[7:6])

            // 0..63: black -> red
            2'b00: begin
                thermal_palette = {x, 8'd0, 8'd0};
            end

            // 64..127: red -> yellow
            2'b01: begin
                thermal_palette = {8'hFF, x, 8'd0};
            end

            // 128..191: yellow -> white
            2'b10: begin
                thermal_palette = {8'hFF, 8'hFF, x};
            end

            // 192..255: white
            default: begin
                thermal_palette = {8'hFF, 8'hFF, 8'hFF};
            end

        endcase
    end
endfunction

    // =========================================================================
    // Display dimensions after scaling
    // =========================================================================
    localparam int DISP_W = IMG_W * SCALE;   //480
    localparam int DISP_H = IMG_H * SCALE;   //480

    // =========================================================================
    // Center image on screen
    // =========================================================================
    localparam int X_OFF = (H_ACTIVE - DISP_W) / 2;
    localparam int Y_OFF = (V_ACTIVE - DISP_H) / 2;

    //cx = 0 ----------------------------- 639
    //     80 px      480 px        80 px
    //    +--------+-------------+--------+
    //    | nero   | immagine IR | nero   |
    //    +--------+-------------+--------+
    //     0      79            559      639

    // =========================================================================
    // Source image coordinates
    // =========================================================================
    
    logic in_image_area;    // high within the camera’s valid image area
    logic in_image_area_d;  // signal delayed by 1 clock cycle because SDP RAM is synchronous

    // camera pixels that we want to read
    logic [$clog2(IMG_W)-1:0] src_x;
    logic [$clog2(IMG_H)-1:0] src_y;

    // =========================================================================
    // Generate framebuffer read address
    // =========================================================================

    always_comb begin
        //default values
        in_image_area = 1'b0;
        src_x         = '0;
        src_y         = '0;

        rd_req        = 1'b0;   //don’t read from RAM
        rd_addr       = '0;

        if (vde &&
            (cx >= X_OFF) && (cx < X_OFF + DISP_W) &&
            (cy >= Y_OFF) && (cy < Y_OFF + DISP_H)) begin

            in_image_area = 1'b1;

            //Conversion of HDMI coordinates to camera coordinates
            src_x = (cx - X_OFF) / SCALE;
            src_y = (cy - Y_OFF) / SCALE;

            rd_req  = 1'b1;
            rd_addr = (src_y * IMG_W) + src_x;
        end
    end

    // =========================================================================
    // RAM has one clock latency.
    // Delay image-area flag and then output grayscale as RGB.
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
                //red   <= rd_pixel;
                //green <= rd_pixel;
                //blue  <= rd_pixel;
                {red, green, blue} <= thermal_palette(rd_pixel);
            end 
            else begin  //out of image : black
                red   <= 8'd0;
                green <= 8'd0;
                blue  <= 8'd0;
            end
        end
    end

endmodule