// ============================================================================
// MODULE: fusion_pipeline
// DESCRIPTION: Reads the VIS and IR framebuffers at the same time, pixel by
// pixel, while the HDMI frame is drawn, and produces the RGB888 output.
//
// DISPLAY MODES (display_mode):
//
//   0  MODE_VIS        : visible image only
//   1  MODE_IR_GRAY    : thermal image only, grayscale
//   2  MODE_IR_COLOR   : thermal image only, false colour
//   3  MODE_BLEND_50   : 50 % visible + 50 % thermal false colour, everywhere
//   4  MODE_THRESHOLD  : threshold-gated blend (baseline of the fusion report):
//                          thermal > IR_THRESHOLD : (1-a)*VIS + a*FalseColor
//                          otherwise              : VIS
//                        with a = IR_ALPHA_Q / 4
//   5 ... 7            : reserved (black) -> future dynamic alpha
//
// Outside the IR window (ir_valid = 0) the blend modes show the visible image.
//
// PIPELINE (clk_pixel):
//
//   cycle 0 : fusion_coordinate_mapper -> read addresses (combinational)
//   cycle 1 : RAM data available
//             VIS -> RGB888, thermal -> false colour,
//             blend factor, alpha blend, mode selection (all combinational)
//             output RGB registered at the end of cycle 1
//
//   FUSION_LATENCY = 2 cycles from (cx, cy) to red/green/blue: the 2-cycle
//   delay applied in the top-level to hsync, vsync and vde is unchanged.
//
// SUB-MODULES:
//   fusion_coordinate_mapper  : screen pixel -> VIS / IR addresses
//   rgb332_to_rgb888          : RGB332 visible pixel -> RGB888
//   thermal_false_color       : thermal 8 bit -> false colour RGB888
//   thermal_blend_controller  : thermal 8 bit -> blend factor (threshold)
//   alpha_blender             : VIS RGB + IR RGB -> blended RGB
// ============================================================================

