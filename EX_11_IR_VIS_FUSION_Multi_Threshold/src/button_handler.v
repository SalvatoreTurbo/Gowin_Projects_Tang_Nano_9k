// ============================================================================
// MODULE: button_handler
// DESCRIPTION: Push button (active low) sampled once per HDMI frame.
//
// - btn_n is asynchronous: one synchronizer FF brings it into the clk domain;
// - the synchronized level is sampled only when sample_en = 1
//   (HDMI frame start, every 16.8 ms): contact bounces last a few ms,
//   so sampling once per frame also acts as a debounce;
// - pressed = 1 during the sample_en cycle in which the transition
//   released -> pressed is seen. Holding the button down gives one pulse.
//
// Same logic previously written directly in the top-level for the mode
// button, moved into a module so that it can be used for several buttons.
// The user of "pressed" updates its register on the same clock edge as
// before (frame start), so the behaviour of the old code is unchanged.
// ============================================================================

module button_handler (
    input  logic clk,
    input  logic rst_n,

    input  logic sample_en,  // 1 clock pulse per frame (hdmi_frame_start)
    input  logic btn_n,      // button pin, active low (pull-up in the .cst)

    output logic pressed     // 1-cycle pulse: button has just been pressed
);

    logic btn_meta;   // synchronizer FF (btn_n is asynchronous)
    logic btn_prev;   // button level at the previous frame

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            btn_meta <= 1'b1;     // 1 = released
            btn_prev <= 1'b1;
        end
        else begin
            btn_meta <= btn_n;

            if (sample_en)
                btn_prev <= btn_meta;
        end
    end

    // released at the previous frame, pressed now
    assign pressed = sample_en && btn_prev && !btn_meta;

endmodule
