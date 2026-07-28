//Copyright (C)2014-2026 Gowin Semiconductor Corporation.
//All rights reserved.
//File Title: IP file
//Tool Version: V1.9.12.02_SP1 (64-bit)
//IP Version: 1.0
//Part Number: GW1NR-LV9QN88PC6/I5
//Device: GW1NR-9
//Device Version: C
//Created Time: Mon Jul 27 12:45:34 2026

module Gowin_SDP (dout, clka, cea, reseta, clkb, ceb, resetb, oce, ada, din, adb);

output [7:0] dout;
input clka;
input cea;
input reseta;
input clkb;
input ceb;
input resetb;
input oce;
input [14:0] ada;
input [7:0] din;
input [14:0] adb;

wire lut_f_0;
wire lut_f_1;
wire [27:0] sdpb_inst_0_dout_w;
wire [3:0] sdpb_inst_0_dout;
wire [27:0] sdpb_inst_1_dout_w;
wire [3:0] sdpb_inst_1_dout;
wire [27:0] sdpb_inst_2_dout_w;
wire [3:0] sdpb_inst_2_dout;
wire [27:0] sdpb_inst_3_dout_w;
wire [3:0] sdpb_inst_3_dout;
wire [27:0] sdpb_inst_4_dout_w;
wire [7:4] sdpb_inst_4_dout;
wire [27:0] sdpb_inst_5_dout_w;
wire [7:4] sdpb_inst_5_dout;
wire [27:0] sdpb_inst_6_dout_w;
wire [7:4] sdpb_inst_6_dout;
wire [27:0] sdpb_inst_7_dout_w;
wire [7:4] sdpb_inst_7_dout;
wire [27:0] sdpb_inst_8_dout_w;
wire [3:0] sdpb_inst_8_dout;
wire [27:0] sdpb_inst_9_dout_w;
wire [3:0] sdpb_inst_9_dout;
wire [27:0] sdpb_inst_10_dout_w;
wire [7:4] sdpb_inst_10_dout;
wire [27:0] sdpb_inst_11_dout_w;
wire [7:4] sdpb_inst_11_dout;
wire [23:0] sdpb_inst_12_dout_w;
wire [7:0] sdpb_inst_12_dout;
wire dff_q_0;
wire dff_q_1;
wire dff_q_2;
wire mux_o_7;
wire mux_o_8;
wire mux_o_9;
wire mux_o_11;
wire mux_o_12;
wire mux_o_21;
wire mux_o_22;
wire mux_o_23;
wire mux_o_25;
wire mux_o_26;
wire mux_o_35;
wire mux_o_36;
wire mux_o_37;
wire mux_o_39;
wire mux_o_40;
wire mux_o_49;
wire mux_o_50;
wire mux_o_51;
wire mux_o_53;
wire mux_o_54;
wire mux_o_63;
wire mux_o_64;
wire mux_o_65;
wire mux_o_67;
wire mux_o_68;
wire mux_o_77;
wire mux_o_78;
wire mux_o_79;
wire mux_o_81;
wire mux_o_82;
wire mux_o_91;
wire mux_o_92;
wire mux_o_93;
wire mux_o_95;
wire mux_o_96;
wire mux_o_105;
wire mux_o_106;
wire mux_o_107;
wire mux_o_109;
wire mux_o_110;
wire gw_gnd;

assign gw_gnd = 1'b0;

LUT4 lut_inst_0 (
  .F(lut_f_0),
  .I0(ada[11]),
  .I1(ada[12]),
  .I2(ada[13]),
  .I3(ada[14])
);
defparam lut_inst_0.INIT = 16'h1000;
LUT4 lut_inst_1 (
  .F(lut_f_1),
  .I0(adb[11]),
  .I1(adb[12]),
  .I2(adb[13]),
  .I3(adb[14])
);
defparam lut_inst_1.INIT = 16'h1000;
SDPB sdpb_inst_0 (
    .DO({sdpb_inst_0_dout_w[27:0],sdpb_inst_0_dout[3:0]}),
    .CLKA(clka),
    .CEA(cea),
    .RESETA(reseta),
    .CLKB(clkb),
    .CEB(ceb),
    .RESETB(resetb),
    .OCE(oce),
    .BLKSELA({ada[14],ada[13],ada[12]}),
    .BLKSELB({adb[14],adb[13],adb[12]}),
    .ADA({ada[11:0],gw_gnd,gw_gnd}),
    .DI({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,din[3:0]}),
    .ADB({adb[11:0],gw_gnd,gw_gnd})
);