module fusion_pipeline #(
    // HDMI active area
    parameter int H_ACTIVE = 640,
    parameter int V_ACTIVE = 480,
    parameter int H_BITS   = $clog2(H_ACTIVE),
    parameter int V_BITS   = $clog2(V_ACTIVE),

    // Visible image
    parameter int VIS_W         = 160,
    parameter int VIS_H         = 120,
    parameter int VIS_ADDR_BITS = $clog2(VIS_W * VIS_H),
    parameter bit VIS_Y8        = 1'b1,     // 1: Y8 grayscale, 0: RGB332 colour

    // Thermal image
    parameter int IR_W          = 80,
    parameter int IR_H          = 80,
    parameter int IR_ADDR_BITS  = $clog2(IR_W * IR_H),

    // Alignment of the IR window (see fusion_coordinate_mapper)
    parameter int IR_COL_OFFSET = 0,
    parameter int IR_ROW_OFFSET = 10,

    // Mirror corrections (1 = read the image reversed on that axis)
    parameter bit VIS_MIRROR_X  = 1'b0,
    parameter bit VIS_FLIP_Y    = 1'b0,
    parameter bit IR_MIRROR_X   = 1'b0,
    parameter bit IR_FLIP_Y     = 1'b0,

    // Threshold-gated blend (MODE_THRESHOLD)
    parameter logic [7:0] IR_THRESHOLD = 8'd80,  // thermal gray level
    parameter logic [2:0] IR_ALPHA_Q   = 3'd2    // 2 = 50 % thermal
)(
    input  logic                     clk_pixel,
    input  logic                     rst_n,

    // Current HDMI pixel
    input  logic [H_BITS-1:0]        cx,
    input  logic [V_BITS-1:0]        cy,
    input  logic                     vde,

    // Selected output (see table above)
    input  logic [2:0]               display_mode,

    // VIS framebuffer read interface
    output logic                     vis_rd_req,
    output logic [VIS_ADDR_BITS-1:0] vis_rd_addr,
    input  logic [7:0]               vis_rd_pixel,
    input  logic                     vis_rd_valid,

    // IR framebuffer read interface
    output logic                     ir_rd_req,
    output logic [IR_ADDR_BITS-1:0]  ir_rd_addr,
    input  logic [7:0]               ir_rd_pixel,
    input  logic                     ir_rd_valid,

    // RGB888 output, valid FUSION_LATENCY cycles after (cx, cy)
    output logic [7:0]               red,
    output logic [7:0]               green,
    output logic [7:0]               blue
);

    // Total latency from (cx, cy) to red/green/blue (documentation only:
    // the matching delay on hsync, vsync and vde is in the top-level).
    localparam int FUSION_LATENCY = 2;

    // Display modes
    localparam logic [2:0] MODE_VIS       = 3'd0;
    localparam logic [2:0] MODE_IR_GRAY   = 3'd1;
    localparam logic [2:0] MODE_IR_COLOR  = 3'd2;
    localparam logic [2:0] MODE_BLEND_50  = 3'd3;
    localparam logic [2:0] MODE_THRESHOLD = 3'd4;

    // ========================================================================
    // Cycle 0: screen coordinates -> framebuffer addresses
    // ========================================================================

    logic vis_valid;   // current screen pixel has a VIS pixel
    logic ir_valid;    // current screen pixel has an IR pixel

    fusion_coordinate_mapper #(
        .H_ACTIVE       (H_ACTIVE),
        .V_ACTIVE       (V_ACTIVE),
        .H_BITS         (H_BITS),
        .V_BITS         (V_BITS),

        .VIS_W          (VIS_W),
        .VIS_H          (VIS_H),
        .VIS_ADDR_BITS  (VIS_ADDR_BITS),

        .IR_W           (IR_W),
        .IR_H           (IR_H),
        .IR_ADDR_BITS   (IR_ADDR_BITS),

        .IR_COL_OFFSET  (IR_COL_OFFSET),
        .IR_ROW_OFFSET  (IR_ROW_OFFSET),

        .VIS_MIRROR_X   (VIS_MIRROR_X),
        .VIS_FLIP_Y     (VIS_FLIP_Y),
        .IR_MIRROR_X    (IR_MIRROR_X),
        .IR_FLIP_Y      (IR_FLIP_Y)
    ) mapper_inst (
        .cx          (cx),
        .cy          (cy),
        .vde         (vde),

        .vis_rd_req  (vis_rd_req),
        .vis_rd_addr (vis_rd_addr),

        .ir_rd_req   (ir_rd_req),
        .ir_rd_addr  (ir_rd_addr),

        .vis_valid   (vis_valid),
        .ir_valid    (ir_valid)
    );

    // ========================================================================
    // Cycle 1: align the validity flags with the RAM data
    // ========================================================================
    // The framebuffer RAMs have 1 cycle of read latency, so the flags
    // computed in cycle 0 are delayed by 1 cycle.
    // ========================================================================

    logic vis_valid_d;
    logic ir_valid_d;

    always_ff @(posedge clk_pixel or negedge rst_n) begin
        if (!rst_n) begin
            vis_valid_d <= 1'b0;
            ir_valid_d  <= 1'b0;
        end
        else begin
            vis_valid_d <= vis_valid;
            ir_valid_d  <= ir_valid;
        end
    end

    // A pixel is used only if it exists (mapper) and the RAM returned it
    logic have_vis;
    logic have_ir;

    assign have_vis = vis_valid_d && vis_rd_valid;
    assign have_ir  = ir_valid_d  && ir_rd_valid;

    // ========================================================================
    // Cycle 1: visible pixel -> RGB888
    // ========================================================================
    // Y8     : R = G = B = Y
    // RGB332 : bit replication (rgb332_to_rgb888)
    // ========================================================================

    logic [7:0] vis_332_r, vis_332_g, vis_332_b;

    rgb332_to_rgb888 vis_rgb332_inst (
        .pixel_in (vis_rd_pixel),
        .red      (vis_332_r),
        .green    (vis_332_g),
        .blue     (vis_332_b)
    );

    logic [7:0] vis_r, vis_g, vis_b;

    assign vis_r = VIS_Y8 ? vis_rd_pixel : vis_332_r;
    assign vis_g = VIS_Y8 ? vis_rd_pixel : vis_332_g;
    assign vis_b = VIS_Y8 ? vis_rd_pixel : vis_332_b;

    // ========================================================================
    // Cycle 1: thermal pixel -> gray level and false colour
    // ========================================================================

    logic [7:0] ir_gray;                 // thermal pixel as gray level
    logic [7:0] ir_r, ir_g, ir_b;        // thermal false colour

    assign ir_gray = ir_rd_pixel;

    thermal_false_color false_color_inst (
        .thermal_in (ir_rd_pixel),
        .red        (ir_r),
        .green      (ir_g),
        .blue       (ir_b)
    );

    // ========================================================================
    // Cycle 1: blend factor
    // ========================================================================
    // MODE_BLEND_50  : fixed 50 % wherever the IR pixel exists
    // MODE_THRESHOLD : decided by thermal_blend_controller
    // other modes    : not used
    // ========================================================================

    logic [2:0] alpha_threshold;         // from the threshold controller
    logic [2:0] alpha_q;                 // blend factor actually applied

    thermal_blend_controller #(
        .THRESHOLD  (IR_THRESHOLD),
        .ALPHA_Q    (IR_ALPHA_Q)
    ) blend_controller_inst (
        .thermal_in (ir_rd_pixel),
        .ir_present (have_ir),
        .alpha_q    (alpha_threshold)
    );

    always_comb begin
        case (display_mode)
            MODE_BLEND_50:  alpha_q = have_ir ? 3'd2 : 3'd0;
            MODE_THRESHOLD: alpha_q = alpha_threshold;
            default:        alpha_q = 3'd0;
        endcase
    end

    // ========================================================================
    // Cycle 1: alpha blend of VIS and thermal false colour
    // ========================================================================

    logic [7:0] blend_r, blend_g, blend_b;

    alpha_blender blender_inst (
        .vis_r   (vis_r),
        .vis_g   (vis_g),
        .vis_b   (vis_b),

        .ir_r    (ir_r),
        .ir_g    (ir_g),
        .ir_b    (ir_b),

        .alpha_q (alpha_q),

        .out_r   (blend_r),
        .out_g   (blend_g),
        .out_b   (blend_b)
    );

    // ========================================================================
    // Cycle 1: output selection (combinational)
    // ========================================================================

    logic [7:0] next_r, next_g, next_b;

    always_comb begin
        // Default: black (blanking, or no source pixel available)
        next_r = 8'd0;
        next_g = 8'd0;
        next_b = 8'd0;

        case (display_mode)

            MODE_VIS: begin
                if (have_vis) begin
                    next_r = vis_r;
                    next_g = vis_g;
                    next_b = vis_b;
                end
            end

            MODE_IR_GRAY: begin
                if (have_ir) begin
                    next_r = ir_gray;
                    next_g = ir_gray;
                    next_b = ir_gray;
                end
            end

            MODE_IR_COLOR: begin
                if (have_ir) begin
                    next_r = ir_r;
                    next_g = ir_g;
                    next_b = ir_b;
                end
            end

            MODE_BLEND_50,
            MODE_THRESHOLD: begin
                // alpha_q is already 0 where there is no IR pixel or the
                // pixel is below the threshold: the blender then returns VIS
                if (have_vis) begin  //‘have_ir’ is missing because it's already handled in thermal_blend_controller: ‘alpha_q=0’ if ‘have_ir=0’
                    next_r = blend_r;
                    next_g = blend_g;
                    next_b = blend_b;
                end
            end

            default: begin          
                // Reserved modes: test pattern from the screen coordinates
                // (red = horizontal ramp, green = vertical ramp, blue = mix)
                next_r = cx[7:0];
                next_g = cy[7:0];
                next_b = cx[7:0] ^ cy[7:0];
            end

        endcase
    end

    // ========================================================================
    // End of cycle 1: registered RGB output
    // ========================================================================
    // Why this register (besides the synchronous RAM read):
    // - Timing: it splits the long combinational path (VIS conversion,
    //   palette, blender, mode mux) from the TMDS encoder logic, so each part
    //   fits in one 40 ns clk_pixel period.
    // - Clean signal: the encoder receives a stable value for the whole
    //   cycle, without the glitches of the combinational logic.
    // - Known latency: RAM (1) + this register (1) = FUSION_LATENCY = 2,
    //   matched by the 2-cycle delay on hsync/vsync/vde in the top-level.
    //   Removing it changes the latency and requires a new sync delay.

    always_ff @(posedge clk_pixel or negedge rst_n) begin
        if (!rst_n) begin
            red   <= 8'd0;
            green <= 8'd0;
            blue  <= 8'd0;
        end
        else begin
            red   <= next_r;
            green <= next_g;
            blue  <= next_b;
        end
    end

endmodule
