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
  parameter CHUNKSIZE = 4,
  parameter CONF      = "MIN",
  parameter RFTYPE    = "LOGIC",
  parameter GPICNT    = 6
) (
  input  logic                  clk_i,
  input  logic                  rst_in,

  input  logic [GPICNT-1:0]     gpi_i,
  output logic                  gpo_o,

  output logic                  mem_cs_ram_on,
  output logic                  mem_cs_rom_on,
  output logic                  mem_sck_o,
  input  logic [3:0]            mem_sd_i,
  output logic [3:0]            mem_sd_o,
  // Instatiate techn. dep. tri-state buffers in wrapper
  output logic [3:0]            mem_sd_oen_o,
  // SPI (cs by gpo)
  output logic                  spi_sck_o,
  output logic                  spi_sdo_o,
  input  logic                  spi_sdi_i,
  // ccx
  output logic [CHUNKSIZE-1:0]  ccx_rs_a_o,
  output logic [CHUNKSIZE-1:0]  ccx_rs_b_o,
  input  logic [CHUNKSIZE-1:0]  ccx_res_i,
  output logic [1:0]            ccx_sel_o,
  output logic                  ccx_req_o,
  input  logic                  ccx_resp_i
);

localparam GPOCNT = 3;

logic         tirq_i;
logic         trap_o;

logic         wb_cpu_imem_stb;
logic         wb_cpu_imem_cyc;
logic [31:0]  wb_cpu_imem_adr;
logic [31:0]  wb_cpu_imem_rdat;
logic         wb_cpu_imem_ack;

logic         wb_cpu_dmem_cyc;
(* keep *) logic         wb_cpu_dmem_stb;
logic         wb_cpu_dmem_we;
logic         wb_cpu_dmem_ack;
logic [3:0]   wb_cpu_dmem_be;
logic [31:0]  wb_cpu_dmem_rdat;
logic [31:0]  wb_cpu_dmem_adr;
(* keep *) logic [31:0]  wb_cpu_dmem_wdat;

logic         wb_mem_stb;
logic         wb_mem_we;
logic         wb_mem_ack;
logic [3:0]   wb_mem_be;
logic [31:0]  wb_mem_rdat;
logic [31:0]  wb_mem_adr;
(* keep *) logic [31:0]  wb_mem_wdat;

logic         wb_wdg_cyc;
logic         wb_wdg_stb;
logic         wb_wdg_we;
logic         wb_wdg_ack;
logic [3:0]   wb_wdg_be;
logic [31:0]  wb_wdg_rdat;
(* keep *) logic [31:0]  wb_wdg_adr;
logic [31:0]  wb_wdg_wdat;

(* keep *) logic         wb_regs_cyc;
logic         wb_regs_stb;
logic         wb_regs_we;
logic         wb_regs_ack;
logic [3:0]   wb_regs_be;
logic [31:0]  wb_regs_rdat;
(* keep *) logic [31:0]  wb_regs_adr;
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

logic         spi_rdy;
logic [1:0]   spi_size;
logic [3:0]   spi_presc;
logic         spi_cpol;
logic         spi_auto_cs;

logic [GPICNT-1:0]  gpo;
logic               spi_cs;

logic [CHUNKSIZE-1:0] ccx_rs_a;
logic [CHUNKSIZE-1:0] ccx_rs_b;
logic [CHUNKSIZE-1:0] ccx_res;
logic                 ccx_req;
logic                 ccx_resp;

logic wdg_to; // watchdog timeout
logic wdg_res_en_n;
logic core_res_en_n;

logic wdg_res_n;
logic core_res_n;

assign wdg_res_n  = rst_in & wdg_res_en_n;
// wdg_res_en_n is gated by ~gpo[1] (inverted as init by 0)
assign core_res_n = rst_in & (wdg_res_en_n | ~gpo[2]);

