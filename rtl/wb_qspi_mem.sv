// Copyright (c) 2023 - 2024 Meinhard Kissich
// SPDX-License-Identifier: MIT
// -----------------------------------------------------------------------------
// File  :  wb_qspi_mem.sv
// Usage :  Minimal Wishbone<->QSPI adapter for ExoTiny ROM and RAM accesses. 
// Ports
//   - clk_i          Clock input.
//   - rst_in         Reset, low active.
//   - sel_rom_ram_i  Select ROM (0) or RAM (1) for the next strobe.
//                    The value must be consistent while stb_i is high.
//   - wb_mem_stb_i   Wishbone strobe.
//   - wb_mem_we_i    Wishbone write enable.
//   - wb_mem_ack_o   Wishbone acknowledge.
//   - wb_mem_be_i    Wishbone byte enable.
//                    For reads, all bytes are read. Writes only write the bytes
//                    where be is high.
//   - wb_mem_dat_i   Wishbone data to memory.
//   - wb_mem_adr_i   Wishbone address (word address).  
//   - wb_mem_dat_o   Wishbone data from memory.
//   - cs_ram_on      Low-active chip select to RAM.
//   - cs_rom_on      Low-active chip select to ROM.
//   - sck_o          QSPI clock.
//   - sd_i           QSPI serial input (from memory).
//   - sd_o           QSPI serial output (to memory).
//   - sd_oen_o       QSPI output enable (set data direction);
//                    keep tri-state buffers at the top level.
//
// Limitations
//   - only be combinations for sw, sh, sb according to the RISC-V ISA are
//     supported. Any other combinations (e.g., be==0101) may fail.
//   - Assumes ROM is set to QSPI mode, i.e., QE high (non-volatile)
//   - Writes to ROM (i.e., ~sel_rom_ram_i & wb_mem_we_i) causes a write
//     to the same address in RAM. Make sure that this case cannot occur.
// -----------------------------------------------------------------------------

module wb_qspi_mem (
  input  logic        clk_i,
  input  logic        rst_in,

  // select mem before, one module to reduce area
  input  logic        sel_rom_ram_i,

  // wishbone
  input  logic        wb_mem_stb_i,
  input  logic        wb_mem_we_i,
  output logic        wb_mem_ack_o,
  input  logic [3:0]  wb_mem_be_i,
  input  logic [31:0] wb_mem_dat_i,
  input  logic [21:0] wb_mem_adr_i, // word address
  output logic [31:0] wb_mem_dat_o,

  // qspi peripherals
  output logic        cs_ram_on,
  output logic        cs_rom_on,
  output logic        sck_o,
  input  logic [3:0]  sd_i,
  output logic [3:0]  sd_o,
  output logic [3:0]  sd_oen_o
);
  
localparam USE_CONTINUOUS_READ_MODE = 1;

localparam INSTR_RAM_QRD = 32'b0000_1011_????_????_????_????_????_????; // (QSPI 8'h0B == 8'b0000_1011)
localparam INSTR_RAM_QWD = 32'b0011_1000_????_????_????_????_????_????; // (QSPI 8'h38 == 8'b0011_1000)

localparam INSTR_ROM_QRD = 32'b???1_???1_???1_???0_???1_???0_???1_???1; // (SPI 8'hEB == 8'b1110_1011)

localparam RAM_INSTR_TO_QSPI = 32'b???0_???0_???1_???1_???0_???1_???0_???1; // (SPI 8'h35 == 8'b0011_0101);

// If order is changed make sure to update the optimization in the fsm
localparam RAM_RD_HIGHZ_CYCLES_VAL = 'd3;
localparam ROM_RD_HIGHZ_CYCLES_VAL = 'd3;

// Write to flash on rising clock edge
// read data on falling edge

// Instructions -> Flash: MSB first, on rising edge
// low CS -> instr -> high CS

