// ============================================================================
// MODULE: fusion_coordinate_mapper
// DESCRIPTION: For the HDMI pixel currently being drawn (cx, cy), computes
// which pixel of the VIS framebuffer and which pixel of the IR framebuffer
// correspond to the same point of the scene.
//
// Geometry (option B: the OV5640 field of view is matched to the VIGIL80 one):
//
//   VIS: 160 x 120 image, scale x4  -> 640 x 480 (whole screen)
//   IR : 80 x 60 window of the 80 x 80 frame, scale x8 -> 640 x 480
//
//   The IR window starts at row IR_ROW_OFFSET and column IR_COL_OFFSET.
//   Default: rows 10 ... 69, i.e. 10 rows discarded at the top and 10 at the
//   bottom (the IR window is centred in the IR frame).
//
//   Screen -> VIS : vis_x = cx / 4                   vis_y = cy / 4
//   Screen -> IR  : ir_x  = cx / 8 + IR_COL_OFFSET   ir_y  = cy / 8 + IR_ROW_OFFSET
//   (plus the optional mirror, applied before the offsets)
//
// The divisions are right shifts because both scale factors are powers of 2.
//
// The two offsets are the alignment controls: they move the IR image with
// respect to the VIS image (parallax correction). If an offset moves the IR
// window outside the IR frame, ir_valid = 0 for that screen area and only the
// VIS image is available there.
//
// Offset sign:
//   IR_COL_OFFSET > 0 : the IR image moves to the left on the screen
//   IR_COL_OFFSET < 0 : the IR image moves to the right on the screen
//   The window already uses all 80 IR columns, so a horizontal correction
//   in both directions needs negative values too.
//   IR_ROW_OFFSET = 0 ... 20 keeps the 60-row window inside the 80 rows,
//   so the vertical correction normally uses only positive values.
//   Offsets must stay within +/- the IR image size.
//
// LATENCY: 0 clock cycles (purely combinational).
// The framebuffer read adds 1 cycle: the module using this mapper must delay
// vis_valid / ir_valid by 1 cycle to align them with the RAM data.
// ============================================================================

