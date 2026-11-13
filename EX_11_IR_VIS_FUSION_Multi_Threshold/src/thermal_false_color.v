// ============================================================================
// MODULE: thermal_false_color
// DESCRIPTION: Converts an 8-bit thermal intensity into an RGB888 false
// colour. Two palettes, selected by the parameter TURBO:
//
//   TURBO = 1 : Google "Turbo" colormap (Apache-2.0), 256 entries
//               cold -> hot: dark blue, blue, cyan, green, yellow, orange,
//               red, dark red. Improved rainbow: perceptually smoother than
//               "jet" and readable also by colour-blind viewers.
//               Values taken from matplotlib.colormaps['turbo'], rounded
//               to 8 bits per channel.
//
//   TURBO = 0 : previous arithmetic palette (iron-like "hot"):
//               thermal   0 ...  63 : black  -> red
//               thermal  64 ... 127 : red    -> yellow
//               thermal 128 ... 191 : yellow -> white
//               thermal 192 ... 255 : white
//
// NOTE:
// The Turbo table is a 256 x 24 bit constant read COMBINATIONALLY: it is
// built with LUTs (distributed logic), not with BSRAM. 
//
// LATENCY: 0 clock cycles (purely combinational).
// ============================================================================

module thermal_false_color #(
    parameter bit TURBO = 1'b1      // 1: Turbo colormap, 0: previous "hot" palette
)(
    input  logic [7:0] thermal_in,   // 8-bit thermal intensity

    output logic [7:0] red,
    output logic [7:0] green,
    output logic [7:0] blue
);

    // ========================================================================
    // Palette 0: previous arithmetic palette (no table)
    // ========================================================================
    logic [23:0] rgb_hot;      // {red, green, blue}

    // Inside each range the varying channel follows a ramp 0, 4, 8, ... 252,
    // obtained from the 6 least significant bits: {thermal[5:0], 2'b00}.
    logic [7:0] ramp;          // local ramp inside the current range: 0, 4, ... 252
    assign ramp = {thermal_in[5:0], 2'b00};

    always_comb begin
        case (thermal_in[7:6])
            2'b00:   rgb_hot = {ramp,  8'h00, 8'h00};   // black  -> red
            2'b01:   rgb_hot = {8'hFF, ramp,  8'h00};   // red    -> yellow
            2'b10:   rgb_hot = {8'hFF, 8'hFF, ramp };   // yellow -> white
            default: rgb_hot = {8'hFF, 8'hFF, 8'hFF};   // white
        endcase
    end

    // ========================================================================
    // Palette 1: Turbo colormap (256-entry table, 24'hRRGGBB)
    // ========================================================================
    logic [23:0] rgb_turbo;

    always_comb begin
        case (thermal_in)
            8'd0  : rgb_turbo = 24'h30123B;
            8'd1  : rgb_turbo = 24'h321543;
            8'd2  : rgb_turbo = 24'h33184A;
            8'd3  : rgb_turbo = 24'h341B51;
            8'd4  : rgb_turbo = 24'h351E58;
            8'd5  : rgb_turbo = 24'h36215F;
            8'd6  : rgb_turbo = 24'h372466;
            8'd7  : rgb_turbo = 24'h38276D;
            8'd8  : rgb_turbo = 24'h392A73;
            8'd9  : rgb_turbo = 24'h3A2D79;
            8'd10 : rgb_turbo = 24'h3B2F80;
            8'd11 : rgb_turbo = 24'h3C3286;
            8'd12 : rgb_turbo = 24'h3D358B;
            8'd13 : rgb_turbo = 24'h3E3891;
            8'd14 : rgb_turbo = 24'h3F3B97;
            8'd15 : rgb_turbo = 24'h3F3E9C;
            8'd16 : rgb_turbo = 24'h4040A2;
            8'd17 : rgb_turbo = 24'h4143A7;
            8'd18 : rgb_turbo = 24'h4146AC;
            8'd19 : rgb_turbo = 24'h4249B1;
            8'd20 : rgb_turbo = 24'h424BB5;
            8'd21 : rgb_turbo = 24'h434EBA;
            8'd22 : rgb_turbo = 24'h4451BF;
            8'd23 : rgb_turbo = 24'h4454C3;
            8'd24 : rgb_turbo = 24'h4456C7;
            8'd25 : rgb_turbo = 24'h4559CB;
            8'd26 : rgb_turbo = 24'h455CCF;
            8'd27 : rgb_turbo = 24'h455ED3;
            8'd28 : rgb_turbo = 24'h4661D6;
            8'd29 : rgb_turbo = 24'h4664DA;
            8'd30 : rgb_turbo = 24'h4666DD;
            8'd31 : rgb_turbo = 24'h4669E0;
            8'd32 : rgb_turbo = 24'h466BE3;
            8'd33 : rgb_turbo = 24'h476EE6;
            8'd34 : rgb_turbo = 24'h4771E9;
            8'd35 : rgb_turbo = 24'h4773EB;
            8'd36 : rgb_turbo = 24'h4776EE;
            8'd37 : rgb_turbo = 24'h4778F0;
            8'd38 : rgb_turbo = 24'h477BF2;
            8'd39 : rgb_turbo = 24'h467DF4;
            8'd40 : rgb_turbo = 24'h4680F6;
            8'd41 : rgb_turbo = 24'h4682F8;
            8'd42 : rgb_turbo = 24'h4685FA;
            8'd43 : rgb_turbo = 24'h4687FB;
            8'd44 : rgb_turbo = 24'h458AFC;
            8'd45 : rgb_turbo = 24'h458CFD;
            8'd46 : rgb_turbo = 24'h448FFE;
            8'd47 : rgb_turbo = 24'h4391FE;
            8'd48 : rgb_turbo = 24'h4294FF;
            8'd49 : rgb_turbo = 24'h4196FF;
            8'd50 : rgb_turbo = 24'h4099FF;
            8'd51 : rgb_turbo = 24'h3E9BFE;
            8'd52 : rgb_turbo = 24'h3D9EFE;
            8'd53 : rgb_turbo = 24'h3BA0FD;
            8'd54 : rgb_turbo = 24'h3AA3FC;
            8'd55 : rgb_turbo = 24'h38A5FB;
            8'd56 : rgb_turbo = 24'h37A8FA;
            8'd57 : rgb_turbo = 24'h35ABF8;
            8'd58 : rgb_turbo = 24'h33ADF7;
            8'd59 : rgb_turbo = 24'h31AFF5;
            8'd60 : rgb_turbo = 24'h2FB2F4;
            8'd61 : rgb_turbo = 24'h2EB4F2;
            8'd62 : rgb_turbo = 24'h2CB7F0;
            8'd63 : rgb_turbo = 24'h2AB9EE;
            8'd64 : rgb_turbo = 24'h28BCEB;
            8'd65 : rgb_turbo = 24'h27BEE9;
            8'd66 : rgb_turbo = 24'h25C0E7;
            8'd67 : rgb_turbo = 24'h23C3E4;
            8'd68 : rgb_turbo = 24'h22C5E2;
            8'd69 : rgb_turbo = 24'h20C7DF;
            8'd70 : rgb_turbo = 24'h1FC9DD;
            8'd71 : rgb_turbo = 24'h1ECBDA;
            8'd72 : rgb_turbo = 24'h1CCDD8;
            8'd73 : rgb_turbo = 24'h1BD0D5;
            8'd74 : rgb_turbo = 24'h1AD2D2;
            8'd75 : rgb_turbo = 24'h1AD4D0;
            8'd76 : rgb_turbo = 24'h19D5CD;
            8'd77 : rgb_turbo = 24'h18D7CA;
            8'd78 : rgb_turbo = 24'h18D9C8;
            8'd79 : rgb_turbo = 24'h18DBC5;
            8'd80 : rgb_turbo = 24'h18DDC2;
            8'd81 : rgb_turbo = 24'h18DEC0;
            8'd82 : rgb_turbo = 24'h18E0BD;
            8'd83 : rgb_turbo = 24'h19E2BB;
            8'd84 : rgb_turbo = 24'h19E3B9;
            8'd85 : rgb_turbo = 24'h1AE4B6;
            8'd86 : rgb_turbo = 24'h1CE6B4;
            8'd87 : rgb_turbo = 24'h1DE7B2;
            8'd88 : rgb_turbo = 24'h1FE9AF;
            8'd89 : rgb_turbo = 24'h20EAAC;
            8'd90 : rgb_turbo = 24'h22EBAA;
            8'd91 : rgb_turbo = 24'h25ECA7;
            8'd92 : rgb_turbo = 24'h27EEA4;
            8'd93 : rgb_turbo = 24'h2AEFA1;
            8'd94 : rgb_turbo = 24'h2CF09E;
            8'd95 : rgb_turbo = 24'h2FF19B;
            8'd96 : rgb_turbo = 24'h32F298;
            8'd97 : rgb_turbo = 24'h35F394;
            8'd98 : rgb_turbo = 24'h38F491;
            8'd99 : rgb_turbo = 24'h3CF58E;
            8'd100: rgb_turbo = 24'h3FF68A;
            8'd101: rgb_turbo = 24'h43F787;
            8'd102: rgb_turbo = 24'h46F884;
            8'd103: rgb_turbo = 24'h4AF880;
            8'd104: rgb_turbo = 24'h4EF97D;
            8'd105: rgb_turbo = 24'h52FA7A;
            8'd106: rgb_turbo = 24'h55FA76;
            8'd107: rgb_turbo = 24'h59FB73;
            8'd108: rgb_turbo = 24'h5DFC6F;
            8'd109: rgb_turbo = 24'h61FC6C;
            8'd110: rgb_turbo = 24'h65FD69;
            8'd111: rgb_turbo = 24'h69FD66;
            8'd112: rgb_turbo = 24'h6DFE62;
            8'd113: rgb_turbo = 24'h71FE5F;
            8'd114: rgb_turbo = 24'h75FE5C;
            8'd115: rgb_turbo = 24'h79FE59;
            8'd116: rgb_turbo = 24'h7DFF56;
            8'd117: rgb_turbo = 24'h80FF53;
            8'd118: rgb_turbo = 24'h84FF51;
            8'd119: rgb_turbo = 24'h88FF4E;
            8'd120: rgb_turbo = 24'h8BFF4B;
            8'd121: rgb_turbo = 24'h8FFF49;
            8'd122: rgb_turbo = 24'h92FF47;
            8'd123: rgb_turbo = 24'h96FE44;
            8'd124: rgb_turbo = 24'h99FE42;
            8'd125: rgb_turbo = 24'h9CFE40;
            8'd126: rgb_turbo = 24'h9FFD3F;
            8'd127: rgb_turbo = 24'hA1FD3D;
            8'd128: rgb_turbo = 24'hA4FC3C;
            8'd129: rgb_turbo = 24'hA7FC3A;
            8'd130: rgb_turbo = 24'hA9FB39;
            8'd131: rgb_turbo = 24'hACFB38;
            8'd132: rgb_turbo = 24'hAFFA37;
            8'd133: rgb_turbo = 24'hB1F936;
            8'd134: rgb_turbo = 24'hB4F836;
            8'd135: rgb_turbo = 24'hB7F735;
            8'd136: rgb_turbo = 24'hB9F635;
            8'd137: rgb_turbo = 24'hBCF534;
            8'd138: rgb_turbo = 24'hBEF434;
            8'd139: rgb_turbo = 24'hC1F334;
            8'd140: rgb_turbo = 24'hC3F134;
            8'd141: rgb_turbo = 24'hC6F034;
            8'd142: rgb_turbo = 24'hC8EF34;
            8'd143: rgb_turbo = 24'hCBED34;
            8'd144: rgb_turbo = 24'hCDEC34;
            8'd145: rgb_turbo = 24'hD0EA34;
            8'd146: rgb_turbo = 24'hD2E935;
            8'd147: rgb_turbo = 24'hD4E735;
            8'd148: rgb_turbo = 24'hD7E535;
            8'd149: rgb_turbo = 24'hD9E436;
            8'd150: rgb_turbo = 24'hDBE236;
            8'd151: rgb_turbo = 24'hDDE037;
            8'd152: rgb_turbo = 24'hDFDF37;
            8'd153: rgb_turbo = 24'hE1DD37;
            8'd154: rgb_turbo = 24'hE3DB38;
            8'd155: rgb_turbo = 24'hE5D938;
            8'd156: rgb_turbo = 24'hE7D739;
            8'd157: rgb_turbo = 24'hE9D539;
            8'd158: rgb_turbo = 24'hEBD339;
            8'd159: rgb_turbo = 24'hECD13A;
            8'd160: rgb_turbo = 24'hEECF3A;
            8'd161: rgb_turbo = 24'hEFCD3A;
            8'd162: rgb_turbo = 24'hF1CB3A;
            8'd163: rgb_turbo = 24'hF2C93A;
            8'd164: rgb_turbo = 24'hF4C73A;
            8'd165: rgb_turbo = 24'hF5C53A;
            8'd166: rgb_turbo = 24'hF6C33A;
            8'd167: rgb_turbo = 24'hF7C13A;
            8'd168: rgb_turbo = 24'hF8BE39;
            8'd169: rgb_turbo = 24'hF9BC39;
            8'd170: rgb_turbo = 24'hFABA39;
            8'd171: rgb_turbo = 24'hFBB838;
            8'd172: rgb_turbo = 24'hFBB637;
            8'd173: rgb_turbo = 24'hFCB336;
            8'd174: rgb_turbo = 24'hFCB136;
            8'd175: rgb_turbo = 24'hFDAE35;
            8'd176: rgb_turbo = 24'hFDAC34;
            8'd177: rgb_turbo = 24'hFEA933;
            8'd178: rgb_turbo = 24'hFEA732;
            8'd179: rgb_turbo = 24'hFEA431;
            8'd180: rgb_turbo = 24'hFEA130;
            8'd181: rgb_turbo = 24'hFE9E2F;
            8'd182: rgb_turbo = 24'hFE9B2D;
            8'd183: rgb_turbo = 24'hFE992C;
            8'd184: rgb_turbo = 24'hFE962B;
            8'd185: rgb_turbo = 24'hFE932A;
            8'd186: rgb_turbo = 24'hFE9029;
            8'd187: rgb_turbo = 24'hFD8D27;
            8'd188: rgb_turbo = 24'hFD8A26;
            8'd189: rgb_turbo = 24'hFC8725;
            8'd190: rgb_turbo = 24'hFC8423;
            8'd191: rgb_turbo = 24'hFB8122;
            8'd192: rgb_turbo = 24'hFB7E21;
            8'd193: rgb_turbo = 24'hFA7B1F;
            8'd194: rgb_turbo = 24'hF9781E;
            8'd195: rgb_turbo = 24'hF9751D;
            8'd196: rgb_turbo = 24'hF8721C;
            8'd197: rgb_turbo = 24'hF76F1A;
            8'd198: rgb_turbo = 24'hF66C19;
            8'd199: rgb_turbo = 24'hF56918;
            8'd200: rgb_turbo = 24'hF46617;
            8'd201: rgb_turbo = 24'hF36315;
            8'd202: rgb_turbo = 24'hF26014;
            8'd203: rgb_turbo = 24'hF15D13;
            8'd204: rgb_turbo = 24'hF05B12;
            8'd205: rgb_turbo = 24'hEF5811;
            8'd206: rgb_turbo = 24'hED5510;
            8'd207: rgb_turbo = 24'hEC530F;
            8'd208: rgb_turbo = 24'hEB500E;
            8'd209: rgb_turbo = 24'hEA4E0D;
            8'd210: rgb_turbo = 24'hE84B0C;
            8'd211: rgb_turbo = 24'hE7490C;
            8'd212: rgb_turbo = 24'hE5470B;
            8'd213: rgb_turbo = 24'hE4450A;
            8'd214: rgb_turbo = 24'hE2430A;
            8'd215: rgb_turbo = 24'hE14109;
            8'd216: rgb_turbo = 24'hDF3F08;
            8'd217: rgb_turbo = 24'hDD3D08;
            8'd218: rgb_turbo = 24'hDC3B07;
            8'd219: rgb_turbo = 24'hDA3907;
            8'd220: rgb_turbo = 24'hD83706;
            8'd221: rgb_turbo = 24'hD63506;
            8'd222: rgb_turbo = 24'hD43305;
            8'd223: rgb_turbo = 24'hD23105;
            8'd224: rgb_turbo = 24'hD02F05;
            8'd225: rgb_turbo = 24'hCE2D04;
            8'd226: rgb_turbo = 24'hCC2B04;
            8'd227: rgb_turbo = 24'hCA2A04;
            8'd228: rgb_turbo = 24'hC82803;
            8'd229: rgb_turbo = 24'hC52603;
            8'd230: rgb_turbo = 24'hC32503;
            8'd231: rgb_turbo = 24'hC12302;
            8'd232: rgb_turbo = 24'hBE2102;
            8'd233: rgb_turbo = 24'hBC2002;
            8'd234: rgb_turbo = 24'hB91E02;
            8'd235: rgb_turbo = 24'hB71D02;
            8'd236: rgb_turbo = 24'hB41B01;
            8'd237: rgb_turbo = 24'hB21A01;
            8'd238: rgb_turbo = 24'hAF1801;
            8'd239: rgb_turbo = 24'hAC1701;
            8'd240: rgb_turbo = 24'hA91601;
            8'd241: rgb_turbo = 24'hA71401;
            8'd242: rgb_turbo = 24'hA41301;
            8'd243: rgb_turbo = 24'hA11201;
            8'd244: rgb_turbo = 24'h9E1001;
            8'd245: rgb_turbo = 24'h9B0F01;
            8'd246: rgb_turbo = 24'h980E01;
            8'd247: rgb_turbo = 24'h950D01;
            8'd248: rgb_turbo = 24'h920B01;
            8'd249: rgb_turbo = 24'h8E0A01;
            8'd250: rgb_turbo = 24'h8B0902;
            8'd251: rgb_turbo = 24'h880802;
            8'd252: rgb_turbo = 24'h850702;
            8'd253: rgb_turbo = 24'h810602;
            8'd254: rgb_turbo = 24'h7E0502;
            8'd255: rgb_turbo = 24'h7A0403;
            default: rgb_turbo = 24'h000000;   // never used (all 256 codes listed)
        endcase
    end

    // ========================================================================
    // Output: palette chosen at compile time
    // ========================================================================
    logic [23:0] rgb;

    assign rgb = TURBO ? rgb_turbo : rgb_hot;

    assign red   = rgb[23:16];
    assign green = rgb[15:8];
    assign blue  = rgb[7:0];

endmodule