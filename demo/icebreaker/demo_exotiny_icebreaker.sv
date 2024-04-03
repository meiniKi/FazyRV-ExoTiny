// Copyright (c) 2024 Meinhard Kissich
// -----------------------------------------------------------------------------
// File  :  demo_exotiny_icebreaker.sv
// Usage :  Wrapper for the icebreaker board
// -----------------------------------------------------------------------------

`timescale 1 ns / 1 ps

module demo_exotiny_icebreaker (
  input  logic        clk_i,
  input  logic        rst_in,
  // QSPI
  output logic        cs_ram_on,
  output logic        cs_rom_on,
  output logic        sck_o,
  inout  logic [3:0]  sdio_io,
  //
  output logic        gpo_o,
  output logic        led_r_n,
  output logic        led_g_n
);

localparam CHUNKSIZE  = 4;
localparam RFTYPE     = "BRAM";
localparam CONF       = "MIN";

assign led_r_n = 1'b1;
assign led_g_n = 1'b1;

// clk_i 12MHz, no PLL for testing

logic [3:0] core_sdo;
logic [3:0] core_sdi;
logic [3:0] core_sdoen;

SB_IO #(
  .PIN_TYPE       ( 6'b1010_01 ),
  .PULLUP         ( 1'b0       )
) io_sda[3:0] (
  .PACKAGE_PIN    ( sdio_io    ),
  .OUTPUT_ENABLE  ( core_sdoen ),
  .D_OUT_0        ( core_sdo   ),
  .D_IN_0         ( core_sdi   )
);

exotiny #( 
  .CHUNKSIZE  ( CHUNKSIZE ),
  .CONF       ( CONF      ),
  .RFTYPE     ( RFTYPE    ),
  .GPOCNT     ( 'd1       )
) i_exotiny (
  .clk_i          ( clk_i   ),
  .rst_in         ( rst_in  ),
  .gpi_i          ( 1'b0    ),
  .gpo_o          ( gpo_o   ),

  .mem_cs_ram_on  ( cs_ram_n    ),
  .mem_cs_rom_on  ( cs_rom_n    ),
  .mem_sck_o      ( sck         ),
  .mem_sd_i       ( core_sdi    ),
  .mem_sd_o       ( core_sdo    ),
  .mem_sd_oen_o   ( core_sdoen  )
);

endmodule
