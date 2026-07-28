// ============================================================================
// MODULE: double_framebuffer_gowin_sdp
// DESCRIPTION:
// Double framebuffer using two Gowin_SDP RAM IPs.
//
// RAM0 and RAM1 are used as ping-pong buffers. The buffer swap is performed only at rd_swap_point.
//
// Write side:
// - clocked by VIGIL80 video_sck
// - writes incoming camera pixels
//
// Read side:
// - clocked by HDMI clk_pixel
// - provides pixels to the HDMI renderer
//
// 
// IMPORTANT: Gowin_SDP RAM has synchronous read access: after the request of data (=high re_req), 
// the data will be present in rd_data with a one-clock-cycle delay (rd_valid indicates that the data is available)
// ============================================================================

module double_framebuffer_gowin_sdp #(
    parameter int FRAME_PIX     = 6400,
    parameter int ADDR_BITS     = $clog2(FRAME_PIX)
)(
    input  logic rst_n,

    // ========================================================================
    // Write side - camera domain
    // ========================================================================
    input  logic wr_clk,          //clock by camera
    input  logic wr_valid,        //permission to write single cell
    input  logic [ADDR_BITS-1:0] wr_addr,
    input  logic [7:0] wr_data,
    input  logic wr_frame_done,   //high when the frame is completed -> swap frambuffer

    output logic wr_allow,        //write permission given by the double_framebuffer to the SPI receiver module
                                  //wr_allow = 1 -> the new frame can be saved
                                  //wr_allow = 0 -> the frame received must be discarded because the framebuffer isn't free
                                  //This is to prevent the camera from overwriting the buffer while HDMI is reading 

    // ========================================================================
    // Read side - HDMI domain
    // ========================================================================
    input  logic rd_clk,            
    input  logic rd_swap_point,   //if high, swap framebuffer
    input  logic rd_req,
    input  logic [ADDR_BITS-1:0] rd_addr,

    output logic [7:0] rd_data,
    output logic rd_valid,        //indicates that rd_data is valid

    output logic frame_available  //DEBUG SIGNAL: high when arrives at least one complete frame 
);

    // ========================================================================
    // Bank control
    // ========================================================================

    logic wr_bank;             // buffer currently written by camera (0: write RAM0; 1: write RAM1)
    logic rd_bank;             // buffer currently read by camera    (0: read RAM0 ; 1: read RAM1)

    logic completed_bank_wr;   // last completely written bank
    logic frame_toggle_wr;     // toggled when a new frame is complete

    logic pending_valid_rd;    // indicates that one framebuffer is ready to be displayed (camera has finished writing it) 
                               // but is pending because the HDMI is still displaying the previous one 
    logic pending_bank_rd;     // indicates which of the two RAMs is ready to be displayed

    // At reset:
    // - HDMI reads RAM0
    // - camera writes RAM1
    // This avoids read/write collision immediately after reset.

    // ========================================================================
    // Two-step syncronization of rd_bank from the HDMI/read clock domain (rd_clock) to the camera/write clock domain (wr_clk).
    // rd_bank is generated with rd_clk, but used with wr_clk to compute wr_allow.
    // Since the two clocks are asynchronous, rd_bank may change close to a wr_clk edge
    // and violate setup/hold times of the first FF(rd_bank_wr_meta) and may cause metastability.
    // The second FF (rd_bank_wr_sync) gives the first FF one clock cycle to settle providing 
    // a stable and safe version of rd_bank for the write clock domain.
    //
    //  rd_bank -> rd_bank_wr_meta -> rd_bank_wr_sync
    // ========================================================================

    logic rd_bank_wr_meta;   //first FF. It may be metastable
    logic rd_bank_wr_sync;   //second FF. Safe syncronized copy of rd_bank in wr_clk domain

    always_ff @(posedge wr_clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_bank_wr_meta <= 1'b0;
            rd_bank_wr_sync <= 1'b0;
        end else begin
            rd_bank_wr_meta <= rd_bank;
            rd_bank_wr_sync <= rd_bank_wr_meta;
        end
    end

    // The camera can write the framebuffer only if the buffer that want to write isn't the one that HDMI is reading
    assign wr_allow = (wr_bank != rd_bank_wr_sync);  

    // ========================================================================
    // Write-side bank update
    // ========================================================================

    always_ff @(posedge wr_clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_bank           <= 1'b1;  //after reset write RAM1
            completed_bank_wr <= 1'b0;
            frame_toggle_wr   <= 1'b0;
        end 
        else begin
            if (wr_frame_done && wr_allow) begin
                completed_bank_wr <= wr_bank;       //Indicate which buffer has just been completed
                frame_toggle_wr   <= ~frame_toggle_wr;
                wr_bank           <= ~wr_bank;      //the write operation switches to the other buffer
            end
        end
    end

    // ========================================================================
    // Synchronize completed-frame event from write clock domain (wr_clk) into read clock domain (rd_clk).
    // ========================================================================

    logic frame_toggle_rd_meta;
    logic frame_toggle_rd_sync;
    logic frame_toggle_rd_last;

    logic completed_bank_rd_meta;
    logic completed_bank_rd_sync;

    always_ff @(posedge rd_clk or negedge rst_n) begin
        if (!rst_n) begin
            frame_toggle_rd_meta <= 1'b0;
            frame_toggle_rd_sync <= 1'b0;
            frame_toggle_rd_last <= 1'b0;

            completed_bank_rd_meta <= 1'b0;
            completed_bank_rd_sync <= 1'b0;

            pending_valid_rd <= 1'b0;
            pending_bank_rd  <= 1'b0;

            rd_bank <= 1'b0;       //after reset read RAM0 

            frame_available <= 1'b0;
        end 
        else begin
            frame_toggle_rd_meta <= frame_toggle_wr;
            frame_toggle_rd_sync <= frame_toggle_rd_meta;

            completed_bank_rd_meta <= completed_bank_wr;
            completed_bank_rd_sync <= completed_bank_rd_meta;

            // If the toggle has changed, a new complete frame has arrived
            if (frame_toggle_rd_sync != frame_toggle_rd_last) begin
                frame_toggle_rd_last <= frame_toggle_rd_sync;
                pending_valid_rd     <= 1'b1;                    //indicates that there is a new buffer ready to be displayed
                pending_bank_rd      <= completed_bank_rd_sync;  //it keeps track of which RAM is ready
                frame_available      <= 1'b1;
            end

            // Swap displayed buffer only if a new frame is starting (rd_swap_point, high when cx==0 && cy==0)
            // and there is a buffer ready to be displayed (pending_valid_rd)
            if (rd_swap_point && pending_valid_rd) begin
                rd_bank          <= pending_bank_rd;
                pending_valid_rd <= 1'b0;
            end
        end
    end

    // ========================================================================
    // RAM enables
    // ========================================================================

    logic ram0_wr_en;
    logic ram1_wr_en;

    logic ram0_rd_en;
    logic ram1_rd_en;

    assign ram0_wr_en = wr_valid && wr_allow && (wr_bank == 1'b0);
    assign ram1_wr_en = wr_valid && wr_allow && (wr_bank == 1'b1);

    assign ram0_rd_en = rd_req && (rd_bank == 1'b0);
    assign ram1_rd_en = rd_req && (rd_bank == 1'b1);

    // ========================================================================
    // RAM outputs
    // ========================================================================

    logic [7:0] ram0_dout;
    logic [7:0] ram1_dout;

    // Gowin_SDP read output is synchronous.
    // Delay selected bank and read request by one rd_clk cycle.
    logic rd_bank_d;
    logic rd_req_d;

    always_ff @(posedge rd_clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_bank_d <= 1'b0;
            rd_req_d  <= 1'b0;
        end 
        else begin
            rd_req_d <= rd_req;

            if (rd_req) begin
                rd_bank_d <= rd_bank;  //if a data is required, records which RAM was requested
            end
        end
    end

    assign rd_valid = rd_req_d;  // If in the previous cycle a data had been requested, the data is now valid


    always_comb begin
        if (rd_bank_d == 1'b0)
            rd_data = ram0_dout;
        else
            rd_data = ram1_dout;
    end

    // ========================================================================
    // Gowin SDP RAM 0
    // ========================================================================
    // Port A: write port
    // Port B: read port
    // ========================================================================

    Gowin_SDP ram0 (
        .dout   (ram0_dout),      // output [7:0] dout

        .clka   (wr_clk),         // input clka
        .cea    (ram0_wr_en),     // input cea
        .reseta (~rst_n),         // input reseta, active high

        .clkb   (rd_clk),         // input clkb
        .ceb    (ram0_rd_en),     // input ceb
        .resetb (~rst_n),         // input resetb, active high
        .oce    (1'b1),           // input oce

        .ada    (wr_addr),        // write address
        .din    (wr_data),        // input [7:0] din
        .adb    (rd_addr)         // read address
    );

    // ========================================================================
    // Gowin SDP RAM 1
    // ========================================================================

    Gowin_SDP ram1 (
        .dout   (ram1_dout),      // output [7:0] dout

        .clka   (wr_clk),         // input clka
        .cea    (ram1_wr_en),     // input cea
        .reseta (~rst_n),         // input reseta, active high

        .clkb   (rd_clk),         // input clkb
        .ceb    (ram1_rd_en),     // input ceb
        .resetb (~rst_n),         // input resetb, active high
        .oce    (1'b1),           // input oce

        .ada    (wr_addr),        // write address
        .din    (wr_data),        // input [7:0] din
        .adb    (rd_addr)         // read address
    );

endmodule