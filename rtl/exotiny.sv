// Copyright (c) 2023 - 2024 Meinhard Kissich
// SPDX-License-Identifier: MIT
// -----------------------------------------------------------------------------
// File  :  exotiny.sv
// Usage :  FazyRV SoC with QSPI to interface external ROM and RAM
// Param
//  - CHUNKSIZE Width of the input vectors.
//  - CONF      Configuration of the processor (see FazyRV core).
//  - RFTYPE    Implementation of the register (see FazyRV core).
//  - GPOCNT    Number of outputs.
//
// Ports
//  - clk_i     Clock input.
//  - rst_in    Reset, low active.
//  - gpi_i     General purpose inputs.
//  - gpo_o     General purpose outputs.
// -----------------------------------------------------------------------------

module exotiny #( 
  parameter CHUNKSIZE = 8,
  parameter CONF      = "MIN",
  parameter RFTYPE    = "BRAM",
  parameter GPOCNT    = 1
) (
  input  logic              clk_i,
  input  logic              rst_in,

  input  logic              gpi_i,
  output logic [GPOCNT-1:0] gpo_o,

  output logic              mem_cs_ram_on,
  output logic              mem_cs_rom_on,
  output logic              mem_sck_o,
  input  logic [3:0]        mem_sd_i,
  output logic [3:0]        mem_sd_o,
  // Instatiate techn. dep. tri-state buffers in wrapper
  output logic [3:0]        mem_sd_oen_o
);

// GPIO:  0x1xxxxxxx
// ROM:   0x0{b0xxx}xxxxxx
// RAM:   0x0{b1xxx}xxxxxx +-> ram size

logic         tirq_i = 1'b0;
logic         trap_o;

logic         wb_cpu_imem_stb;
logic         wb_cpu_imem_cyc;
logic [31:0]  wb_cpu_imem_adr;
logic [31:0]  wb_cpu_imem_rdat;
logic         wb_cpu_imem_ack;

logic         wb_cpu_dmem_cyc;
logic         wb_cpu_dmem_stb;
logic         wb_cpu_dmem_we;
logic         wb_cpu_dmem_ack;
logic [3:0]   wb_cpu_dmem_be;
logic [31:0]  wb_cpu_dmem_rdat;
logic [31:0]  wb_cpu_dmem_adr;
logic [31:0]  wb_cpu_dmem_wdat;

logic         wb_mem_stb;
logic         wb_mem_we;
logic         wb_mem_ack;
logic [3:0]   wb_mem_be;
logic [31:0]  wb_mem_rdat;
logic [31:0]  wb_mem_adr;
logic [31:0]  wb_mem_wdat;

logic         wb_gpio_cyc;
logic         wb_gpio_stb;
logic         wb_gpio_we;
logic         wb_gpio_ack;
logic [3:0]   wb_gpio_be;
logic [31:0]  wb_gpio_rdat;
logic [31:0]  wb_gpio_wdat;

logic         sel_gpio;
logic         sel_rom_ram;


assign sel_gpio = wb_mem_adr[28];
assign sel_rom_ram = wb_mem_adr[27];

assign wb_cpu_imem_rdat = wb_mem_rdat;
assign wb_cpu_dmem_rdat = sel_gpio ? wb_gpio_rdat : wb_mem_rdat;

assign wb_cpu_imem_ack = wb_mem_ack & wb_cpu_imem_stb;
assign wb_cpu_dmem_ack = (wb_gpio_ack | wb_mem_ack) & wb_cpu_dmem_stb;

assign wb_mem_adr   = wb_cpu_imem_stb ? wb_cpu_imem_adr : wb_cpu_dmem_adr;
assign wb_mem_wdat  = wb_cpu_dmem_wdat;
assign wb_mem_be    = wb_cpu_dmem_be | {4{wb_cpu_imem_stb}};
assign wb_mem_we    = wb_cpu_dmem_we & wb_cpu_dmem_stb;
assign wb_mem_stb   = ~sel_gpio & (wb_cpu_imem_stb | wb_cpu_dmem_stb);

assign wb_gpio_cyc   = sel_gpio & wb_cpu_dmem_stb;
assign wb_gpio_stb   = wb_gpio_cyc;
assign wb_gpio_we    = wb_cpu_dmem_we;
assign wb_gpio_be    = wb_cpu_dmem_be;
assign wb_gpio_wdat  = wb_cpu_dmem_wdat;


wb_qspi_mem i_wb_qspi_mem (
  .clk_i          ( clk_i       ),
  .rst_in         ( rst_in      ),
  .sel_rom_ram_i  ( sel_rom_ram ),
  // wishbone
  .wb_mem_stb_i   ( wb_mem_stb  ),
  .wb_mem_we_i    ( wb_mem_we   ),
  .wb_mem_ack_o   ( wb_mem_ack  ),
  .wb_mem_be_i    ( wb_mem_be   ),
  .wb_mem_dat_i   ( wb_mem_wdat ),
  .wb_mem_adr_i   ( wb_mem_adr[23:2] ),
  .wb_mem_dat_o   ( wb_mem_rdat ),
  // qspi peripherals
  .cs_ram_on      ( mem_cs_ram_on ),
  .cs_rom_on      ( mem_cs_rom_on ),
  .sck_o          ( mem_sck_o     ),
  .sd_i           ( mem_sd_i      ),
  .sd_o           ( mem_sd_o      ),
  .sd_oen_o       ( mem_sd_oen_o  )
);


gpio #(.GPOCNT(GPOCNT)) i_gpio (
  .rst_in ( rst_in        ),
  .clk_i  ( clk_i         ),
  .cyc_i  ( wb_gpio_cyc   ),
  .stb_i  ( wb_gpio_stb   ),
  .we_i   ( wb_gpio_we    ),
  .ack_o  ( wb_gpio_ack   ),
  .be_i   ( wb_gpio_be    ),
  .dat_i  ( wb_gpio_wdat  ),
  .dat_o  ( wb_gpio_rdat  ),
  .gpi_i  ( gpi_i         ),
  .gpo_o  ( gpo_o         )
);


fazyrv_top #( 
  .CHUNKSIZE  ( CHUNKSIZE ),
  .CONF       ( CONF      ),
  .MTVAL      ( 'h4       ),
  .BOOTADR    ( 'h0       ),
  .RFTYPE     ( RFTYPE    ),
  .MEMDLY1    ( 0         )
) i_fazyrv_top (
  .clk_i          ( clk_i             ),
  .rst_in         ( rst_in            ),
  .tirq_i         ( tirq_i            ),
  .trap_o         ( trap_o            ),

  .wb_imem_stb_o  ( wb_cpu_imem_stb   ),
  .wb_imem_cyc_o  ( wb_cpu_imem_cyc   ),
  .wb_imem_adr_o  ( wb_cpu_imem_adr   ),
  .wb_imem_dat_i  ( wb_cpu_imem_rdat  ),
  .wb_imem_ack_i  ( wb_cpu_imem_ack   ),

  .wb_dmem_cyc_o  ( wb_cpu_dmem_cyc   ),
  .wb_dmem_stb_o  ( wb_cpu_dmem_stb   ),
  .wb_dmem_we_o   ( wb_cpu_dmem_we    ),
  .wb_dmem_ack_i  ( wb_cpu_dmem_ack   ),
  .wb_dmem_be_o   ( wb_cpu_dmem_be    ),
  .wb_dmem_dat_i  ( wb_cpu_dmem_rdat  ),
  .wb_dmem_adr_o  ( wb_cpu_dmem_adr   ),
  .wb_dmem_dat_o  ( wb_cpu_dmem_wdat  )
);


endmodule