// Split DATA into DATA_R and DATA_R, to have 8 states and avoid if in DATA
//
enum int unsigned { INIT, IDLE, INSTR, ADDR, DUMMY, DATA_R, DATA_W, ACK} state_r, state_n;

logic [2:0]  cnt_r, cnt_n;
logic [31:0] dat_r, dat_n;
logic [31:0] adr_init;

assign wb_mem_dat_o = { dat_r[ 7: 4], dat_r[ 3: 0],
                        dat_r[15:12], dat_r[11: 8],
                        dat_r[23:20], dat_r[19:16],
                        dat_r[31:28], dat_r[27:24]};

logic       crm_r, crm_n;
logic [3:0] data_i_padded [0:7];
logic [2:0] data_idx;

assign data_i_padded[0] = wb_mem_dat_i[ 7: 4];
assign data_i_padded[1] = wb_mem_dat_i[ 3: 0];
assign data_i_padded[2] = wb_mem_dat_i[15:12];
assign data_i_padded[3] = wb_mem_dat_i[11: 8];
assign data_i_padded[4] = wb_mem_dat_i[23:20];
assign data_i_padded[5] = wb_mem_dat_i[19:16];
assign data_i_padded[6] = wb_mem_dat_i[31:28];
assign data_i_padded[7] = wb_mem_dat_i[27:24];

assign sck_o = ~clk_i; //& (state_r != IDLE) & rst_in; save area

