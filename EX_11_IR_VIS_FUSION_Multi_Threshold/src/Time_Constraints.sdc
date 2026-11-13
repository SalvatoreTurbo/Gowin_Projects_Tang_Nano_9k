// Board clock (27 MHz)
create_clock -name clk_27MHz -period 37.037 [get_ports {clk_27MHz}]

// OV5640 pixel clock: estimated ~56 MHz from the PLL registers (to be verified by measurement)
create_clock -name ov_pclk -period 17.857 [get_ports {ov_pclk}]

// VIGIL80 SPI clock (4.6 MHz)
create_clock -name vigil_sck -period 217.4 [get_ports {vigil_sck}]

// The three clock sources are unrelated: no timing check between them (CDC handled by 2-FF synchronizers)
set_clock_groups -asynchronous -group [get_clocks {clk_27MHz}] -group [get_clocks {ov_pclk}] -group [get_clocks {vigil_sck}]