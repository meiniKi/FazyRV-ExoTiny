// Copyright (c) 2023 - 2024 Meinhard Kissich
// SPDX-License-Identifier: MIT
// -----------------------------------------------------------------------------
// File  :  exotiny.sv
// Usage :  FazyRV SoC with QSPI to interface external ROM and RAM
// Param
//  - CHUNKSIZE Width of the input vectors.
//  - CONF      Configuration of the processor (see FazyRV core).
//  - RFTYPE    Implementation of the register (see FazyRV core).
//  - GPICNT    Number of inputs.
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
  parameter GPICNT    = 6,
  parameter GPOCNT    = 6
) (
  input  logic              clk_i,
  input  logic              rst_in,

  input  logic [GPICNT-1:0] gpi_i,
  output logic [GPOCNT-1:0] gpo_o,

  output logic              mem_cs_ram_on,
  output logic              mem_cs_rom_on,
  output logic              mem_sck_o,
  input  logic [3:0]        mem_sd_i,
  output logic [3:0]        mem_sd_o,
  // Instatiate techn. dep. tri-state buffers in wrapper
  output logic [3:0]        mem_sd_oen_o,
  // SPI (cs by gpo)
  output logic              spi_sck_o,
  output logic              spi_sdo_o,
  input  logic              spi_sdi_i
);

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

logic         wb_regs_cyc;
logic         wb_regs_stb;
logic         wb_regs_we;
logic         wb_regs_ack;
logic [3:0]   wb_regs_be;
logic [31:0]  wb_regs_rdat;
logic [31:0]  wb_regs_wdat;

logic         wb_spi_cyc;
logic         wb_spi_stb;
logic         wb_spi_we;
logic         wb_spi_ack;
// no be
logic [31:0]  wb_spi_rdat;
logic [31:0]  wb_spi_wdat;

logic         sel_rom_ram;
logic         sel_mem;
logic         sel_regs;
logic         sel_spi;

logic [7:0]   spi_presc;
logic         spi_cpol;
logic         spi_cpha;
logic         spi_tx_clr;
logic         spi_rx_clr;
logic [3:0]   spi_tx_size;
logic [3:0]   spi_rx_size;

// SPI:  0x{0b0100}xxxxxxx
// REGS: 0x{0b0010}xxxxxxx
// ROM:  0x{0b0001}xxxxxxx
// RAM:  0x{0b0000}xxxxxxx +-> ram size

assign sel_mem  = ~|wb_mem_adr[30:29];
assign sel_spi  = wb_mem_adr[30];
assign sel_regs = wb_mem_adr[29];

assign sel_rom_ram  = wb_mem_adr[28];

assign wb_cpu_imem_rdat = wb_mem_rdat;
assign wb_cpu_dmem_rdat = sel_regs  ? wb_regs_rdat  :
                          sel_spi   ? wb_spi_rdat   : wb_mem_rdat;

assign wb_cpu_imem_ack = wb_mem_ack & wb_cpu_imem_stb;
assign wb_cpu_dmem_ack = (wb_regs_ack | wb_spi_ack | wb_mem_ack) & wb_cpu_dmem_stb;

assign wb_mem_adr   = wb_cpu_imem_stb ? wb_cpu_imem_adr : wb_cpu_dmem_adr;
assign wb_mem_wdat  = wb_cpu_dmem_wdat;
assign wb_mem_be    = wb_cpu_dmem_be | {4{wb_cpu_imem_stb}};
assign wb_mem_we    = wb_cpu_dmem_we & wb_cpu_dmem_stb;
assign wb_mem_stb   = sel_mem & (wb_cpu_imem_stb | wb_cpu_dmem_stb);

assign wb_regs_cyc  = sel_regs & wb_cpu_dmem_stb;
assign wb_regs_stb  = wb_gpio_cyc;
assign wb_regs_we   = wb_cpu_dmem_we;
assign wb_regs_be   = wb_cpu_dmem_be;
assign wb_regs_wdat = wb_cpu_dmem_wdat;

assign wb_spi_cyc   = sel_spi & wb_cpu_dmem_stb;
assign wb_spi_stb   = wb_spi_cyc; 
assign wb_spi_we    = wb_cpu_dmem_we;
assign wb_spi_wdat  = wb_cpu_dmem_wdat;

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


wb_regs i_wb_regs (
  .rst_in         ( rst_in ),
  .clk_i          ( clk_i ),
  .wb_regs_cyc_i  ( wb_regs_cyc       ),
  .wb_regs_stb_i  ( wb_regs_stb       ),
  .wb_regs_we_i   ( wb_regs_we        ),
  .wb_regs_ack_o  ( wb_regs_ack       ),
  .wb_regs_adr_i  ( wb_regs_adr[2:0]  ),
  .wb_regs_be_i   ( wb_regs_be        ),
  .wb_regs_dat_i  ( wb_regs_dat       ),
  .wb_regs_dat_o  ( wb_regs_dat       ),
  // gpio
  // already synchronized from tt frame
  .gpi_i          ( gpi_i             ),  
  .gpo_o          ( gpo_o             ),
  // spi
  .spi_presc_o    ( spi_presc         ),
  .spi_cpol_o     ( spi_cpol          ),
  .spi_cpha_o     ( spi_cpha          ),
  .spi_tx_clr_o   ( spi_tx_clr        ),
  .spi_rx_clr_o   ( spi_rx_clr        ),
  .spi_tx_size_i  ( spi_tx_size       ),
  .spi_rx_size_i  ( spi_rx_size       )
);


wb_spi_master #(
  .BUFFER           ( 'd4 ),
  .PRESCALER_WIDTH  ( 'd8 )
) i_wb_spi_master (
  .clk      ( clk_i         ),
  .rstz     ( rst_in        ),
  // phy
  .sclk     ( spi_sck_o         ),
  .mosi     ( spi_sdo_o         ),
  .miso     ( spi_sdi_i         ),
  .prescaler( spi_presc         ),
  .cpol     ( spi_cpol          ),
  .cpha     ( spi_cpha          ),
  .tx_clear ( spi_tx_clr        ),
  .rx_clear ( spi_rx_clr        ),
  .tx_size  ( spi_tx_size       ),
  .rx_size  ( spi_rx_size       ),
  .dat_i    ( wb_spi_wdat[7:0]  ),
  .dat_o    ( wb_spi_rdat       ),
  .we_i     ( wb_spi_we         ),
  .stb_i    ( wb_spi_stb        ),
  .ack_o    ( wb_spi_ack        )
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
