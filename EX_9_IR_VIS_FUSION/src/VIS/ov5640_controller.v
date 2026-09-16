// ============================================================================
// MODULE: ov5640_controller
// DESCRIPTION: Controls the complete OV5640 startup and configuration sequence.
//
// This module:
// 1. Places the camera in power-down and reset.
// 2. Releases power-down.
// 3. Releases hardware reset.
// 4. Reads the configuration ROM.
// 5. Writes each register through the SCCB master.
// 6. Executes fixed 10 ms delay entries.
// 7. Sets camera_initialized when configuration is complete.
//
// The low-level SCCB bit transmission is delegated to sccb_write_master.
// ============================================================================

module ov5640_controller #(
    parameter int CLK_HZ  = 27_000_000,   // ≈ 37 ns
    parameter int SCCB_HZ = 100_000       //SCCB bus sets at 100 kHz
)(
    input  logic clk,   //connected to 27MHz board clk
    input  logic rst_n,

    // OV5640 hardware-control signals
    output logic ov_reset_n,
    output logic ov_pwdn,   //puts the camera into low-power mode and disables operation

    // SCCB interface
    inout  wire ov_scl,
    inout  wire ov_sda,

    // Status
    output logic camera_initialized
);

    // OV5640 7-bit SCCB address.
    // The transmitted write byte will be {7'h3C, 1'b0} = 8'h78.
    localparam logic [6:0] OV5640_ADDR = 7'h3C;

    // All delays in the sequence are fixed at 10 ms.
    //since 1 / 100 s = 10 ms, we have to wait 27.000.000 / 100 = 270.000 cycles to wait 10 ms
    localparam int DELAY_CYCLES   = CLK_HZ / 100;
    localparam int DELAY_CNT_BITS = $clog2(DELAY_CYCLES + 1);

    // Configuration ROM index width.
    localparam int ROM_ADDR_BITS = 9;

    // Special ROM addresses.
    localparam logic [15:0] ROM_DELAY = 16'hFFFE;
    localparam logic [15:0] ROM_END   = 16'hFFFF;

    // =========================================================================
    // Main camera FSM
    // =========================================================================

    typedef enum logic [3:0] {
        CAM_POWER_DOWN,
        CAM_RESET_ACTIVE,
        CAM_RESET_RELEASED,

        CFG_LOAD,
        CFG_START_WRITE,
        CFG_WAIT_WRITE,
        CFG_DELAY,

        CAM_READY,
        CAM_ERROR
    } state_t;

    state_t state;

    //FSM typical sequence:
    //CAM_POWER_DOWN
    //    Camera in PWDN e reset per 10 ms
    //          ↓
    //CAM_RESET_ACTIVE
    //    Esce da PWDN, rimane in reset per 10 ms
    //          ↓
    //CAM_RESET_RELEASED
    //    Reset rilasciato, attesa 10 ms
    //          ↓
    //CFG_LOAD
    //    Legge una entry della ROM
    //          ↓
    //CFG_START_WRITE
    //    Avvia una scrittura SCCB
    //          ↓
    //CFG_WAIT_WRITE
    //    Aspetta ACK e fine transazione
    //          ↓
    //CFG_LOAD
    //    Passa al registro successivo
    //          ↓
    //CAM_READY
    //    camera_initialized = 1

    // One shared counter is sufficient because delays never run simultaneously.
    logic [DELAY_CNT_BITS-1:0] delay_counter;

    // =========================================================================
    // Configuration ROM
    // =========================================================================

    logic [ROM_ADDR_BITS-1:0] rom_index;  //Current configuration index

    logic [15:0] current_reg_addr;
    logic [7:0]  current_reg_data;
    logic [23:0] rom_entry;               //[23:8] = register address, 16 bit + [7:0]  = data, 8 bit

    
    assign current_reg_addr = rom_entry[23:8];
    assign current_reg_data = rom_entry[7:0];

// Adapted from the user's known-good OV5640 color configuration.
// Target: 160x120 DVP RGB565, double framebuffer stores RGB332.
// Required capture settings: VSYNC_ACTIVE=1, HREF_ACTIVE=1.
// Required byte assembly: rgb565_to_rgb332({cam_data, first_byte}).
// Required project settings: VIS_W=160, VIS_H=120, SCALE=4, ROM_ADDR_BITS=9.

