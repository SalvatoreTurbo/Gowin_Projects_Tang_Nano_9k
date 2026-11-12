// ============================================================================
// MODULE: thermal_false_color
// DESCRIPTION: Converts an 8-bit thermal intensity into an RGB888 false
// colour. Hotter pixels get "warmer" and brighter colours.
//
// Palette (same as the previous thermal_hdmi_renderer of EX_6):
//
//   thermal   0 ...  63 : black  -> red
//   thermal  64 ... 127 : red    -> yellow
//   thermal 128 ... 191 : yellow -> white
//   thermal 192 ... 255 : white
//
// Inside each range the varying channel follows a ramp 0, 4, 8, ... 252,
// obtained from the 6 least significant bits: {thermal[5:0], 2'b00}.
// No lookup table is needed: the palette uses only bit selections and
// multiplexers, so it does not use any BSRAM.
//
// LATENCY: 0 clock cycles (purely combinational).
// ============================================================================

module thermal_false_color (
    input  logic [7:0] thermal_in,   // 8-bit thermal intensity

    output logic [7:0] red,
    output logic [7:0] green,
    output logic [7:0] blue
);

    // Local ramp inside the current range: 0, 4, 8, ... 252
    logic [7:0] ramp;

    assign ramp = {thermal_in[5:0], 2'b00};

    always_comb begin
        case (thermal_in[7:6])

            // 0 ... 63: black -> red
            2'b00: begin
                red   = ramp;
                green = 8'd0;
                blue  = 8'd0;
            end

            // 64 ... 127: red -> yellow
            2'b01: begin
                red   = 8'hFF;
                green = ramp;
                blue  = 8'd0;
            end

            // 128 ... 191: yellow -> white
            2'b10: begin
                red   = 8'hFF;
                green = 8'hFF;
                blue  = ramp;
            end

            // 192 ... 255: white
            default: begin
                red   = 8'hFF;
                green = 8'hFF;
                blue  = 8'hFF;
            end

        endcase
    end

endmodule
