// Copyright (c) 2023 - 2024 Meinhard Kissich
// -----------------------------------------------------------------------------
// File  :  exotiny_sim.sv
// Usage :  Simulation wrapper for FazyRV ExoTiny.
// -----------------------------------------------------------------------------

`timescale 1 ns / 1 ps

module exotiny_sim #( 
  parameter CHUNKSIZE = 8,
  parameter CONF      = "MIN",
  parameter RFTYPE    = "BRAM"
) (
  input  logic              clk_i,
  input  logic              rst_in
);

localparam RAMSIZE = 1024*1024*16;

// QSPI
logic       cs_ram_n;
logic       cs_rom_n;
logic       sck;
logic [3:0] core_sdo;
logic [3:0] core_sdoen;

// SPI
logic       spi_sck;
logic       spi_sdo;
logic       spi_sdi;

// GPIO
logic [5:0] gpi;
logic gpo;


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


// CCX
localparam RES_DLY = 10;

logic [CHUNKSIZE-1:0] ccx_rs_a;
logic [CHUNKSIZE-1:0] ccx_rs_b;
logic [CHUNKSIZE-1:0] ccx_res;

logic                 ccx_req;
logic                 ccx_resp;

logic                 ccx_sel;


logic [CHUNKSIZE-1:0] shift_res [0:RES_DLY-1];
logic                 shift_req [0:(RES_DLY-1 + 32/CHUNKSIZE-1)];

assign ccx_res  = shift_res[RES_DLY-1];
assign ccx_resp = shift_req[RES_DLY-1 + 32/CHUNKSIZE-1];

always_ff @(posedge clk_i) begin
  shift_res[0] <= ccx_rs_a & ccx_rs_b;
  shift_req[0] <= ccx_req;
end

genvar i;
generate for (i = 1; i < RES_DLY; i++) begin
  always_ff @(posedge clk_i) shift_res[i] <= shift_res[i-1];
end endgenerate

generate for (i = 1; i < RES_DLY + 32/CHUNKSIZE-1; i++) begin
  always_ff @(posedge clk_i) shift_req[i] <= shift_req[i-1];
end endgenerate

exotiny #( 
  .CHUNKSIZE  ( CHUNKSIZE ),
  .CONF       ( CONF      ),
  .RFTYPE     ( RFTYPE    )
) i_exotiny (
  .clk_i          ( clk_i   ),
  .rst_in         ( rst_in  ),
  .gpi_i          ( gpi     ),
  .gpo_o          ( gpo     ),

  .mem_cs_ram_on  ( cs_ram_n    ),
  .mem_cs_rom_on  ( cs_rom_n    ),
  .mem_sck_o      ( sck         ),
  .mem_sd_i       ( sdio        ),
  .mem_sd_o       ( core_sdo    ),
  .mem_sd_oen_o   ( core_sdoen  ),

  .spi_sck_o      ( spi_sck     ),
  .spi_sdo_o      ( spi_sdo     ),
  .spi_sdi_i      ( spi_sdi     ),

  .ccx_rs_a_o     ( ccx_rs_a    ),
  .ccx_rs_b_o     ( ccx_rs_b    ),
  .ccx_res_i      ( ccx_res     ),
  .ccx_sel_o      ( ccx_sel     ),
  .ccx_req_o      ( ccx_req     ),
  .ccx_resp_i     ( ccx_resp    )
);

// conditional loopback for testing
assign spi_sdi =  gpo ? 1'b0 : spi_sdo;

assign gpi =  gpo ? 6'b10_1010 : 6'b01_0101;

endmodule