always_comb begin
    case (rom_index)
        9'd0: rom_entry = {16'h3103, 8'h11}; // OpenMV reset
        9'd1: rom_entry = {16'h3008, 8'h82}; // software reset
        9'd2: rom_entry = {ROM_DELAY, 8'h00}; // 10 ms
        9'd3: rom_entry = {16'h4740, 8'h20}; // OpenMV default
        9'd4: rom_entry = {16'h4050, 8'h6E}; // OpenMV default
        9'd5: rom_entry = {16'h4051, 8'h8F}; // OpenMV default
        9'd6: rom_entry = {16'h3008, 8'h42}; // OpenMV default
        9'd7: rom_entry = {16'h3103, 8'h03}; // OpenMV default
        9'd8: rom_entry = {16'h3017, 8'hFF}; // OpenMV default
        9'd9: rom_entry = {16'h3018, 8'hFF}; // OpenMV default
        9'd10: rom_entry = {16'h302C, 8'h02}; // OpenMV default
        9'd11: rom_entry = {16'h3108, 8'h01}; // OpenMV default
        9'd12: rom_entry = {16'h3630, 8'h2E}; // OpenMV default
        9'd13: rom_entry = {16'h3632, 8'hE2}; // OpenMV default
        9'd14: rom_entry = {16'h3633, 8'h23}; // OpenMV default
        9'd15: rom_entry = {16'h3621, 8'hE0}; // OpenMV default
        9'd16: rom_entry = {16'h3704, 8'hA0}; // OpenMV default
        9'd17: rom_entry = {16'h3703, 8'h5A}; // OpenMV default
        9'd18: rom_entry = {16'h3715, 8'h78}; // OpenMV default
        9'd19: rom_entry = {16'h3717, 8'h01}; // OpenMV default
        9'd20: rom_entry = {16'h370B, 8'h60}; // OpenMV default
        9'd21: rom_entry = {16'h3705, 8'h1A}; // OpenMV default
        9'd22: rom_entry = {16'h3905, 8'h02}; // OpenMV default
        9'd23: rom_entry = {16'h3906, 8'h10}; // OpenMV default
        9'd24: rom_entry = {16'h3901, 8'h0A}; // OpenMV default
        9'd25: rom_entry = {16'h3731, 8'h12}; // OpenMV default
        9'd26: rom_entry = {16'h3600, 8'h08}; // OpenMV default
        9'd27: rom_entry = {16'h3601, 8'h33}; // OpenMV default
        9'd28: rom_entry = {16'h302D, 8'h60}; // OpenMV default
        9'd29: rom_entry = {16'h3620, 8'h52}; // OpenMV default
        9'd30: rom_entry = {16'h371B, 8'h20}; // OpenMV default
        9'd31: rom_entry = {16'h471C, 8'h50}; // OpenMV default
        9'd32: rom_entry = {16'h3A18, 8'h00}; // OpenMV default
        9'd33: rom_entry = {16'h3A19, 8'hF8}; // OpenMV default
        9'd34: rom_entry = {16'h3635, 8'h1C}; // OpenMV default
        9'd35: rom_entry = {16'h3634, 8'h40}; // OpenMV default
        9'd36: rom_entry = {16'h3622, 8'h01}; // OpenMV default
        9'd37: rom_entry = {16'h3C04, 8'h28}; // OpenMV default
        9'd38: rom_entry = {16'h3C05, 8'h98}; // OpenMV default
        9'd39: rom_entry = {16'h3C06, 8'h00}; // OpenMV default
        9'd40: rom_entry = {16'h3C07, 8'h08}; // OpenMV default
        9'd41: rom_entry = {16'h3C08, 8'h00}; // OpenMV default
        9'd42: rom_entry = {16'h3C09, 8'h1C}; // OpenMV default
        9'd43: rom_entry = {16'h3C0A, 8'h9C}; // OpenMV default
        9'd44: rom_entry = {16'h3C0B, 8'h40}; // OpenMV default
        9'd45: rom_entry = {16'h3820, 8'h47}; // OpenMV default
        9'd46: rom_entry = {16'h3821, 8'h01}; // OpenMV default
        9'd47: rom_entry = {16'h3800, 8'h00}; // OpenMV default
        9'd48: rom_entry = {16'h3801, 8'h00}; // OpenMV default
        9'd49: rom_entry = {16'h3802, 8'h00}; // OpenMV default
        9'd50: rom_entry = {16'h3803, 8'h04}; // OpenMV default
        9'd51: rom_entry = {16'h3804, 8'h0A}; // OpenMV default
        9'd52: rom_entry = {16'h3805, 8'h3F}; // OpenMV default
        9'd53: rom_entry = {16'h3806, 8'h07}; // OpenMV default
        9'd54: rom_entry = {16'h3807, 8'h9B}; // OpenMV default
        9'd55: rom_entry = {16'h3808, 8'h05}; // OpenMV default
        9'd56: rom_entry = {16'h3809, 8'h00}; // OpenMV default
        9'd57: rom_entry = {16'h380A, 8'h03}; // OpenMV default
        9'd58: rom_entry = {16'h380B, 8'hC0}; // OpenMV default
        9'd59: rom_entry = {16'h3810, 8'h00}; // OpenMV default
        9'd60: rom_entry = {16'h3811, 8'h10}; // OpenMV default
        9'd61: rom_entry = {16'h3812, 8'h00}; // OpenMV default
        9'd62: rom_entry = {16'h3813, 8'h06}; // OpenMV default
        9'd63: rom_entry = {16'h3814, 8'h31}; // OpenMV default
        9'd64: rom_entry = {16'h3815, 8'h31}; // OpenMV default
        9'd65: rom_entry = {16'h3034, 8'h1A}; // OpenMV default
        9'd66: rom_entry = {16'h3035, 8'h11}; // OpenMV default
        9'd67: rom_entry = {16'h3036, 8'h46}; // OpenMV default
        9'd68: rom_entry = {16'h3037, 8'h13}; // OpenMV default
        9'd69: rom_entry = {16'h3038, 8'h00}; // OpenMV default
        9'd70: rom_entry = {16'h3039, 8'h00}; // OpenMV default
        9'd71: rom_entry = {16'h380C, 8'h07}; // OpenMV default
        9'd72: rom_entry = {16'h380D, 8'h68}; // OpenMV default
        9'd73: rom_entry = {16'h380E, 8'h03}; // OpenMV default
        9'd74: rom_entry = {16'h380F, 8'hD8}; // OpenMV default
        9'd75: rom_entry = {16'h3C01, 8'hB4}; // OpenMV default
        9'd76: rom_entry = {16'h3C00, 8'h04}; // OpenMV default
        9'd77: rom_entry = {16'h3A08, 8'h00}; // OpenMV default
        9'd78: rom_entry = {16'h3A09, 8'h93}; // OpenMV default
        9'd79: rom_entry = {16'h3A0E, 8'h06}; // OpenMV default
        9'd80: rom_entry = {16'h3A0A, 8'h00}; // OpenMV default
        9'd81: rom_entry = {16'h3A0B, 8'h7B}; // OpenMV default
        9'd82: rom_entry = {16'h3A0D, 8'h08}; // OpenMV default
        9'd83: rom_entry = {16'h3A00, 8'h38}; // OpenMV default
        9'd84: rom_entry = {16'h3A02, 8'h05}; // OpenMV default
        9'd85: rom_entry = {16'h3A03, 8'hC4}; // OpenMV default
        9'd86: rom_entry = {16'h3A14, 8'h05}; // OpenMV default
        9'd87: rom_entry = {16'h3A15, 8'hC4}; // OpenMV default
        9'd88: rom_entry = {16'h3618, 8'h00}; // OpenMV default
        9'd89: rom_entry = {16'h3612, 8'h29}; // OpenMV default
        9'd90: rom_entry = {16'h3708, 8'h64}; // OpenMV default
        9'd91: rom_entry = {16'h3709, 8'h52}; // OpenMV default
        9'd92: rom_entry = {16'h370C, 8'h03}; // OpenMV default
        9'd93: rom_entry = {16'h4001, 8'h02}; // OpenMV default
        9'd94: rom_entry = {16'h4004, 8'h02}; // OpenMV default
        9'd95: rom_entry = {16'h3000, 8'h00}; // OpenMV default
        9'd96: rom_entry = {16'h3002, 8'h1C}; // OpenMV default
        9'd97: rom_entry = {16'h3004, 8'hFF}; // OpenMV default
        9'd98: rom_entry = {16'h3006, 8'hC3}; // OpenMV default
        9'd99: rom_entry = {16'h300E, 8'h58}; // OpenMV default
        9'd100: rom_entry = {16'h302E, 8'h00}; // OpenMV default
        9'd101: rom_entry = {16'h4300, 8'h30}; // OpenMV default
        9'd102: rom_entry = {16'h501F, 8'h00}; // OpenMV default
        9'd103: rom_entry = {16'h4713, 8'h04}; // OpenMV default
        9'd104: rom_entry = {16'h4407, 8'h04}; // OpenMV default
        9'd105: rom_entry = {16'h460B, 8'h35}; // OpenMV default
        9'd106: rom_entry = {16'h460C, 8'h22}; // OpenMV default
        9'd107: rom_entry = {16'h3824, 8'h02}; // OpenMV default
        9'd108: rom_entry = {16'h5001, 8'hA3}; // OpenMV default
        9'd109: rom_entry = {16'h3406, 8'h01}; // OpenMV default
        9'd110: rom_entry = {16'h3400, 8'h06}; // OpenMV default
        9'd111: rom_entry = {16'h3401, 8'h80}; // OpenMV default
        9'd112: rom_entry = {16'h3402, 8'h04}; // OpenMV default
        9'd113: rom_entry = {16'h3403, 8'h00}; // OpenMV default
        9'd114: rom_entry = {16'h3404, 8'h06}; // OpenMV default
        9'd115: rom_entry = {16'h3405, 8'h00}; // OpenMV default
        9'd116: rom_entry = {16'h5180, 8'hFF}; // OpenMV default
        9'd117: rom_entry = {16'h5181, 8'hF2}; // OpenMV default
        9'd118: rom_entry = {16'h5182, 8'h00}; // OpenMV default
        9'd119: rom_entry = {16'h5183, 8'h14}; // OpenMV default
        9'd120: rom_entry = {16'h5184, 8'h25}; // OpenMV default
        9'd121: rom_entry = {16'h5185, 8'h24}; // OpenMV default
        9'd122: rom_entry = {16'h5186, 8'h16}; // OpenMV default
        9'd123: rom_entry = {16'h5187, 8'h16}; // OpenMV default
        9'd124: rom_entry = {16'h5188, 8'h16}; // OpenMV default
        9'd125: rom_entry = {16'h5189, 8'h62}; // OpenMV default
        9'd126: rom_entry = {16'h518A, 8'h62}; // OpenMV default
        9'd127: rom_entry = {16'h518B, 8'hF0}; // OpenMV default
        9'd128: rom_entry = {16'h518C, 8'hB2}; // OpenMV default
        9'd129: rom_entry = {16'h518D, 8'h50}; // OpenMV default
        9'd130: rom_entry = {16'h518E, 8'h30}; // OpenMV default
        9'd131: rom_entry = {16'h518F, 8'h30}; // OpenMV default
        9'd132: rom_entry = {16'h5190, 8'h50}; // OpenMV default
        9'd133: rom_entry = {16'h5191, 8'hF8}; // OpenMV default
        9'd134: rom_entry = {16'h5192, 8'h04}; // OpenMV default
        9'd135: rom_entry = {16'h5193, 8'h70}; // OpenMV default
        9'd136: rom_entry = {16'h5194, 8'hF0}; // OpenMV default
        9'd137: rom_entry = {16'h5195, 8'hF0}; // OpenMV default
        9'd138: rom_entry = {16'h5196, 8'h03}; // OpenMV default
        9'd139: rom_entry = {16'h5197, 8'h01}; // OpenMV default
        9'd140: rom_entry = {16'h5198, 8'h04}; // OpenMV default
        9'd141: rom_entry = {16'h5199, 8'h12}; // OpenMV default
        9'd142: rom_entry = {16'h519A, 8'h04}; // OpenMV default
        9'd143: rom_entry = {16'h519B, 8'h00}; // OpenMV default
        9'd144: rom_entry = {16'h519C, 8'h06}; // OpenMV default
        9'd145: rom_entry = {16'h519D, 8'h82}; // OpenMV default
        9'd146: rom_entry = {16'h519E, 8'h38}; // OpenMV default
        9'd147: rom_entry = {16'h5381, 8'h1E}; // OpenMV default
        9'd148: rom_entry = {16'h5382, 8'h5B}; // OpenMV default
        9'd149: rom_entry = {16'h5383, 8'h14}; // OpenMV default
        9'd150: rom_entry = {16'h5384, 8'h06}; // OpenMV default
        9'd151: rom_entry = {16'h5385, 8'h82}; // OpenMV default
        9'd152: rom_entry = {16'h5386, 8'h88}; // OpenMV default
        9'd153: rom_entry = {16'h5387, 8'h7C}; // OpenMV default
        9'd154: rom_entry = {16'h5388, 8'h60}; // OpenMV default
        9'd155: rom_entry = {16'h5389, 8'h1C}; // OpenMV default
        9'd156: rom_entry = {16'h538A, 8'h01}; // OpenMV default
        9'd157: rom_entry = {16'h538B, 8'h98}; // OpenMV default
        9'd158: rom_entry = {16'h5300, 8'h08}; // OpenMV default
        9'd159: rom_entry = {16'h5301, 8'h30}; // OpenMV default
        9'd160: rom_entry = {16'h5302, 8'h3F}; // OpenMV default
        9'd161: rom_entry = {16'h5303, 8'h10}; // OpenMV default
        9'd162: rom_entry = {16'h5304, 8'h08}; // OpenMV default
        9'd163: rom_entry = {16'h5305, 8'h30}; // OpenMV default
        9'd164: rom_entry = {16'h5306, 8'h18}; // OpenMV default
        9'd165: rom_entry = {16'h5307, 8'h28}; // OpenMV default
        9'd166: rom_entry = {16'h5309, 8'h08}; // OpenMV default
        9'd167: rom_entry = {16'h530A, 8'h30}; // OpenMV default
        9'd168: rom_entry = {16'h530B, 8'h04}; // OpenMV default
        9'd169: rom_entry = {16'h530C, 8'h06}; // OpenMV default
        9'd170: rom_entry = {16'h5480, 8'h01}; // OpenMV default
        9'd171: rom_entry = {16'h5481, 8'h06}; // OpenMV default
        9'd172: rom_entry = {16'h5482, 8'h12}; // OpenMV default
        9'd173: rom_entry = {16'h5483, 8'h24}; // OpenMV default
        9'd174: rom_entry = {16'h5484, 8'h4A}; // OpenMV default
        9'd175: rom_entry = {16'h5485, 8'h58}; // OpenMV default
        9'd176: rom_entry = {16'h5486, 8'h65}; // OpenMV default
        9'd177: rom_entry = {16'h5487, 8'h72}; // OpenMV default
        9'd178: rom_entry = {16'h5488, 8'h7D}; // OpenMV default
        9'd179: rom_entry = {16'h5489, 8'h88}; // OpenMV default
        9'd180: rom_entry = {16'h548A, 8'h92}; // OpenMV default
        9'd181: rom_entry = {16'h548B, 8'hA3}; // OpenMV default
        9'd182: rom_entry = {16'h548C, 8'hB2}; // OpenMV default
        9'd183: rom_entry = {16'h548D, 8'hC8}; // OpenMV default
        9'd184: rom_entry = {16'h548E, 8'hDD}; // OpenMV default
        9'd185: rom_entry = {16'h548F, 8'hF0}; // OpenMV default
        9'd186: rom_entry = {16'h5490, 8'h15}; // OpenMV default
        9'd187: rom_entry = {16'h5580, 8'h06}; // OpenMV default
        9'd188: rom_entry = {16'h5583, 8'h40}; // OpenMV default
        9'd189: rom_entry = {16'h5584, 8'h20}; // OpenMV default
        9'd190: rom_entry = {16'h5589, 8'h10}; // OpenMV default
        9'd191: rom_entry = {16'h558A, 8'h00}; // OpenMV default
        9'd192: rom_entry = {16'h558B, 8'hF8}; // OpenMV default
        9'd193: rom_entry = {16'h5000, 8'h27}; // OpenMV default
        9'd194: rom_entry = {16'h5800, 8'h20}; // OpenMV default
        9'd195: rom_entry = {16'h5801, 8'h19}; // OpenMV default
        9'd196: rom_entry = {16'h5802, 8'h17}; // OpenMV default
        9'd197: rom_entry = {16'h5803, 8'h16}; // OpenMV default
        9'd198: rom_entry = {16'h5804, 8'h18}; // OpenMV default
        9'd199: rom_entry = {16'h5805, 8'h21}; // OpenMV default
        9'd200: rom_entry = {16'h5806, 8'h0F}; // OpenMV default
        9'd201: rom_entry = {16'h5807, 8'h0A}; // OpenMV default
        9'd202: rom_entry = {16'h5808, 8'h07}; // OpenMV default
        9'd203: rom_entry = {16'h5809, 8'h07}; // OpenMV default
        9'd204: rom_entry = {16'h580A, 8'h0A}; // OpenMV default
        9'd205: rom_entry = {16'h580B, 8'h0C}; // OpenMV default
        9'd206: rom_entry = {16'h580C, 8'h0A}; // OpenMV default
        9'd207: rom_entry = {16'h580D, 8'h03}; // OpenMV default
        9'd208: rom_entry = {16'h580E, 8'h01}; // OpenMV default
        9'd209: rom_entry = {16'h580F, 8'h01}; // OpenMV default
        9'd210: rom_entry = {16'h5810, 8'h03}; // OpenMV default
        9'd211: rom_entry = {16'h5811, 8'h09}; // OpenMV default
        9'd212: rom_entry = {16'h5812, 8'h0A}; // OpenMV default
        9'd213: rom_entry = {16'h5813, 8'h03}; // OpenMV default
        9'd214: rom_entry = {16'h5814, 8'h01}; // OpenMV default
        9'd215: rom_entry = {16'h5815, 8'h01}; // OpenMV default
        9'd216: rom_entry = {16'h5816, 8'h03}; // OpenMV default
        9'd217: rom_entry = {16'h5817, 8'h08}; // OpenMV default
        9'd218: rom_entry = {16'h5818, 8'h10}; // OpenMV default
        9'd219: rom_entry = {16'h5819, 8'h0A}; // OpenMV default
        9'd220: rom_entry = {16'h581A, 8'h06}; // OpenMV default
        9'd221: rom_entry = {16'h581B, 8'h06}; // OpenMV default
        9'd222: rom_entry = {16'h581C, 8'h08}; // OpenMV default
        9'd223: rom_entry = {16'h581D, 8'h0E}; // OpenMV default
        9'd224: rom_entry = {16'h581E, 8'h22}; // OpenMV default
        9'd225: rom_entry = {16'h581F, 8'h18}; // OpenMV default
        9'd226: rom_entry = {16'h5820, 8'h13}; // OpenMV default
        9'd227: rom_entry = {16'h5821, 8'h12}; // OpenMV default
        9'd228: rom_entry = {16'h5822, 8'h16}; // OpenMV default
        9'd229: rom_entry = {16'h5823, 8'h1E}; // OpenMV default
        9'd230: rom_entry = {16'h5824, 8'h64}; // OpenMV default
        9'd231: rom_entry = {16'h5825, 8'h2A}; // OpenMV default
        9'd232: rom_entry = {16'h5826, 8'h2C}; // OpenMV default
        9'd233: rom_entry = {16'h5827, 8'h2A}; // OpenMV default
        9'd234: rom_entry = {16'h5828, 8'h46}; // OpenMV default
        9'd235: rom_entry = {16'h5829, 8'h2A}; // OpenMV default
        9'd236: rom_entry = {16'h582A, 8'h26}; // OpenMV default
        9'd237: rom_entry = {16'h582B, 8'h24}; // OpenMV default
        9'd238: rom_entry = {16'h582C, 8'h26}; // OpenMV default
        9'd239: rom_entry = {16'h582D, 8'h2A}; // OpenMV default
        9'd240: rom_entry = {16'h582E, 8'h28}; // OpenMV default
        9'd241: rom_entry = {16'h582F, 8'h42}; // OpenMV default
        9'd242: rom_entry = {16'h5830, 8'h40}; // OpenMV default
        9'd243: rom_entry = {16'h5831, 8'h42}; // OpenMV default
        9'd244: rom_entry = {16'h5832, 8'h08}; // OpenMV default
        9'd245: rom_entry = {16'h5833, 8'h28}; // OpenMV default
        9'd246: rom_entry = {16'h5834, 8'h26}; // OpenMV default
        9'd247: rom_entry = {16'h5835, 8'h24}; // OpenMV default
        9'd248: rom_entry = {16'h5836, 8'h26}; // OpenMV default
        9'd249: rom_entry = {16'h5837, 8'h2A}; // OpenMV default
        9'd250: rom_entry = {16'h5838, 8'h44}; // OpenMV default
        9'd251: rom_entry = {16'h5839, 8'h4A}; // OpenMV default
        9'd252: rom_entry = {16'h583A, 8'h2C}; // OpenMV default
        9'd253: rom_entry = {16'h583B, 8'h2A}; // OpenMV default
        9'd254: rom_entry = {16'h583C, 8'h46}; // OpenMV default
        9'd255: rom_entry = {16'h583D, 8'hCE}; // OpenMV default
        9'd256: rom_entry = {16'h5688, 8'h11}; // OpenMV default
        9'd257: rom_entry = {16'h5689, 8'h11}; // OpenMV default
        9'd258: rom_entry = {16'h568A, 8'h11}; // OpenMV default
        9'd259: rom_entry = {16'h568B, 8'h11}; // OpenMV default
        9'd260: rom_entry = {16'h568C, 8'h11}; // OpenMV default
        9'd261: rom_entry = {16'h568D, 8'h11}; // OpenMV default
        9'd262: rom_entry = {16'h568E, 8'h11}; // OpenMV default
        9'd263: rom_entry = {16'h568F, 8'h11}; // OpenMV default
        9'd264: rom_entry = {16'h5025, 8'h00}; // OpenMV default
        9'd265: rom_entry = {16'h3A0F, 8'h42}; // OpenMV default
        9'd266: rom_entry = {16'h3A10, 8'h38}; // OpenMV default
        9'd267: rom_entry = {16'h3A1B, 8'h44}; // OpenMV default
        9'd268: rom_entry = {16'h3A1E, 8'h36}; // OpenMV default
        9'd269: rom_entry = {16'h3A11, 8'h60}; // OpenMV default
        9'd270: rom_entry = {16'h3A1F, 8'h10}; // OpenMV default
        9'd271: rom_entry = {16'h4005, 8'h1A}; // OpenMV default
        9'd272: rom_entry = {16'h3406, 8'h00}; // OpenMV default
        9'd273: rom_entry = {16'h3503, 8'h00}; // OpenMV default
        9'd274: rom_entry = {16'h3008, 8'h02}; // OpenMV default
        9'd275: rom_entry = {16'h3A02, 8'h07}; // OpenMV default
        9'd276: rom_entry = {16'h3A03, 8'hAE}; // OpenMV default
        9'd277: rom_entry = {16'h3A08, 8'h01}; // OpenMV default
        9'd278: rom_entry = {16'h3A09, 8'h27}; // OpenMV default
        9'd279: rom_entry = {16'h3A0A, 8'h00}; // OpenMV default
        9'd280: rom_entry = {16'h3A0B, 8'hF6}; // OpenMV default
        9'd281: rom_entry = {16'h3A0E, 8'h06}; // OpenMV default
        9'd282: rom_entry = {16'h3A0D, 8'h08}; // OpenMV default
        9'd283: rom_entry = {16'h3A14, 8'h07}; // OpenMV default
        9'd284: rom_entry = {16'h3A15, 8'hAE}; // OpenMV default
        9'd285: rom_entry = {16'h4401, 8'h0D}; // OpenMV default
        9'd286: rom_entry = {16'h4723, 8'h03}; // OpenMV default
        9'd287: rom_entry = {ROM_DELAY, 8'h00}; // 300 ms settling
        9'd288: rom_entry = {ROM_DELAY, 8'h00}; // 300 ms settling
        9'd289: rom_entry = {ROM_DELAY, 8'h00}; // 300 ms settling
        9'd290: rom_entry = {ROM_DELAY, 8'h00}; // 300 ms settling
        9'd291: rom_entry = {ROM_DELAY, 8'h00}; // 300 ms settling
        9'd292: rom_entry = {ROM_DELAY, 8'h00}; // 300 ms settling
        9'd293: rom_entry = {ROM_DELAY, 8'h00}; // 300 ms settling
        9'd294: rom_entry = {ROM_DELAY, 8'h00}; // 300 ms settling
        9'd295: rom_entry = {ROM_DELAY, 8'h00}; // 300 ms settling
        9'd296: rom_entry = {ROM_DELAY, 8'h00}; // 300 ms settling
        9'd297: rom_entry = {ROM_DELAY, 8'h00}; // 300 ms settling
        9'd298: rom_entry = {ROM_DELAY, 8'h00}; // 300 ms settling
        9'd299: rom_entry = {ROM_DELAY, 8'h00}; // 300 ms settling
        9'd300: rom_entry = {ROM_DELAY, 8'h00}; // 300 ms settling
        9'd301: rom_entry = {ROM_DELAY, 8'h00}; // 300 ms settling
        9'd302: rom_entry = {ROM_DELAY, 8'h00}; // 300 ms settling
        9'd303: rom_entry = {ROM_DELAY, 8'h00}; // 300 ms settling
        9'd304: rom_entry = {ROM_DELAY, 8'h00}; // 300 ms settling
        9'd305: rom_entry = {ROM_DELAY, 8'h00}; // 300 ms settling
        9'd306: rom_entry = {ROM_DELAY, 8'h00}; // 300 ms settling
        9'd307: rom_entry = {ROM_DELAY, 8'h00}; // 300 ms settling
        9'd308: rom_entry = {ROM_DELAY, 8'h00}; // 300 ms settling
        9'd309: rom_entry = {ROM_DELAY, 8'h00}; // 300 ms settling
        9'd310: rom_entry = {ROM_DELAY, 8'h00}; // 300 ms settling
        9'd311: rom_entry = {ROM_DELAY, 8'h00}; // 300 ms settling
        9'd312: rom_entry = {ROM_DELAY, 8'h00}; // 300 ms settling
        9'd313: rom_entry = {ROM_DELAY, 8'h00}; // 300 ms settling
        9'd314: rom_entry = {ROM_DELAY, 8'h00}; // 300 ms settling
        9'd315: rom_entry = {ROM_DELAY, 8'h00}; // 300 ms settling
        9'd316: rom_entry = {ROM_DELAY, 8'h00}; // 300 ms settling
        9'd317: rom_entry = {16'h4300, 8'h61}; // RGB565 byte order validated on this module
        9'd318: rom_entry = {16'h501F, 8'h01}; // RGB ISP mux
        9'd319: rom_entry = {16'h3821, 8'h01}; // non-JPEG timing
        9'd320: rom_entry = {16'h3002, 8'h1C}; // enable non-JPEG blocks
        9'd321: rom_entry = {16'h3006, 8'hC3}; // non-JPEG clocks
        9'd322: rom_entry = {16'h3800, 8'h00}; // sensor start X
        9'd323: rom_entry = {16'h3801, 8'h00}; // sensor start X
        9'd324: rom_entry = {16'h3802, 8'h00}; // sensor start Y
        9'd325: rom_entry = {16'h3803, 8'h00}; // sensor start Y
        9'd326: rom_entry = {16'h3804, 8'h0A}; // sensor end X
        9'd327: rom_entry = {16'h3805, 8'h2F}; // sensor end X
        9'd328: rom_entry = {16'h3806, 8'h07}; // sensor end Y
        9'd329: rom_entry = {16'h3807, 8'h9F}; // sensor end Y
        9'd330: rom_entry = {16'h3808, 8'h00}; // width 160
        9'd331: rom_entry = {16'h3809, 8'hA0}; // width 160
        9'd332: rom_entry = {16'h380A, 8'h00}; // height 120
        9'd333: rom_entry = {16'h380B, 8'h78}; // height 120
        9'd334: rom_entry = {16'h380C, 8'h06}; // HTS 1716
        9'd335: rom_entry = {16'h380D, 8'hB4}; // HTS 1716
        9'd336: rom_entry = {16'h380E, 8'h03}; // VTS 1000
        9'd337: rom_entry = {16'h380F, 8'hE8}; // VTS 1000
        9'd338: rom_entry = {16'h3810, 8'h00}; // X offset 4
        9'd339: rom_entry = {16'h3811, 8'h04}; // X offset 4
        9'd340: rom_entry = {16'h3812, 8'h00}; // Y offset 2
        9'd341: rom_entry = {16'h3813, 8'h02}; // Y offset 2
        9'd342: rom_entry = {16'h3814, 8'h31}; // 2x subsampling
        9'd343: rom_entry = {16'h3815, 8'h31}; // 2x subsampling
        9'd344: rom_entry = {16'h3820, 8'h41}; // binning enabled
        9'd345: rom_entry = {16'h3821, 8'h01}; // binning enabled
        9'd346: rom_entry = {16'h4602, 8'h00}; // VFIFO width 160
        9'd347: rom_entry = {16'h4603, 8'hA0}; // VFIFO width 160
        9'd348: rom_entry = {16'h4604, 8'h00}; // VFIFO height 120
        9'd349: rom_entry = {16'h4605, 8'h78}; // VFIFO height 120
        9'd350: rom_entry = {16'h3212, 8'h03}; // start group 3
        9'd351: rom_entry = {16'h5581, 8'h1C}; // neutral saturation
        9'd352: rom_entry = {16'h5582, 8'h5A}; // neutral saturation
        9'd353: rom_entry = {16'h5583, 8'h06}; // neutral saturation
        9'd354: rom_entry = {16'h5584, 8'h15};
        9'd355: rom_entry = {16'h5585, 8'h52};
        9'd356: rom_entry = {16'h5586, 8'h66};
        9'd357: rom_entry = {16'h5587, 8'h68};
        9'd358: rom_entry = {16'h5588, 8'h66};
        9'd359: rom_entry = {16'h5589, 8'h02};
        9'd360: rom_entry = {16'h558B, 8'h98}; // neutral saturation
        9'd361: rom_entry = {16'h558A, 8'h01}; // neutral saturation
        9'd362: rom_entry = {16'h3212, 8'h13}; // end group 3
        9'd363: rom_entry = {16'h3212, 8'hA3}; // launch group 3
        9'd364: rom_entry = {16'h3212, 8'h03}; // start normal-effect group
        9'd365: rom_entry = {16'h5580, 8'h06}; // normal effect
        9'd366: rom_entry = {16'h5583, 8'h40}; // normal effect
        9'd367: rom_entry = {16'h5584, 8'h15}; // normal effect
        9'd368: rom_entry = {16'h5003, 8'h08}; // normal effect
        9'd369: rom_entry = {16'h3212, 8'h13}; // end normal-effect group
        9'd370: rom_entry = {16'h3212, 8'hA3}; // launch normal-effect group
        9'd371: rom_entry = {16'h3406, 8'h00}; // automatic white balance
        9'd372: rom_entry = {16'h3503, 8'h00}; // automatic exposure and gain
        9'd373: rom_entry = {16'h503D, 8'h00}; // test pattern off
        9'd374: rom_entry = {16'h3008, 8'h02}; // streaming on
        9'd375: rom_entry = {ROM_DELAY, 8'h00}; // 10 ms
        9'd376: rom_entry = {ROM_END, 8'hFF}; // end
        default: rom_entry = {ROM_END, 8'hFF};
    endcase
end


    // =========================================================================
    // SCCB master interface
    // =========================================================================

    logic sccb_start;
    logic sccb_busy;
    logic sccb_done;
    logic sccb_ack_error;

    sccb_write_master #(
        .CLK_HZ      (CLK_HZ),
        .SCCB_HZ     (SCCB_HZ),
        .DEVICE_ADDR (OV5640_ADDR)
    ) sccb_master_inst (
        .clk       (clk),
        .rst_n     (rst_n),

        .start    (sccb_start),        //1 when a new SCCB communication should start
        .reg_addr (current_reg_addr),
        .reg_data (current_reg_data),

        .busy     (sccb_busy),         //1: Transmission in progress, busy: 0: master free
        .done     (sccb_done),         //1 when the transmission is completed
        .ack_error(sccb_ack_error),    //1 if camera did not respond correctly with an ACK

        .scl       (ov_scl),
        .sda       (ov_sda)
    );

    // =========================================================================
    // Main camera-control and configuration FSM
    // =========================================================================

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state              <= CAM_POWER_DOWN;

            delay_counter      <= '0;
            rom_index          <= '0;

            sccb_start         <= 1'b0;

            //The camera is disabled and kept in a reset state
            ov_pwdn            <= 1'b1;
            ov_reset_n         <= 1'b0;

            camera_initialized <= 1'b0;
        end
        else begin
            // sccb_start must be a one-clock pulse.
            sccb_start <= 1'b0;

            case (state)

                // ------------------------------------------------------------
                // Camera in power-down and hardware reset.
                // ------------------------------------------------------------

                CAM_POWER_DOWN: begin
                    ov_pwdn            <= 1'b1;
                    ov_reset_n         <= 1'b0;
                    camera_initialized <= 1'b0;

                    if (delay_counter == DELAY_CYCLES - 1) begin  //waiting of 10 ms
                        delay_counter <= '0;
                        state         <= CAM_RESET_ACTIVE;
                    end
                    else begin
                        delay_counter <= delay_counter + 1'b1;
                    end
                end

                // ------------------------------------------------------------
                //The camera comes out of power-down mode->internal circuits can be powered up and stabilize, 
                //but the logic remains locked in a reset state
                // ------------------------------------------------------------

                CAM_RESET_ACTIVE: begin
                    ov_pwdn    <= 1'b0;
                    ov_reset_n <= 1'b0;

                    if (delay_counter == DELAY_CYCLES - 1) begin
                        delay_counter <= '0;
                        state         <= CAM_RESET_RELEASED;
                    end
                    else begin
                        delay_counter <= delay_counter + 1'b1;
                    end
                end

                // ------------------------------------------------------------
                //Camera is powered up and out of reset
                //The controller waits other 10 ms to allow the logic and the SCCB bus to become operational
                // ------------------------------------------------------------

                CAM_RESET_RELEASED: begin
                    ov_pwdn    <= 1'b0;
                    ov_reset_n <= 1'b1;

                    if (delay_counter == DELAY_CYCLES - 1) begin
                        delay_counter <= '0;
                        rom_index     <= '0;
                        state         <= CFG_LOAD;
                    end
                    else begin
                        delay_counter <= delay_counter + 1'b1;
                    end
                end

                // ------------------------------------------------------------
                // Interpret the current ROM entry.
                // ------------------------------------------------------------

                CFG_LOAD: begin
                    if (current_reg_addr == ROM_END) begin
                        state <= CAM_READY;
                    end
                    else if (current_reg_addr == ROM_DELAY) begin
                        delay_counter <= '0;
                        state         <= CFG_DELAY;
                    end
                    else begin
                        state <= CFG_START_WRITE;
                    end
                end

                // ------------------------------------------------------------
                // Start one SCCB register-write transaction. Waiting for SCCB to be available to start writing
                // ------------------------------------------------------------

                CFG_START_WRITE: begin
                    if (!sccb_busy) begin   // avoid starting a 2nd transaction while the master is still completing the previous one
                        sccb_start <= 1'b1;
                        state      <= CFG_WAIT_WRITE;
                    end
                end

                // ------------------------------------------------------------
                // Wait for the SCCB master to finish the current register.
                // ------------------------------------------------------------

                CFG_WAIT_WRITE: begin
                    if (sccb_done) begin
                        if (sccb_ack_error) begin
                            state <= CAM_ERROR;
                        end
                        else begin
                            rom_index <= rom_index + 1'b1;
                            state     <= CFG_LOAD;
                        end
                    end
                end

                // ------------------------------------------------------------
                // Fixed 10 ms delay ROM entry.
                // ------------------------------------------------------------

                CFG_DELAY: begin
                    if (delay_counter == DELAY_CYCLES - 1) begin
                        delay_counter <= '0;
                        rom_index     <= rom_index + 1'b1;
                        state         <= CFG_LOAD;
                    end
                    else begin
                        delay_counter <= delay_counter + 1'b1;
                    end
                end

                // ------------------------------------------------------------
                // Camera initialization successfully completed.
                // ------------------------------------------------------------

                CAM_READY: begin
                    ov_pwdn            <= 1'b0;
                    ov_reset_n         <= 1'b1;
                    camera_initialized <= 1'b1;
                end

                // ------------------------------------------------------------
                // SCCB error. Remain here until external reset.
                // ------------------------------------------------------------

                CAM_ERROR: begin
                    ov_pwdn            <= 1'b0;
                    ov_reset_n         <= 1'b1;
                    camera_initialized <= 1'b0;
                end

                default: begin
                    state              <= CAM_POWER_DOWN;
                    delay_counter      <= '0;
                    rom_index          <= '0;

                    ov_pwdn            <= 1'b1;
                    ov_reset_n         <= 1'b0;

                    camera_initialized <= 1'b0;
                end

            endcase
        end
    end

endmodule