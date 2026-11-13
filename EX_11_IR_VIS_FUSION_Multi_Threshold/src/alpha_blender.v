// ============================================================================
// MODULE: alpha_blender
// DESCRIPTION: Mixes a visible RGB pixel and a thermal RGB pixel, channel by
// channel, with a blend factor expressed in quarters:
//
//   out = (1 - alpha) * VIS + alpha * IR
//
//   alpha_q = 0 : out = VIS                       (  0 % IR)
//   alpha_q = 1 : out = (3*VIS + IR)   / 4        ( 25 % IR)
//   alpha_q = 2 : out = (VIS + IR)     / 2        ( 50 % IR)
//   alpha_q = 3 : out = (VIS + 3*IR)   / 4        ( 75 % IR)
//   alpha_q = 4 : out = IR                        (100 % IR)
//
// Only additions and shifts are used (x3 = x2 + x1, /4 = >> 2): no
// multipliers. The sums use 10 bits (maximum 4 * 255 = 1020), so they never
// overflow and the result is always between 0 and 255: no saturation needed.
//
// LATENCY: 0 clock cycles (purely combinational).
// ============================================================================

module alpha_blender (
    input  logic [7:0] vis_r, vis_g, vis_b,   // visible pixel (RGB888)
    input  logic [7:0] ir_r,  ir_g,  ir_b,    // thermal false colour (RGB888)
    input  logic [2:0] alpha_q,               // blend factor in quarters

    output logic [7:0] out_r, out_g, out_b
);

    // ========================================================================
    // Blend of one colour channel
    // ========================================================================

    function automatic logic [7:0] blend_channel(
        input logic [7:0] vis,
        input logic [7:0] ir,
        input logic [2:0] alpha
    );
        logic [9:0] v;      // vis extended to 10 bits
        logic [9:0] t;      // ir  extended to 10 bits
        logic [9:0] sum;
        begin
            v = {2'b00, vis};
            t = {2'b00, ir};

            case (alpha)
                3'd0: blend_channel = vis;                          //   0 %

                3'd1: begin                                         //  25 %
                    sum           = (v << 1) + v + t;               // 3*VIS + IR
                    blend_channel = sum[9:2];                       // / 4
                end

                3'd2: begin                                         //  50 %
                    sum           = v + t;                          // VIS + IR
                    blend_channel = sum[8:1];                       // / 2
                end

                3'd3: begin                                         //  75 %
                    sum           = v + (t << 1) + t;               // VIS + 3*IR
                    blend_channel = sum[9:2];                       // / 4
                end

                default: blend_channel = ir;                        // 100 %
            endcase
        end
    endfunction

    // ========================================================================
    // Same blend factor on the three channels
    // ========================================================================

    assign out_r = blend_channel(vis_r, ir_r, alpha_q);
    assign out_g = blend_channel(vis_g, ir_g, alpha_q);
    assign out_b = blend_channel(vis_b, ir_b, alpha_q);

endmodule