defparam sdpb_inst_0.READ_MODE = 1'b0;
defparam sdpb_inst_0.BIT_WIDTH_0 = 4;
defparam sdpb_inst_0.BIT_WIDTH_1 = 4;
defparam sdpb_inst_0.BLK_SEL_0 = 3'b000;
defparam sdpb_inst_0.BLK_SEL_1 = 3'b000;
defparam sdpb_inst_0.RESET_MODE = "SYNC";

SDPB sdpb_inst_1 (
    .DO({sdpb_inst_1_dout_w[27:0],sdpb_inst_1_dout[3:0]}),
    .CLKA(clka),
    .CEA(cea),
    .RESETA(reseta),
    .CLKB(clkb),
    .CEB(ceb),
    .RESETB(resetb),
    .OCE(oce),
    .BLKSELA({ada[14],ada[13],ada[12]}),
    .BLKSELB({adb[14],adb[13],adb[12]}),
    .ADA({ada[11:0],gw_gnd,gw_gnd}),
    .DI({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,din[3:0]}),
    .ADB({adb[11:0],gw_gnd,gw_gnd})
);

defparam sdpb_inst_1.READ_MODE = 1'b0;
defparam sdpb_inst_1.BIT_WIDTH_0 = 4;
defparam sdpb_inst_1.BIT_WIDTH_1 = 4;
defparam sdpb_inst_1.BLK_SEL_0 = 3'b001;
defparam sdpb_inst_1.BLK_SEL_1 = 3'b001;
defparam sdpb_inst_1.RESET_MODE = "SYNC";

SDPB sdpb_inst_2 (
    .DO({sdpb_inst_2_dout_w[27:0],sdpb_inst_2_dout[3:0]}),
    .CLKA(clka),
    .CEA(cea),
    .RESETA(reseta),
    .CLKB(clkb),
    .CEB(ceb),
    .RESETB(resetb),
    .OCE(oce),
    .BLKSELA({ada[14],ada[13],ada[12]}),
    .BLKSELB({adb[14],adb[13],adb[12]}),
    .ADA({ada[11:0],gw_gnd,gw_gnd}),
    .DI({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,din[3:0]}),
    .ADB({adb[11:0],gw_gnd,gw_gnd})
);

defparam sdpb_inst_2.READ_MODE = 1'b0;
defparam sdpb_inst_2.BIT_WIDTH_0 = 4;
defparam sdpb_inst_2.BIT_WIDTH_1 = 4;
defparam sdpb_inst_2.BLK_SEL_0 = 3'b010;
defparam sdpb_inst_2.BLK_SEL_1 = 3'b010;
defparam sdpb_inst_2.RESET_MODE = "SYNC";

SDPB sdpb_inst_3 (
    .DO({sdpb_inst_3_dout_w[27:0],sdpb_inst_3_dout[3:0]}),
    .CLKA(clka),
    .CEA(cea),
    .RESETA(reseta),
    .CLKB(clkb),
    .CEB(ceb),
    .RESETB(resetb),
    .OCE(oce),
    .BLKSELA({ada[14],ada[13],ada[12]}),
    .BLKSELB({adb[14],adb[13],adb[12]}),
    .ADA({ada[11:0],gw_gnd,gw_gnd}),
    .DI({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,din[3:0]}),
    .ADB({adb[11:0],gw_gnd,gw_gnd})
);

defparam sdpb_inst_3.READ_MODE = 1'b0;
defparam sdpb_inst_3.BIT_WIDTH_0 = 4;
defparam sdpb_inst_3.BIT_WIDTH_1 = 4;
defparam sdpb_inst_3.BLK_SEL_0 = 3'b011;
defparam sdpb_inst_3.BLK_SEL_1 = 3'b011;
defparam sdpb_inst_3.RESET_MODE = "SYNC";

