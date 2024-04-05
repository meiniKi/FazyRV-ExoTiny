// Copyright (c) 2024 Meinhard Kissich
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
  input  logic [5:0]  gpi_i,
  output logic [5:0]  gpo_o,
  // spi
  output logic [7:0]  spi_presc_o,
  output logic        spi_cpol_o,
  output logic        spi_cpha_o,
  output logic        spi_tx_clr_o,
  output logic        spi_rx_clr_o,
  input  logic [3:0]  spi_tx_size_i,
  input  logic [3:0]  spi_rx_size_i
);

// word addresses
//
localparam ADR_SPI_GPO  = 3'b000;
localparam ADR_SPI_GPI  = 3'b001;

localparam ADR_SPI_CTRL = 3'b010;
localparam ADR_SPI_STAT = 3'b100;

logic [3:0] gpo_r, gpo_n;
logic [7:0] spi_presc_r;
logic       spi_cpol_r;
logic       spi_cpha_r;
logic       spi_tx_clr_r;
logic       spi_rx_clr_r;

assign gpo_o        = gpo_r;
assign spi_presc_o  = spi_presc_r;
assign spi_cpol_o   = spi_cpol_r;
assign spi_cpha_o   = spi_cpha_r;
assign spi_tx_clr_o = spi_tx_clr_r;
assign spi_rx_clr_o = spi_rx_clr_r;

assign wb_regs_ack_o = wb_regs_cyc_i & wb_regs_stb_i;

// ---- Data read ------------------------------
always_comb begin
  /* verilator lint_off CASEINCOMPLETE */
  case(wb_regs_adr_i)
    ADR_SPI_GPO:  wb_regs_dat_o = {26'b0, gpo_r};
    ADR_SPI_GPI:  wb_regs_dat_o = {26'b0, gpi_i};
    ADR_SPI_CTRL: wb_regs_dat_o = {8'b0, 6'b0, spi_tx_clr_r, spim_rx_clear, 6'b0, spi_cpol_r, spi_cpha_r, spi_presc_r};
    ADR_SPI_STAT: wb_regs_dat_o = {16'b0, 2'b0, spi_rx_size_i, 2'b0, spi_tx_size_i};
    default:      wb_regs_dat_o = {28'b0, gpo_r};
  endcase
  /* verilator lint_on CASEINCOMPLETE */
end

// ---- Data writes ------------------------------
always_ff @(posedge clk_i) begin
  if (~rst_in) begin
    spi_presc_r   <= 8'd11;
    spi_cpol_r    <= 1'b0;  // mode 0
    spi_cpha_r    <= 1'b0;
    spi_tx_clr_r  <= 1'b0;
    spi_rx_clr_r  <= 1'b0;
  end
  else begin
    if (wb_regs_cyc_i & wb_regs_stb_i & wb_regs_we_i) begin
      /* verilator lint_off CASEINCOMPLETE */
      case(wb_regs_adr_i)
        ADR_SPI_GPO: begin
          if (wb_regs_be_i[0])  gpo_r <= wb_regs_dat_i[5:0];
        end
        ADR_SPI_CTRL: begin
          if (wb_regs_be_i[0]) spi_presc_r                    <= wb_regs_dat_i[7:0];
          if (wb_regs_be_i[1]) {spim_cpol, spim_cpha}         <= wb_regs_dat_i[9:8];
          if (wb_regs_be_i[2]) {spim_tx_clear, spim_rx_clear} <= wb_regs_dat_i[17:16];
        end
      endcase
      /* verilator lint_on CASEINCOMPLETE */
    end else begin
      spim_tx_clear <= 1'b0;
      spim_rx_clear <= 1'b0;
    end
  end
end

endmodule