assign ccx_rs_a_o = ccx_rs_a;
assign ccx_rs_b_o = ccx_rs_b;
assign ccx_req_o  = ccx_req;
assign ccx_res    = ccx_res_i;
assign ccx_resp   = ccx_resp_i;

// we don't have enough io, thus
// we use gpo[1] to mux whether soft cs or by peripheral
assign gpo_o = gpo[1] ? gpo[0] : gpo[0] & spi_cs;

// WDG:  0x{0b1000}xxxxxxx
// SPI:  0x{0b0100}xxxxxxx
// REGS: 0x{0b0010}xxxxxxx
// RAM:  0x{0b0001}xxxxxxx +-> ram size
// ROM:  0x{0b0000}xxxxxxx

assign sel_wdg  = wb_mem_adr[31];
assign sel_mem  = ~|wb_mem_adr[31:29];
assign sel_spi  = wb_mem_adr[30];
assign sel_regs = wb_mem_adr[29];

assign sel_rom_ram  = wb_mem_adr[28];

assign wb_cpu_imem_rdat = wb_mem_rdat;
assign wb_cpu_dmem_rdat = sel_wdg   ? wb_wdg_rdat   :
                          sel_regs  ? wb_regs_rdat  :
                          sel_spi   ? wb_spi_rdat   : wb_mem_rdat;

assign wb_cpu_imem_ack = wb_mem_ack & wb_cpu_imem_stb;
assign wb_cpu_dmem_ack = (wb_wdg_ack | wb_regs_ack | wb_spi_ack | wb_mem_ack) & wb_cpu_dmem_stb;

assign wb_wdg_adr  = wb_cpu_dmem_adr;
assign wb_wdg_cyc  = sel_wdg & wb_cpu_dmem_stb;
assign wb_wdg_stb  = wb_wdg_cyc;
assign wb_wdg_we   = wb_cpu_dmem_we;
assign wb_wdg_be   = wb_cpu_dmem_be;
assign wb_wdg_wdat = wb_cpu_dmem_wdat;

assign wb_mem_adr   = wb_cpu_imem_stb ? wb_cpu_imem_adr : wb_cpu_dmem_adr;
assign wb_mem_wdat  = wb_cpu_dmem_wdat;
assign wb_mem_be    = wb_cpu_dmem_be | {4{wb_cpu_imem_stb}};
assign wb_mem_we    = wb_cpu_dmem_we & wb_cpu_dmem_stb;
assign wb_mem_stb   = sel_mem & (wb_cpu_imem_stb | wb_cpu_dmem_stb);

assign wb_regs_adr  = wb_cpu_dmem_adr;
assign wb_regs_cyc  = sel_regs & wb_cpu_dmem_stb;
assign wb_regs_stb  = wb_regs_cyc;
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
  .wb_mem_stb_i   ( wb_mem_stb        ),
  .wb_mem_we_i    ( wb_mem_we         ),
  .wb_mem_ack_o   ( wb_mem_ack        ),
  .wb_mem_be_i    ( wb_mem_be         ),
  .wb_mem_dat_i   ( wb_mem_wdat       ),
  .wb_mem_adr_i   ( wb_mem_adr[23:2]  ),
  .wb_mem_dat_o   ( wb_mem_rdat       ),
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
  .clk_i          ( clk_i  ),
  .wb_regs_cyc_i  ( wb_regs_cyc       ),
  .wb_regs_stb_i  ( wb_regs_stb       ),
  .wb_regs_we_i   ( wb_regs_we        ),
  .wb_regs_ack_o  ( wb_regs_ack       ),
  .wb_regs_adr_i  ( wb_regs_adr[4:2]  ),
  .wb_regs_be_i   ( wb_regs_be        ),
  .wb_regs_dat_i  ( wb_regs_wdat      ),
  .wb_regs_dat_o  ( wb_regs_rdat      ),
  // gpio
  // already synchronized from tt frame
  .gpi_i          ( gpi_i             ),  
  .gpo_o          ( gpo               ),
  // spi
  .spi_rdy_i      ( spi_rdy           ),
  .spi_presc_o    ( spi_presc         ),
  .spi_cpol_o     ( spi_cpol          ),
  .spi_auto_cs_o  ( spi_auto_cs       ),
  .spi_size_o     ( spi_size          )
);


