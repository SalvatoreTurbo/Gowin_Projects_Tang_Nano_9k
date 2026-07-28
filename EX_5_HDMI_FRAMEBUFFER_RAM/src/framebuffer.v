// ============================================================================
// MODULO: framebuffer
// DESCRIPTION: Synchronous framebuffer stored in BRAM (Single port RAM).
//
// Pixel format: RGB332 (8-bit)
// One clock latency on read
// ============================================================================

module framebuffer #( 
    parameter int FRAME_SIZE = 19200,
    parameter int ADDR_BITS  = $clog2(FRAME_SIZE) 
)(
    input logic clk,
    input logic rst_n,

    input logic [ADDR_BITS-1:0] addr,

    input logic wr_en,
    input logic [7:0] wr_data,

    output logic [7:0] rd_data
);

        wire [15:0] addr_ext;
        assign addr_ext = {{(16-ADDR_BITS){1'b0}}, addr};   //perche addr può non essere a 16 bit      

        Gowin_SP ram(
        .dout(rd_data), //output 
        .clk(clk), //input clk
        .oce(1'b1), //input oce
        .ce(1'b1), //input ce
        .reset(~rst_n), //input reset
        .wre(wr_en), //input wre
        .ad(addr_ext), //address
        .din(wr_data) //input  
    );

endmodule