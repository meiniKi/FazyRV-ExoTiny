// Copyright (c) 2023 - 2024 Meinhard Kissich
// -----------------------------------------------------------------------------
// File  :  exotiny_sim.sv
// Usage :  Simulation wrapper for FazyRV ExoTiny.
// -----------------------------------------------------------------------------

`timescale 1 ns / 1 ps

module exotiny_sim #( 
  parameter CHUNKSIZE = 8,
  parameter CONF      = "MIN",
  parameter RFTYPE    = "BRAM",
  parameter GPOCNT    = 1
) (
  input  logic              clk_i,
  input  logic              rst_in,
  input  logic              gpi_i,
  output logic [GPOCNT-1:0] gpo_o
);

localparam RAMSIZE = 16384;

// QSPI
logic       cs_ram_n;
logic       cs_rom_n;
logic       sck;
logic [3:0] core_sdo;
logic [3:0] core_sdoen;

wire [3:0] sdio;
assign sdio[0] = core_sdoen[0] ? core_sdo[0] : 1'bz;
assign sdio[1] = core_sdoen[1] ? core_sdo[1] : 1'bz;
assign sdio[2] = core_sdoen[2] ? core_sdo[2] : 1'bz;
assign sdio[3] = core_sdoen[3] ? core_sdo[3] : 1'bz;


spiflash i_spiflash (
  .csb ( cs_rom_n ),
  .clk ( sck      ),
  .io0 ( sdio[0]  ),
  .io1 ( sdio[1]  ),
  .io2 ( sdio[2]  ),
  .io3 ( sdio[3]  )
);

qspi_psram #( .DEPTH(RAMSIZE) ) i_qspi_psram (
  .sck_i    ( sck       ),
  .cs_in    ( cs_ram_n  ),
  .io0_io   ( sdio[0]   ),
  .io1_io   ( sdio[1]   ),
  .io2_io   ( sdio[2]   ),
  .io3_io   ( sdio[3]   )
);

exotiny #( 
  .CHUNKSIZE  ( CHUNKSIZE ),
  .CONF       ( CONF      ),
  .RFTYPE     ( RFTYPE    ),
  .GPOCNT     ( 'd1       )
) i_exotiny (
  .clk_i          ( clk_i   ),
  .rst_in         ( rst_in  ),
  .gpi_i          ( gpi_i   ),
  .gpo_o          ( gpo_o   ),

  .mem_cs_ram_on  ( cs_ram_n    ),
  .mem_cs_rom_on  ( cs_rom_n    ),
  .mem_sck_o      ( sck         ),
  .mem_sd_i       ( sdio        ),
  .mem_sd_o       ( core_sdo    ),
  .mem_sd_oen_o   ( core_sdoen  )
);

endmodule