SDPB sdpb_inst_4 (
    .DO({sdpb_inst_4_dout_w[27:0],sdpb_inst_4_dout[7:4]}),
    .CLKA(clka),
    .CEA(cea),
    .RESETA(reseta),
    .CLKB(clkb),
    .CEB(ceb),
    .RESETB(resetb),
    .OCE(oce),
    .BLKSELA({ada[14],ada[13],ada[12]}),
    .BLKSELB({adb[14],adb[13],adb[12]}),
    .ADA({ada[11:0],gw_gnd,gw_gnd}),
    .DI({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,din[7:4]}),
    .ADB({adb[11:0],gw_gnd,gw_gnd})
);

defparam sdpb_inst_4.READ_MODE = 1'b0;
defparam sdpb_inst_4.BIT_WIDTH_0 = 4;
defparam sdpb_inst_4.BIT_WIDTH_1 = 4;
defparam sdpb_inst_4.BLK_SEL_0 = 3'b000;
defparam sdpb_inst_4.BLK_SEL_1 = 3'b000;
defparam sdpb_inst_4.RESET_MODE = "SYNC";

SDPB sdpb_inst_5 (
    .DO({sdpb_inst_5_dout_w[27:0],sdpb_inst_5_dout[7:4]}),
    .CLKA(clka),
    .CEA(cea),
    .RESETA(reseta),
    .CLKB(clkb),
    .CEB(ceb),
    .RESETB(resetb),
    .OCE(oce),
    .BLKSELA({ada[14],ada[13],ada[12]}),
    .BLKSELB({adb[14],adb[13],adb[12]}),
    .ADA({ada[11:0],gw_gnd,gw_gnd}),
    .DI({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,din[7:4]}),
    .ADB({adb[11:0],gw_gnd,gw_gnd})
);

defparam sdpb_inst_5.READ_MODE = 1'b0;
defparam sdpb_inst_5.BIT_WIDTH_0 = 4;
defparam sdpb_inst_5.BIT_WIDTH_1 = 4;
defparam sdpb_inst_5.BLK_SEL_0 = 3'b001;
defparam sdpb_inst_5.BLK_SEL_1 = 3'b001;
defparam sdpb_inst_5.RESET_MODE = "SYNC";

SDPB sdpb_inst_6 (
    .DO({sdpb_inst_6_dout_w[27:0],sdpb_inst_6_dout[7:4]}),
    .CLKA(clka),
    .CEA(cea),
    .RESETA(reseta),
    .CLKB(clkb),
    .CEB(ceb),
    .RESETB(resetb),
    .OCE(oce),
    .BLKSELA({ada[14],ada[13],ada[12]}),
    .BLKSELB({adb[14],adb[13],adb[12]}),
    .ADA({ada[11:0],gw_gnd,gw_gnd}),
    .DI({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,din[7:4]}),
    .ADB({adb[11:0],gw_gnd,gw_gnd})
);

defparam sdpb_inst_6.READ_MODE = 1'b0;
defparam sdpb_inst_6.BIT_WIDTH_0 = 4;
defparam sdpb_inst_6.BIT_WIDTH_1 = 4;
defparam sdpb_inst_6.BLK_SEL_0 = 3'b010;
defparam sdpb_inst_6.BLK_SEL_1 = 3'b010;
defparam sdpb_inst_6.RESET_MODE = "SYNC";

SDPB sdpb_inst_7 (
    .DO({sdpb_inst_7_dout_w[27:0],sdpb_inst_7_dout[7:4]}),
    .CLKA(clka),
    .CEA(cea),
    .RESETA(reseta),
    .CLKB(clkb),
    .CEB(ceb),
    .RESETB(resetb),
    .OCE(oce),
    .BLKSELA({ada[14],ada[13],ada[12]}),
    .BLKSELB({adb[14],adb[13],adb[12]}),
    .ADA({ada[11:0],gw_gnd,gw_gnd}),
    .DI({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,din[7:4]}),
    .ADB({adb[11:0],gw_gnd,gw_gnd})
);

