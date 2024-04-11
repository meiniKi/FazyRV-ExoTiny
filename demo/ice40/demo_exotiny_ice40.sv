// Copyright (c) 2024 Meinhard Kissich
// -----------------------------------------------------------------------------
// File  :  demo_exotiny_ice40.sv
// Usage :  Wrapper for ice40 FPGAs
// -----------------------------------------------------------------------------

`timescale 1 ns / 1 ps

module demo_exotiny_ice40 (
  input  logic        clk_i,
  input  logic        rst_i,
  // QSPI
  output logic        cs_ram_on,
  output logic        cs_rom_on,
  output logic        sck_o,
  inout  logic [3:0]  sdio_io,
  //
  output logic        led_rst_n,
  output logic        led_r_n,
  output logic        led_g_n,
  //
  output logic        spi_sck_o,
  output logic        spi_sdo_o,
  input  logic        spi_sdi_i,
  //
  output logic [2:0]  dbg_o
);

localparam CHUNKSIZE  = 2;
localparam RFTYPE     = "BRAM";
localparam CONF       = "MIN";

// Reset sync
logic       rst_sync;
always_ff @(posedge clk_i) rst_sync <= rst_i;


logic rst_n;
logic locked;
logic clk_sys;

logic [5:0] gpo;
assign {led_r_n, led_g_n} = gpo[1:0];

assign dbg_o[0] = cs_ram_on;
assign dbg_o[2] = cs_rom_on;
assign dbg_o[1] = gpo[0];


// Divide further for testing
logic clk_inter;
logic [3:0] clk_cnt;

always_ff @(posedge clk_inter) clk_cnt <= clk_cnt + 'b1;
assign clk_sys = clk_cnt[3];

SB_PLL40_PAD #(
		.FEEDBACK_PATH("SIMPLE"),
		.DIVR(4'b0011),		// DIVR =  3
		.DIVF(7'b0101000),	// DIVF = 40
		.DIVQ(3'b110),		// DIVQ =  6
		.FILTER_RANGE(3'b010)	// FILTER_RANGE = 2
) i_SB_PLL40_PAD (   
  .PACKAGEPIN    ( clk_i    ),
  .PLLOUTGLOBAL  ( clk_inter  ),
  .RESETB        ( ~rst_sync  ),
  .BYPASS        ( 1'b0       ),
  .LOCK          ( locked     )
);


// --- Reset logic ---
logic [7:0] locked_dly_r;

always @(posedge clk_sys) begin
  if (~locked | rst_sync) begin
    locked_dly_r <= 'b0;
  end else begin
    if (~&locked_dly_r) locked_dly_r <= locked_dly_r + 'b1;
  end
end

assign rst_n      = locked & ~rst_sync & (&locked_dly_r);
assign led_rst_n  = rst_n; 
// ---- 

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
) i_exotiny (
  .clk_i          ( clk_sys ),
  .rst_in         ( rst_n   ),
  .gpi_i          ( 6'b0    ),
  .gpo_o          ( gpo     ),

  .mem_cs_ram_on  ( cs_ram_on   ),
  .mem_cs_rom_on  ( cs_rom_on   ),
  .mem_sck_o      ( sck_o       ),
  .mem_sd_i       ( core_sdi    ),
  .mem_sd_o       ( core_sdo    ),
  .mem_sd_oen_o   ( core_sdoen  ),

  .spi_sck_o      ( spi_sck_o   ),
  .spi_sdo_o      ( spi_sdo_o   ),
  .spi_sdi_i      ( spi_sdi_i   )
);

endmodule