module fusion_coordinate_mapper #(
    // HDMI active area
    parameter int H_ACTIVE = 640,
    parameter int V_ACTIVE = 480,
    parameter int H_BITS   = $clog2(H_ACTIVE),
    parameter int V_BITS   = $clog2(V_ACTIVE),

    // Visible image
    parameter int VIS_W           = 160,
    parameter int VIS_H           = 120,
    parameter int VIS_SCALE_SHIFT = 2,                  // scale = 2^2 = 4
    parameter int VIS_ADDR_BITS   = $clog2(VIS_W * VIS_H),

    // Thermal image
    parameter int IR_W            = 80,
    parameter int IR_H            = 80,
    parameter int IR_SCALE_SHIFT  = 3,                  // scale = 2^3 = 8
    parameter int IR_ADDR_BITS    = $clog2(IR_W * IR_H),

    // Position of the IR window inside the 80 x 80 IR frame (IR pixels)
    parameter int IR_COL_OFFSET   = 0,                  // columns 0 ... 79
    parameter int IR_ROW_OFFSET   = 10,                 // rows 10 ... 69

    // Mirror corrections (1 = read the image reversed on that axis)
    parameter bit VIS_MIRROR_X    = 1'b0,
    parameter bit VIS_FLIP_Y      = 1'b0,
    parameter bit IR_MIRROR_X     = 1'b0,
    parameter bit IR_FLIP_Y       = 1'b0
)(
    // Current HDMI pixel
    input  logic [H_BITS-1:0]        cx,
    input  logic [V_BITS-1:0]        cy,
    input  logic                     vde,

    // VIS framebuffer read request
    output logic                     vis_rd_req,
    output logic [VIS_ADDR_BITS-1:0] vis_rd_addr,

    // IR framebuffer read request
    output logic                     ir_rd_req,
    output logic [IR_ADDR_BITS-1:0]  ir_rd_addr,

    // 1 when the current screen pixel has a corresponding VIS / IR pixel
    output logic                     vis_valid,
    output logic                     ir_valid
);

    // Size of the IR window shown on screen (80 x 60 with scale x8).
    // Used BEFORE the offsets, to mirror the window.
    // (VIS needs no equivalent constant: the VIS window is the whole
    //  160 x 120 image, so VIS_W / VIS_H are used directly.)
    localparam int IR_WIN_W = H_ACTIVE >> IR_SCALE_SHIFT;   // 640 / 8 = 80
    localparam int IR_WIN_H = V_ACTIVE >> IR_SCALE_SHIFT;   // 480 / 8 = 60

    // Width of the source-image coordinates:
    // bits needed by the image ($clog2) + 2 bits:
    //   +1 sign bit : offsets and mirror can give negative values
    //   +1 margin   : to cover values beyond the image (blanking area, offsets)
    localparam int VIS_X_BITS = $clog2(VIS_W) + 2;   // 8 + 2 = 10 bits
    localparam int VIS_Y_BITS = $clog2(VIS_H) + 2;   // 7 + 2 =  9 bits
    localparam int IR_X_BITS  = $clog2(IR_W)  + 2;   // 7 + 2 =  9 bits
    localparam int IR_Y_BITS  = $clog2(IR_H)  + 2;   // 7 + 2 =  9 bits

    // ========================================================================
    // Source-image coordinates (signed)
    // ========================================================================
    // They are SIGNED so that a negative result (negative offset, mirror)
    // stays negative and the ">= 0" checks work.

    logic signed [VIS_X_BITS-1:0] vis_x;   // VIS column (0 ... 159 when valid)
    logic signed [VIS_Y_BITS-1:0] vis_y;   // VIS row    (0 ... 119 when valid)
    logic signed [IR_X_BITS-1:0]  ir_x;    // IR column  (0 ... 79 when valid)
    logic signed [IR_Y_BITS-1:0]  ir_y;    // IR row     (0 ... 79 when valid)

    always_comb begin

        // --------------------------------------------------------------------
        // 1. Screen -> VIS: divide by the VIS scale (x4), optional mirror
        // --------------------------------------------------------------------
        vis_x = VIS_X_BITS'(cx >> VIS_SCALE_SHIFT);
        vis_y = VIS_Y_BITS'(cy >> VIS_SCALE_SHIFT);

        if (VIS_MIRROR_X) vis_x = (VIS_W - 1) - vis_x;
        if (VIS_FLIP_Y)   vis_y = (VIS_H - 1) - vis_y;

        // --------------------------------------------------------------------
        // 2. Screen -> IR: divide by the IR scale (x8), optional mirror
        //    inside the 80 x 60 window, then move the window
        // --------------------------------------------------------------------
        ir_x = IR_X_BITS'(cx >> IR_SCALE_SHIFT);    // 0 ... IR_WIN_W-1 on screen
        ir_y = IR_Y_BITS'(cy >> IR_SCALE_SHIFT);    // 0 ... IR_WIN_H-1 on screen

        // Mirror relative to the WINDOW (80 x 60), not to the full 80 x 80
        // frame: rows 0 ... 59 become 59 ... 0
        if (IR_MIRROR_X) ir_x = (IR_WIN_W - 1) - ir_x;
        if (IR_FLIP_Y)   ir_y = (IR_WIN_H - 1) - ir_y;

        // From here on, ir_x / ir_y are positions in the full 80 x 80 frame
        ir_x = ir_x + IR_COL_OFFSET;
        ir_y = ir_y + IR_ROW_OFFSET;

        // --------------------------------------------------------------------
        // 3. Validity: active video and coordinates inside the source image
        // --------------------------------------------------------------------
        // VIS: no offset, so in the active area vis_x / vis_y are never
        // negative: only the upper limit is checked. (Negative values can
        // appear only during blanking, where vde = 0.)
        vis_valid = vde &&
                    (vis_x < VIS_W) && (vis_y < VIS_H);

        // IR: offsets and mirror can give negative values -> both limits.
        // The limits are IR_W / IR_H (80 x 80, the image stored in RAM) and
        // not IR_WIN_W / IR_WIN_H (80 x 60, the window on screen): after the
        // offset the coordinates refer to the full frame (default rows
        // 10 ... 69, all valid; with IR_WIN_H rows 60 ... 69 would be lost).
        ir_valid  = vde &&
                    (ir_x >= 0) && (ir_x < IR_W) &&
                    (ir_y >= 0) && (ir_y < IR_H);

        // --------------------------------------------------------------------
        // 4. Framebuffer addresses (address = y * W + x)
        //    The multiplication by a constant is reduced to shifts and adds by synthesis.
        //    A RAM is read only when its pixel exists.
        // --------------------------------------------------------------------
        vis_rd_req  = vis_valid;
        vis_rd_addr = vis_valid ? VIS_ADDR_BITS'(vis_y * VIS_W + vis_x) : '0;

        ir_rd_req   = ir_valid;
        ir_rd_addr  = ir_valid  ? IR_ADDR_BITS'(ir_y * IR_W + ir_x)     : '0;
    end

endmodule