defparam sdpb_inst_7.READ_MODE = 1'b0;
defparam sdpb_inst_7.BIT_WIDTH_0 = 4;
defparam sdpb_inst_7.BIT_WIDTH_1 = 4;
defparam sdpb_inst_7.BLK_SEL_0 = 3'b011;
defparam sdpb_inst_7.BLK_SEL_1 = 3'b011;
defparam sdpb_inst_7.RESET_MODE = "SYNC";

SDPB sdpb_inst_8 (
    .DO({sdpb_inst_8_dout_w[27:0],sdpb_inst_8_dout[3:0]}),
    .CLKA(clka),
    .CEA(cea),
    .RESETA(reseta),
    .CLKB(clkb),
    .CEB(ceb),
    .RESETB(resetb),
    .OCE(oce),
    .BLKSELA({ada[14],ada[13],ada[12]}),
    .BLKSELB({adb[14],adb[13],adb[12]}),
    .ADA({ada[11:0],gw_gnd,gw_gnd}),
    .DI({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,din[3:0]}),
    .ADB({adb[11:0],gw_gnd,gw_gnd})
);

defparam sdpb_inst_8.READ_MODE = 1'b0;
defparam sdpb_inst_8.BIT_WIDTH_0 = 4;
defparam sdpb_inst_8.BIT_WIDTH_1 = 4;
defparam sdpb_inst_8.BLK_SEL_0 = 3'b100;
defparam sdpb_inst_8.BLK_SEL_1 = 3'b100;
defparam sdpb_inst_8.RESET_MODE = "SYNC";

SDPB sdpb_inst_9 (
    .DO({sdpb_inst_9_dout_w[27:0],sdpb_inst_9_dout[3:0]}),
    .CLKA(clka),
    .CEA(cea),
    .RESETA(reseta),
    .CLKB(clkb),
    .CEB(ceb),
    .RESETB(resetb),
    .OCE(oce),
    .BLKSELA({ada[14],ada[13],ada[12]}),
    .BLKSELB({adb[14],adb[13],adb[12]}),
    .ADA({ada[11:0],gw_gnd,gw_gnd}),
    .DI({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,din[3:0]}),
    .ADB({adb[11:0],gw_gnd,gw_gnd})
);

defparam sdpb_inst_9.READ_MODE = 1'b0;
defparam sdpb_inst_9.BIT_WIDTH_0 = 4;
defparam sdpb_inst_9.BIT_WIDTH_1 = 4;
defparam sdpb_inst_9.BLK_SEL_0 = 3'b101;
defparam sdpb_inst_9.BLK_SEL_1 = 3'b101;
defparam sdpb_inst_9.RESET_MODE = "SYNC";

SDPB sdpb_inst_10 (
    .DO({sdpb_inst_10_dout_w[27:0],sdpb_inst_10_dout[7:4]}),
    .CLKA(clka),
    .CEA(cea),
    .RESETA(reseta),
    .CLKB(clkb),
    .CEB(ceb),
    .RESETB(resetb),
    .OCE(oce),
    .BLKSELA({ada[14],ada[13],ada[12]}),
    .BLKSELB({adb[14],adb[13],adb[12]}),
    .ADA({ada[11:0],gw_gnd,gw_gnd}),
    .DI({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,din[7:4]}),
    .ADB({adb[11:0],gw_gnd,gw_gnd})
);

defparam sdpb_inst_10.READ_MODE = 1'b0;
defparam sdpb_inst_10.BIT_WIDTH_0 = 4;
defparam sdpb_inst_10.BIT_WIDTH_1 = 4;
defparam sdpb_inst_10.BLK_SEL_0 = 3'b100;
defparam sdpb_inst_10.BLK_SEL_1 = 3'b100;
defparam sdpb_inst_10.RESET_MODE = "SYNC";

