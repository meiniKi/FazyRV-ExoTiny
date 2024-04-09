// Copyright (c) 2024 Meinhard Kissich
// SPDX-License-Identifier: MIT
// -----------------------------------------------------------------------------
// File  :  wb_regs.sv
// Usage :  FazyRV SoC with QSPI to interface external ROM and RAM
// Ports
//  - clk_i           Clock input.
//  - rst_in          Reset, low active.
//  - wb_regs_cyc_i   Wishbone interface.
//  - wb_regs_stb_i
//  - wb_regs_we_i
//  - wb_regs_ack_o
//  - wb_regs_adr_i
//  - wb_regs_be_i
//  - wb_regs_dat_i
//  - wb_regs_dat_o
//  - gpi_i           General purpose inputs.
//  - gpo_o           General purpose outputs.
//  - spi_rdy_i       Spi is ready.
//  - spi_presc_o     Spi prescaler.
//  - spi_cpol_o      Spi CPOL.
//  - spi_auto_cs_o   Spi automatically assert CS.
//  - spi_size_o      Spi rx/tx size in bytes.
// -----------------------------------------------------------------------------

module wb_regs (
  input  logic        rst_in,
  input  logic        clk_i,
  input  logic        wb_regs_cyc_i,
  input  logic        wb_regs_stb_i,
  input  logic        wb_regs_we_i,
  output logic        wb_regs_ack_o,
  input  logic [2:0]  wb_regs_adr_i,
  input  logic [3:0]  wb_regs_be_i,
  input  logic [31:0] wb_regs_dat_i,
  output logic [31:0] wb_regs_dat_o,
  // gpio
  input  logic [6:0]  gpi_i,
  output logic [5:0]  gpo_o,
  // spi
  input  logic        spi_rdy_i,
  output logic [3:0]  spi_presc_o,
  output logic        spi_cpol_o,
  output logic        spi_auto_cs_o,
  output logic [1:0]  spi_size_o
);

// word addresses
//
localparam ADR_SPI_GPO  = 3'b000;
localparam ADR_SPI_GPI  = 3'b001;

localparam ADR_SPI_CTRL = 3'b010;
localparam ADR_SPI_STAT = 3'b100;

logic [5:0] gpo_r, gpo_n;
logic [3:0] spi_presc_r;
logic       spi_cpol_r;
logic       spi_auto_cs_r;
logic [1:0] spi_size_r;

assign gpo_o          = gpo_r;
assign spi_presc_o    = spi_presc_r;
assign spi_cpol_o     = spi_cpol_r;
assign spi_auto_cs_o  = spi_auto_cs_r;
assign spi_size_o     = spi_size_r;

assign wb_regs_ack_o = wb_regs_cyc_i & wb_regs_stb_i;

// ---- Data read ------------------------------
always_comb begin
  /* verilator lint_off CASEINCOMPLETE */
  case(wb_regs_adr_i)
    ADR_SPI_GPO:  wb_regs_dat_o = {26'b0, gpo_r};
    ADR_SPI_GPI:  wb_regs_dat_o = {25'b0, gpi_i};
    ADR_SPI_CTRL: wb_regs_dat_o = {8'b0, 6'b0, spi_size_r, 5'b0, spi_auto_cs_r, spi_cpol_r, 1'b0, 4'b0, spi_presc_r};
    ADR_SPI_STAT: wb_regs_dat_o = {31'b0, spi_rdy_i};
    default:      wb_regs_dat_o = {28'b0, gpo_r};
  endcase
  /* verilator lint_on CASEINCOMPLETE */
end

// ---- Data writes ------------------------------
always_ff @(posedge clk_i) begin
  if (~rst_in) begin
    spi_presc_r   <= 8'd11;
    spi_cpol_r    <= 1'b0;  // mode 0
    gpo_r         <= 'b0;
  end
  else begin
    if (wb_regs_cyc_i & wb_regs_stb_i & wb_regs_we_i) begin
      /* verilator lint_off CASEINCOMPLETE */
      case(wb_regs_adr_i)
        ADR_SPI_GPO: begin
          if (wb_regs_be_i[0])  gpo_r <= wb_regs_dat_i[5:0];
        end
        ADR_SPI_CTRL: begin
          if (wb_regs_be_i[0]) spi_presc_r                  <= wb_regs_dat_i[3:0];
          if (wb_regs_be_i[1]) {spi_auto_cs_r, spi_cpol_r}  <= wb_regs_dat_i[10:9];
          if (wb_regs_be_i[2]) spi_size_r                   <= wb_regs_dat_i[17:16];
        end
      endcase
      /* verilator lint_on CASEINCOMPLETE */
    end
  end
end

endmodule