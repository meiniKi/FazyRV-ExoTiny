// Copyright (c) 2024 Meinhard Kissich
// SPDX-License-Identifier: MIT
// -----------------------------------------------------------------------------
// File  :  wb_spi.sv
// Usage :  A minimal SPI module for FazyRV-ExoTiny
//          Partially inspired by SonalPinto/kronos SPI.
// Param
//  - CHUNKSIZE Width of the input vectors.
//  - CONF      Configuration of the processor (see FazyRV core).
//  - RFTYPE    Implementation of the register (see FazyRV core).
//  - GPICNT    Number of inputs.
//  - GPOCNT    Number of outputs.
//
// Ports
//  - clk_i         Clock input.
//  - rst_in        Reset, low active.
//  - wb_spi_cyc_i  Wishbone interface.
//  - wb_spi_stb_i
//  - wb_spi_we_i
//  - wb_spi_ack_o
//  - wb_spi_dat_i
//  - wb_spi_dat_o
//  - presc_i       Spi prescaler.
//  - size_i        Spi rx/tx size in bytes.
//  - cpol_i        Spi CPOL.
//  - auto_cs_i     Spi automatically assert CS.
//  - rdy_o         Spi is ready.
//  - spi_cs_o      Spi phy CS.
//  - spi_sck_o     Spi phy SCK.
//  - spi_sdo_o     Spi phy SDO.
//  - spi_sdi_i     Spi phy SDI.
// -----------------------------------------------------------------------------

module wb_spi (
  input  logic        rst_in,
  input  logic        clk_i,
  input  logic        wb_spi_cyc_i,
  input  logic        wb_spi_stb_i,
  input  logic        wb_spi_we_i,
  output logic        wb_spi_ack_o,
  input  logic [31:0] wb_spi_dat_i,
  output logic [31:0] wb_spi_dat_o,
  // spi config
  input  logic [3:0]  presc_i,
  input  logic [1:0]  size_i,
  input  logic        cpol_i,
  input  logic        auto_cs_i,
  output logic        rdy_o,
  // spi data
  output logic        spi_cs_o,
  output logic        spi_sck_o,
  output logic        spi_sdo_o,
  input  logic        spi_sdi_i
);

logic [31:0] dat_rx_r, dat_rx_n;
logic [31:0] dat_tx_r, dat_tx_n;

logic [6:0] cnt_hbit_r, cnt_hbit_n;
logic [6:0] cnt_presc_r, cnt_presc_n;

logic sck_r;
logic tick;
logic done;

logic [2:0] size;
assign size = {1'b0, size_i} + 1'b1; 

enum int unsigned { IDLE, ACT } state_r, state_n;

assign wb_spi_dat_o = dat_rx_r;
assign wb_spi_ack_o = wb_spi_stb_i & wb_spi_cyc_i;
assign rdy_o        = (state_r == IDLE);
assign spi_cs_o     = ~(auto_cs_i & ((state_r != IDLE) | (wb_spi_cyc_i & wb_spi_stb_i & wb_spi_we_i)));
assign spi_sck_o    = sck_r;
assign spi_sdo_o    = dat_tx_r[31];

assign tick         = (~|cnt_presc_r);
assign done         = (state_r == ACT) & (state_n != ACT);

always_comb begin
  dat_rx_n    = dat_rx_r;
  dat_tx_n    = dat_tx_r;
  cnt_hbit_n  = cnt_hbit_r;
  state_n     = state_r;
  cnt_presc_n = cnt_presc_r - 'b1;

  case(state_r)

    IDLE: begin
      if (wb_spi_cyc_i & wb_spi_stb_i & wb_spi_we_i) begin
        dat_tx_n    = wb_spi_dat_i;
        state_n = ACT;
        cnt_presc_n = (presc_i << 3);
        cnt_hbit_n  = (size << 4);
      end
    end
    // ---
    ACT: begin
      if (tick) begin
        cnt_hbit_n  = cnt_hbit_r - 'b1;
        if (~|cnt_hbit_r) begin
          state_n = IDLE;
        end 
        cnt_presc_n = (presc_i << 3);

        if (cnt_hbit_r[0]) begin
          dat_tx_n    = dat_tx_r << 1;
          dat_rx_n    = {dat_rx_r[30:0], spi_sdi_i};
        end
      end
    end
  endcase
end

always_ff @(posedge clk_i) begin
  dat_rx_r    <= dat_rx_n;
  dat_tx_r    <= dat_tx_n;
  cnt_hbit_r  <= cnt_hbit_n;
  cnt_presc_r <= cnt_presc_n;

  if (~rst_in) begin
    state_r     <= IDLE;
    sck_r       <= cpol_i;
  end else begin
    state_r     <= state_n;
    // SCK
    if (state_r == IDLE)  sck_r <= cpol_i;
    else if (tick)        sck_r <= done ? cpol_i : ~sck_r;
    else                  sck_r <= sck_r;
  end
end

endmodule