SDPB sdpb_inst_11 (
    .DO({sdpb_inst_11_dout_w[27:0],sdpb_inst_11_dout[7:4]}),
    .CLKA(clka),
    .CEA(cea),
    .RESETA(reseta),
    .CLKB(clkb),
    .CEB(ceb),
    .RESETB(resetb),
    .OCE(oce),
    .BLKSELA({ada[14],ada[13],ada[12]}),
    .BLKSELB({adb[14],adb[13],adb[12]}),
    .ADA({ada[11:0],gw_gnd,gw_gnd}),
    .DI({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,din[7:4]}),
    .ADB({adb[11:0],gw_gnd,gw_gnd})
);

defparam sdpb_inst_11.READ_MODE = 1'b0;
defparam sdpb_inst_11.BIT_WIDTH_0 = 4;
defparam sdpb_inst_11.BIT_WIDTH_1 = 4;
defparam sdpb_inst_11.BLK_SEL_0 = 3'b101;
defparam sdpb_inst_11.BLK_SEL_1 = 3'b101;
defparam sdpb_inst_11.RESET_MODE = "SYNC";

SDPB sdpb_inst_12 (
    .DO({sdpb_inst_12_dout_w[23:0],sdpb_inst_12_dout[7:0]}),
    .CLKA(clka),
    .CEA(cea),
    .RESETA(reseta),
    .CLKB(clkb),
    .CEB(ceb),
    .RESETB(resetb),
    .OCE(oce),
    .BLKSELA({gw_gnd,gw_gnd,lut_f_0}),
    .BLKSELB({gw_gnd,gw_gnd,lut_f_1}),
    .ADA({ada[10:0],gw_gnd,gw_gnd,gw_gnd}),
    .DI({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,din[7:0]}),
    .ADB({adb[10:0],gw_gnd,gw_gnd,gw_gnd})
);

defparam sdpb_inst_12.READ_MODE = 1'b0;
defparam sdpb_inst_12.BIT_WIDTH_0 = 8;
defparam sdpb_inst_12.BIT_WIDTH_1 = 8;
defparam sdpb_inst_12.BLK_SEL_0 = 3'b001;
defparam sdpb_inst_12.BLK_SEL_1 = 3'b001;
defparam sdpb_inst_12.RESET_MODE = "SYNC";