wb_spi i_wb_spi (
  .rst_in         ( rst_in      ),
  .clk_i          ( clk_i       ),
  .wb_spi_cyc_i   ( wb_spi_cyc  ),
  .wb_spi_stb_i   ( wb_spi_stb  ),
  .wb_spi_we_i    ( wb_spi_we   ),
  .wb_spi_ack_o   ( wb_spi_ack  ),
  .wb_spi_dat_i   ( wb_spi_wdat ),
  .wb_spi_dat_o   ( wb_spi_rdat ),
  // spi config
  .presc_i        ( spi_presc   ),
  .size_i         ( spi_size    ),
  .cpol_i         ( spi_cpol    ),
  .auto_cs_i      ( spi_auto_cs ),
  .rdy_o          ( spi_rdy     ),
  // spi data
  .spi_cs_o       ( spi_cs      ),
  .spi_sck_o      ( spi_sck_o   ),
  .spi_sdo_o      ( spi_sdo_o   ),
  .spi_sdi_i      ( spi_sdi_i   )
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
  .rst_in         ( core_res_n        ),
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
  .wb_dmem_dat_o  ( wb_cpu_dmem_wdat  ),

  .ccx_rs_a_o     ( ccx_rs_a          ),
  .ccx_rs_b_o     ( ccx_rs_b          ),
  .ccx_res_i      ( ccx_res           ),
  .ccx_sel_o      ( ccx_sel_o         ),
  .ccx_req_o      ( ccx_req           ),
  .ccx_resp_i     ( ccx_resp          )
);

// wdg
wdg_top #(
  // Wishbone
  .REG_ADDRESS_WIDTH    (  2 ), // <- TODO
  .REG_PRE_DECODE       (  0 ),
  .REG_BASE_ADDRESS     (  0 ), // <- TODO
  .REG_ERROR_STATUS     (  0 ),
  .REG_DEFAULT_READ     (  0 ),
  .REG_INSERT_SLICER    (  0 ),
  .REG_USE_STALLS       (  0 ), // idk?
  .WB_DATA_WIDTH        ( 32 ),
  .WDG_PRECLKDIV_WIDTH  ( 20 ),
  .WDG_TICK_BIT         ( 19 ) // can be set from 0 up to WDG_PRECLKDIV_WIDTH-1
) i_wdg_top (
  .clk                  ( clk_i       ),
  .res_n                ( wdg_res_n   ),
  // Wishbone interface
  .i_wb_cyc             ( wb_wdg_cyc  ),
  .i_wb_stb             ( wb_wdg_stb  ),
  .o_wb_stall           ( /* NC */    ),
  .i_wb_adr             ( wb_wdg_adr  ),
  .i_wb_we              ( wb_wdg_we   ),
  .i_wb_dat             ( wb_wdg_wdat ),
  .i_wb_sel             ( wb_wdg_be   ),
  .o_wb_ack             ( wb_wdg_ack  ),
  .o_wb_err             ( /* NC */    ),
  .o_wb_rty             ( /* NC */    ),
  .o_wb_dat             ( wb_wdg_rdat ),
  // ---
  .o_irq1                (),              // NC stage 1 watchdog timeout
  .o_irq2                ( wdg_to     )   //    stage 2 watchdog timeout //TODO make safer
);

reset_ctrl #(
  .CORE_RST_CYCLES ( 60 ),
  .PADDING_CYCLES  (  5 ),
  .WDG_RST_CYCLES  (  1 )    
) i_rstctl (
  .clk          ( clk_i         ),
  .sys_res_n    ( rst_in        ),

  .wdg_to       ( wdg_to        ),
  .wdg_res_n    ( wdg_res_en_n  ),
  .core_res_n   ( core_res_en_n )
);

endmodule