assign data_idx = {offset, 1'b0} + cnt_r;

assign sd_o = (state_r == DATA_W) ? data_i_padded[data_idx] : dat_r[31 -: 4];

logic [1:0] offset;
//assign offset = (wb_mem_be_i[0] | ~wb_mem_we_i) ? 'd0 :
//                wb_mem_be_i[1]                  ? 'd1 :
//                wb_mem_be_i[2]                  ? 'd2 : 'd3 ;
// Optimized:
assign offset[0] = ~(wb_mem_be_i[0] | ~wb_mem_we_i | wb_mem_be_i[2]);
assign offset[1] = ~(wb_mem_be_i[0] | ~wb_mem_we_i | wb_mem_be_i[1]);

logic [2:0] cnt_to_write_init;
assign cnt_to_write_init =  &wb_mem_be_i ? 'd7 :
                            ^wb_mem_be_i ? 'd1 : 'd3;

generate
  if (USE_CONTINUOUS_READ_MODE) begin
    assign adr_init = {wb_mem_adr_i, offset, 8'hA5};
  end else begin
    assign adr_init = {wb_mem_adr_i, offset, 8'hFF};
  end
endgenerate


always_ff @(posedge clk_i) begin
  if (~rst_in) begin
    state_r   <= INIT;
    crm_r     <= 'b0;
    cnt_r     <= 'd0;
    dat_r     <= RAM_INSTR_TO_QSPI;
  end else begin
    state_r   <= state_n;
    crm_r     <= crm_n;
    cnt_r     <= cnt_n;
    dat_r     <= dat_n;
  end
end

always_comb begin
  cs_rom_on     = sel_rom_ram_i;
  cs_ram_on     = ~sel_rom_ram_i;
  sd_oen_o      = 4'b0000;
  wb_mem_ack_o  = 1'b0;

  state_n       = state_r;
  cnt_n         = cnt_r + 'b1;
  dat_n         = (dat_r << 'd4);
  crm_n         = crm_r;

  case (state_r)
    INIT: begin
      sd_oen_o    = {3'b000, rst_in};
      cs_rom_on   = 1'b1;
      cs_ram_on   = 1'b0 | ~rst_in;
      if (cnt_r == 'd7) begin
        state_n = IDLE;
      end
    end
    // ---
    IDLE: begin
      cs_rom_on = 1'b1;
      cs_ram_on = 1'b1;
      if (wb_mem_stb_i == 1'b1) begin
        state_n = INSTR;
        cnt_n   = 'd0;

        if (wb_mem_we_i) begin
          // Case: write to RAM
          dat_n = INSTR_RAM_QWD;
        end else begin
          // Case B: read from RAM or ROM in non-continuous mode
          dat_n = sel_rom_ram_i ? INSTR_RAM_QRD : INSTR_ROM_QRD;

          // Case A: read from ROM when set in continuous mode
          if (~sel_rom_ram_i & USE_CONTINUOUS_READ_MODE & crm_r) begin
            state_n = ADDR;
            dat_n   = adr_init;
          end
        end
      end
    end
    //---
    INSTR: begin
      sd_oen_o  = {{3{sel_rom_ram_i}}, 1'b1};
      if ((sel_rom_ram_i & (cnt_r == 'd1))| (cnt_r == 'd7)) begin
        state_n = ADDR;
        dat_n   = adr_init;
        crm_n   = crm_r | (~sel_rom_ram_i & USE_CONTINUOUS_READ_MODE);
        cnt_n   = 'd0;
      end
    end
    //---
    ADDR: begin
      sd_oen_o  = 4'b1111;
      if ( (sel_rom_ram_i & (cnt_r == 'd5)) | (cnt_r == 'd7) ) begin
        cnt_n = 'd0;
        if (wb_mem_we_i) begin
          // write: must be ram here
          state_n = DATA_W;
        end else begin
          // read
          state_n = DUMMY;
        end
      end
    end
    //---
    DUMMY: begin
      if ( (~sel_rom_ram_i & (cnt_r == ROM_RD_HIGHZ_CYCLES_VAL)) | (cnt_r == RAM_RD_HIGHZ_CYCLES_VAL) )  begin
        // must be a read here
        state_n = DATA_R;
        cnt_n   = 'd0;
      end
    end
    //---
    DATA_R: begin
      dat_n = {dat_r[27:0], sd_i};  // shift in this way to just have one shift direction
      if (cnt_r == 'd7) begin
        state_n = ACK;
      end
    end
    //---
    DATA_W: begin
      sd_oen_o = 4'b1111;
      if (cnt_r == cnt_to_write_init) begin
        state_n = ACK;
      end
    end
    //---
    ACK: begin
      cs_rom_on     = 1'b1;
      cs_ram_on     = 1'b1;
      wb_mem_ack_o  = 1'b1;
      state_n       = IDLE;
    end
  endcase
end


`ifdef DEBUG
(* keep *) logic [127:0] dbg_ascii_state;
always_comb begin
  case(state_r)
    INIT:   dbg_ascii_state = "INIT";
    IDLE:   dbg_ascii_state = "IDLE";
    INSTR:  dbg_ascii_state = "INSTR";
    ADDR:   dbg_ascii_state = "ADDR";
    DUMMY:  dbg_ascii_state = "DUMMY";
    DATA_R: dbg_ascii_state = "DATA_R";
    DATA_W: dbg_ascii_state = "DATA_W";
    ACK:    dbg_ascii_state = "ACK";
    default dbg_ascii_state = "UNKNOWN";
  endcase
end

(* keep *) logic dbg_ram_rd_word;
(* keep *) logic dbg_ram_wr_word;
(* keep *) logic dbg_ram_rd_byte;
(* keep *) logic dbg_ram_wr_byte;

(* keep *) logic [31:0] dbg_dat_n;

assign dbg_dat_n = (dat_r << 'd4);

assign dbg_ram_rd_word = ~cs_ram_on & ~wb_mem_we_i & (wb_mem_be_i == 4'b1111);
assign dbg_ram_wr_word = ~cs_ram_on & wb_mem_we_i & (wb_mem_be_i == 4'b1111);
assign dbg_ram_rd_byte = ~cs_ram_on & ~wb_mem_we_i & (wb_mem_be_i != 4'b1111);
assign dbg_ram_wr_byte = ~cs_ram_on & wb_mem_we_i & (wb_mem_be_i != 4'b1111);

`endif

endmodule
