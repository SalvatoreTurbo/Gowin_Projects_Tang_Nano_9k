// ============================================================================
// MODULE: thermal_multilevel_controller
// DESCRIPTION: Dynamic blend factor driven by the thermal intensity
// (multi-level thermal saliency). The hotter the pixel, the more the thermal
// false colour covers the visible image.
//
// The thresholds are passed as an array, sorted in ascending order:
//
//   THRESHOLDS[0] < THRESHOLDS[1] < ... < THRESHOLDS[NUM_THRESHOLDS-1]
//
// The output level is the number of thresholds reached by the pixel:
//
//   thermal_in < THRESHOLDS[0]                      -> level = 0
//   THRESHOLDS[i-1] <= thermal_in < THRESHOLDS[i]   -> level = i
//   thermal_in >= THRESHOLDS[NUM_THRESHOLDS-1]      -> level = NUM_THRESHOLDS
//
// With NUM_THRESHOLDS = 4 the level is directly the blend factor in quarters
// used by alpha_blender:
//   0 = 0 %, 1 = 25 %, 2 = 50 %, 3 = 75 %, 4 = 100 % thermal
//
// NOTE: changing NUM_THRESHOLDS also changes the meaning of one level
// (1/NUM_THRESHOLDS instead of 1/4): alpha_blender must then be adapted.
//
// The thresholds are gray levels of the 8-bit thermal image, i.e. levels
// relative to the conversion base (TEMP_MIN, or the automatic offset once it
// is implemented), not absolute temperatures. With TEMP_SHIFT = 2 one level
// corresponds to about 0.04 K (e.g. 30 levels = about 1.2 K).
//
// LATENCY: 0 clock cycles (purely combinational).
// ============================================================================

module thermal_multilevel_controller #(
    parameter int NUM_THRESHOLDS = 4,

    // Thresholds, ascending. In the concatenation the LAST value is
    // element [0]: {8'd170, 8'd140, 8'd110, 8'd80} -> [0] = 80 ... [3] = 170
    parameter logic [NUM_THRESHOLDS-1:0][7:0] THRESHOLDS = {8'd170, 8'd140, 8'd110, 8'd80},

    // Width of the output level (0 ... NUM_THRESHOLDS)
    localparam int LEVEL_BITS = $clog2(NUM_THRESHOLDS + 1)
)(
    input  logic [7:0]            thermal_in,   // 8-bit thermal intensity
    input  logic                  ir_present,   // 1 if a thermal pixel exists here

    output logic [LEVEL_BITS-1:0] level         // thresholds reached (0 ... N)
);

    always_comb begin
        level = '0;                              // default: visible only

        if (ir_present) begin
            // Thresholds are ascending: the last one reached gives the level
            for (int i = 0; i < NUM_THRESHOLDS; i++) begin
                if (thermal_in >= THRESHOLDS[i])
                    level = LEVEL_BITS'(i + 1);
            end
        end
    end

endmodule