DFFE dff_inst_0 (
  .Q(dff_q_0),
  .D(adb[14]),
  .CLK(clkb),
  .CE(ceb)
);
DFFE dff_inst_1 (
  .Q(dff_q_1),
  .D(adb[13]),
  .CLK(clkb),
  .CE(ceb)
);
DFFE dff_inst_2 (
  .Q(dff_q_2),
  .D(adb[12]),
  .CLK(clkb),
  .CE(ceb)
);
MUX2 mux_inst_7 (
  .O(mux_o_7),
  .I0(sdpb_inst_0_dout[0]),
  .I1(sdpb_inst_1_dout[0]),
  .S0(dff_q_2)
);
MUX2 mux_inst_8 (
  .O(mux_o_8),
  .I0(sdpb_inst_2_dout[0]),
  .I1(sdpb_inst_3_dout[0]),
  .S0(dff_q_2)
);
MUX2 mux_inst_9 (
  .O(mux_o_9),
  .I0(sdpb_inst_8_dout[0]),
  .I1(sdpb_inst_9_dout[0]),
  .S0(dff_q_2)
);
MUX2 mux_inst_11 (
  .O(mux_o_11),
  .I0(mux_o_7),
  .I1(mux_o_8),
  .S0(dff_q_1)
);
MUX2 mux_inst_12 (
  .O(mux_o_12),
  .I0(mux_o_9),
  .I1(sdpb_inst_12_dout[0]),
  .S0(dff_q_1)
);
MUX2 mux_inst_13 (
  .O(dout[0]),
  .I0(mux_o_11),
  .I1(mux_o_12),
  .S0(dff_q_0)
);
MUX2 mux_inst_21 (
  .O(mux_o_21),
  .I0(sdpb_inst_0_dout[1]),
  .I1(sdpb_inst_1_dout[1]),
  .S0(dff_q_2)
);
MUX2 mux_inst_22 (
  .O(mux_o_22),
  .I0(sdpb_inst_2_dout[1]),
  .I1(sdpb_inst_3_dout[1]),
  .S0(dff_q_2)
);
MUX2 mux_inst_23 (
  .O(mux_o_23),
  .I0(sdpb_inst_8_dout[1]),
  .I1(sdpb_inst_9_dout[1]),
  .S0(dff_q_2)
);
MUX2 mux_inst_25 (
  .O(mux_o_25),
  .I0(mux_o_21),
  .I1(mux_o_22),
  .S0(dff_q_1)
);
MUX2 mux_inst_26 (
  .O(mux_o_26),
  .I0(mux_o_23),
  .I1(sdpb_inst_12_dout[1]),
  .S0(dff_q_1)
);
MUX2 mux_inst_27 (
  .O(dout[1]),
  .I0(mux_o_25),
  .I1(mux_o_26),
  .S0(dff_q_0)
);
MUX2 mux_inst_35 (
  .O(mux_o_35),
  .I0(sdpb_inst_0_dout[2]),
  .I1(sdpb_inst_1_dout[2]),
  .S0(dff_q_2)
);
MUX2 mux_inst_36 (
  .O(mux_o_36),
  .I0(sdpb_inst_2_dout[2]),
  .I1(sdpb_inst_3_dout[2]),
  .S0(dff_q_2)
);
MUX2 mux_inst_37 (
  .O(mux_o_37),
  .I0(sdpb_inst_8_dout[2]),
  .I1(sdpb_inst_9_dout[2]),
  .S0(dff_q_2)
);
MUX2 mux_inst_39 (
  .O(mux_o_39),
  .I0(mux_o_35),
  .I1(mux_o_36),
  .S0(dff_q_1)
);
MUX2 mux_inst_40 (
  .O(mux_o_40),
  .I0(mux_o_37),
  .I1(sdpb_inst_12_dout[2]),
  .S0(dff_q_1)
);
MUX2 mux_inst_41 (
  .O(dout[2]),
  .I0(mux_o_39),
  .I1(mux_o_40),
  .S0(dff_q_0)
);
MUX2 mux_inst_49 (
  .O(mux_o_49),
  .I0(sdpb_inst_0_dout[3]),
  .I1(sdpb_inst_1_dout[3]),
  .S0(dff_q_2)
);
MUX2 mux_inst_50 (
  .O(mux_o_50),
  .I0(sdpb_inst_2_dout[3]),
  .I1(sdpb_inst_3_dout[3]),
  .S0(dff_q_2)
);
MUX2 mux_inst_51 (
  .O(mux_o_51),
  .I0(sdpb_inst_8_dout[3]),
  .I1(sdpb_inst_9_dout[3]),
  .S0(dff_q_2)
);
MUX2 mux_inst_53 (
  .O(mux_o_53),
  .I0(mux_o_49),
  .I1(mux_o_50),
  .S0(dff_q_1)
);
MUX2 mux_inst_54 (
  .O(mux_o_54),
  .I0(mux_o_51),
  .I1(sdpb_inst_12_dout[3]),
  .S0(dff_q_1)
);
MUX2 mux_inst_55 (
  .O(dout[3]),
  .I0(mux_o_53),
  .I1(mux_o_54),
  .S0(dff_q_0)
);
MUX2 mux_inst_63 (
  .O(mux_o_63),
  .I0(sdpb_inst_4_dout[4]),
  .I1(sdpb_inst_5_dout[4]),
  .S0(dff_q_2)
);
MUX2 mux_inst_64 (
  .O(mux_o_64),
  .I0(sdpb_inst_6_dout[4]),
  .I1(sdpb_inst_7_dout[4]),
  .S0(dff_q_2)
);
MUX2 mux_inst_65 (
  .O(mux_o_65),
  .I0(sdpb_inst_10_dout[4]),
  .I1(sdpb_inst_11_dout[4]),
  .S0(dff_q_2)
);
MUX2 mux_inst_67 (
  .O(mux_o_67),
  .I0(mux_o_63),
  .I1(mux_o_64),
  .S0(dff_q_1)
);
MUX2 mux_inst_68 (
  .O(mux_o_68),
  .I0(mux_o_65),
  .I1(sdpb_inst_12_dout[4]),
  .S0(dff_q_1)
);
MUX2 mux_inst_69 (
  .O(dout[4]),
  .I0(mux_o_67),
  .I1(mux_o_68),
  .S0(dff_q_0)
);
MUX2 mux_inst_77 (
  .O(mux_o_77),
  .I0(sdpb_inst_4_dout[5]),
  .I1(sdpb_inst_5_dout[5]),
  .S0(dff_q_2)
);
MUX2 mux_inst_78 (
  .O(mux_o_78),
  .I0(sdpb_inst_6_dout[5]),
  .I1(sdpb_inst_7_dout[5]),
  .S0(dff_q_2)
);
MUX2 mux_inst_79 (
  .O(mux_o_79),
  .I0(sdpb_inst_10_dout[5]),
  .I1(sdpb_inst_11_dout[5]),
  .S0(dff_q_2)
);
MUX2 mux_inst_81 (
  .O(mux_o_81),
  .I0(mux_o_77),
  .I1(mux_o_78),
  .S0(dff_q_1)
);
MUX2 mux_inst_82 (
  .O(mux_o_82),
  .I0(mux_o_79),
  .I1(sdpb_inst_12_dout[5]),
  .S0(dff_q_1)
);
MUX2 mux_inst_83 (
  .O(dout[5]),
  .I0(mux_o_81),
  .I1(mux_o_82),
  .S0(dff_q_0)
);
MUX2 mux_inst_91 (
  .O(mux_o_91),
  .I0(sdpb_inst_4_dout[6]),
  .I1(sdpb_inst_5_dout[6]),
  .S0(dff_q_2)
);
MUX2 mux_inst_92 (
  .O(mux_o_92),
  .I0(sdpb_inst_6_dout[6]),
  .I1(sdpb_inst_7_dout[6]),
  .S0(dff_q_2)
);
MUX2 mux_inst_93 (
  .O(mux_o_93),
  .I0(sdpb_inst_10_dout[6]),
  .I1(sdpb_inst_11_dout[6]),
  .S0(dff_q_2)
);
MUX2 mux_inst_95 (
  .O(mux_o_95),
  .I0(mux_o_91),
  .I1(mux_o_92),
  .S0(dff_q_1)
);
MUX2 mux_inst_96 (
  .O(mux_o_96),
  .I0(mux_o_93),
  .I1(sdpb_inst_12_dout[6]),
  .S0(dff_q_1)
);
MUX2 mux_inst_97 (
  .O(dout[6]),
  .I0(mux_o_95),
  .I1(mux_o_96),
  .S0(dff_q_0)
);
MUX2 mux_inst_105 (
  .O(mux_o_105),
  .I0(sdpb_inst_4_dout[7]),
  .I1(sdpb_inst_5_dout[7]),
  .S0(dff_q_2)
);
MUX2 mux_inst_106 (
  .O(mux_o_106),
  .I0(sdpb_inst_6_dout[7]),
  .I1(sdpb_inst_7_dout[7]),
  .S0(dff_q_2)
);
MUX2 mux_inst_107 (
  .O(mux_o_107),
  .I0(sdpb_inst_10_dout[7]),
  .I1(sdpb_inst_11_dout[7]),
  .S0(dff_q_2)
);
MUX2 mux_inst_109 (
  .O(mux_o_109),
  .I0(mux_o_105),
  .I1(mux_o_106),
  .S0(dff_q_1)
);
MUX2 mux_inst_110 (
  .O(mux_o_110),
  .I0(mux_o_107),
  .I1(sdpb_inst_12_dout[7]),
  .S0(dff_q_1)
);
MUX2 mux_inst_111 (
  .O(dout[7]),
  .I0(mux_o_109),
  .I1(mux_o_110),
  .S0(dff_q_0)
);
endmodule //Gowin_SDP
