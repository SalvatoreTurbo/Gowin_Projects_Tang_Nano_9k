// ============================================================================
// MODULE: thermal_blend_controller
// DESCRIPTION: Decides, for each pixel, how much of the thermal false colour
// is mixed into the visible image (threshold gating, "mask-guided fusion").
//
// CURRENT VERSION (single threshold):
//
//   thermal_in >  THRESHOLD  ->  alpha_q = ALPHA_Q   (pixel is coloured)
//   thermal_in <= THRESHOLD  ->  alpha_q = 0         (visible image only)
//
// alpha_q is the blend factor in quarters (see alpha_blender):
//   0 = 0 %, 1 = 25 %, 2 = 50 %, 3 = 75 %, 4 = 100 % thermal
//
// THRESHOLD is a gray level of the 8-bit thermal image, i.e. a level
// relative to the conversion base (TEMP_MIN, or the automatic offset once it
// is implemented), not an absolute temperature. With TEMP_SHIFT = 2 one
// level corresponds to about 0.04 K.
//
// FUTURE VERSION (dynamic alpha): several thresholds S1 < S2 < S3 < S4 select
// alpha_q = 0 ... 4, so that hotter regions cover the visible image more.
// Only the inside of this module will change.
//
// LATENCY: 0 clock cycles (purely combinational).
// ============================================================================

module thermal_blend_controller #(
    parameter logic [7:0] THRESHOLD = 8'd80,   // thermal gray level
    parameter logic [2:0] ALPHA_Q   = 3'd2     // blend above threshold (2 = 50 %)
)(
    input  logic [7:0] thermal_in,   // 8-bit thermal intensity
    input  logic       ir_present,   // 1 if a thermal pixel exists here

    output logic [2:0] alpha_q       // blend factor, in quarters (0 ... 4)
);

    always_comb begin
        if (ir_present && (thermal_in > THRESHOLD))
            alpha_q = ALPHA_Q;       // hot pixel: mix the false colour
        else
            alpha_q = 3'd0;          // cold pixel or no IR: visible only
    end

endmodule
