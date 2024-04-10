// Copyright (c) 2024 Meinhard Kissich
// SPDX-License-Identifier: MIT
// -----------------------------------------------------------------------------
// File  :  qspi_psram.sv
// Usage :  Very basic QSPI PSRAM Model. The model requires a 
//			_SPI Quad Mode Enable Operation_ ('h35) after power up and only
//			supports QSPI read ('h0B) and write ('h38) operations
// Param
//  - DEPTH     Memory size in bytes
//
// Limations
//  - requires that sck_i continues for at least one clock cylce after cs_in high
//
// Ports
//  - sck_i     Serial clock
//  - cs_in     Low active chip select
//  - io0_io    serial in,  qspi io0
//  - io1_io    serial out, qspi io1
//  - io2_io    qspi io2
//  - io3_io    qspi io3
// -----------------------------------------------------------------------------

`timescale 1 ns / 1 ps

module qspi_psram #( parameter DEPTH=128 )(
  input logic sck_i,
  input logic cs_in,
  inout logic io0_io,
  inout logic io1_io,
  inout logic io2_io,
  inout logic io3_io
);

localparam CMD_QSPI_UNLOCK = 'h35;
localparam CMD_QSPI_READ   = 'h0B;
localparam CMD_QSPI_WRITE  = 'h38;

localparam DUMMY_CYCLES = 4;

logic io0_o;
logic io1_o;
logic io2_o;
logic io3_o;

logic io0_o_pre;
logic io1_o_pre;
logic io2_o_pre;
logic io3_o_pre;

always @(negedge sck_i) begin
  if (state_r == READ) begin
    #5 
    io0_o <= io0_o_pre;
    io1_o <= io1_o_pre;
    io2_o <= io2_o_pre;
    io3_o <= io3_o_pre;
  end else begin
    io0_o <= 1'bz;
    io1_o <= 1'bz;
    io2_o <= 1'bz;
    io3_o <= 1'bz;
  end
end

logic io0_oen;
logic io1_oen;
logic io2_oen;
logic io3_oen;

logic [7:0] mem_r [0:DEPTH-1];

logic [1023:0] rampreload_file;
initial begin
  if ($value$plusargs("rampreload=%s", rampreload_file)) begin
    $readmemh(rampreload_file, mem_r);
  end
end

logic [7:0] mem_byte_r, mem_byte_n;

logic qspi_unlocked_n, qspi_unlocked_r = 0;

enum int unsigned {CMD=0, ADR, DUMMY, READ, WRITE, WAIT} state_r, state_n;

logic [7:0]   cmd_r, cmd_n;
logic [23:0]  adr_r, adr_n;
logic [7:0]   dat_r, dat_n;

int cnt_r, cnt_n;

assign io0_oen = ~cs_in & (state_r == READ);
assign io1_oen = ~cs_in & (state_r == READ);
assign io2_oen = ~cs_in & (state_r == READ);
assign io3_oen = ~cs_in & (state_r == READ);

assign io0_io = io0_oen ? io0_o : 1'bz;
assign io1_io = io1_oen ? io1_o : 1'bz;
assign io2_io = io2_oen ? io2_o : 1'bz;
assign io3_io = io3_oen ? io3_o : 1'bz;

logic [7:0] current_read;
assign current_read = mem_r[adr_r]; 

always @(posedge sck_i) begin
  cnt_r           <= cnt_n;
  cmd_r           <= cmd_n;
  adr_r           <= adr_n;
  dat_r           <= dat_n;
  state_r         <= state_n;
  qspi_unlocked_r <= qspi_unlocked_n;
  mem_byte_r      <= mem_byte_n;

  if ((state_r == WRITE) && (cnt_r == 'd1) && ~cs_in) begin
    mem_r[adr_r]  <= mem_byte_n;
  end
end

always_comb begin
  state_n         = state_r;
  cnt_n           = cnt_r;
  adr_n           = adr_r;
  dat_n           = dat_r;
  qspi_unlocked_n = qspi_unlocked_r;
  mem_byte_n      = mem_byte_r;

  if (~cs_in) begin
    case (state_r)
      CMD: begin
        cnt_n = cnt_r + 'd1;

        if (qspi_unlocked_r)  cmd_n = {cmd_r[3:0], io3_io, io2_io, io1_io, io0_io};
        else                  cmd_n = {cmd_r[6:0], io0_io};

        if (qspi_unlocked_r & (cnt_r == 'd1)) begin
          cnt_n   = 'd0;
          state_n = WAIT;
          if (({cmd_r[3:0], io3_io, io2_io, io1_io, io0_io} == CMD_QSPI_READ) |
              ({cmd_r[3:0], io3_io, io2_io, io1_io, io0_io} == CMD_QSPI_WRITE) ) begin
            state_n         = ADR;
          end
        end
        if (cnt_r == 'd7) begin
          cnt_n   = 'd0;
          state_n = WAIT;
          if ({cmd_r[6:0], io0_io} == CMD_QSPI_UNLOCK) begin
            qspi_unlocked_n = 1;
            state_n         = WAIT;
          end
        end
      end
      // ---
      ADR: begin
        cnt_n = cnt_r + 'd1;
        adr_n = {adr_r[19:0], io3_io, io2_io, io1_io, io0_io};
        if (cnt_r == 'd5) begin
          cnt_n       = 'd0;
          if (cmd_r == CMD_QSPI_WRITE)  state_n = WRITE;
          else                          state_n = DUMMY;
        end
      end
      // ---
      DUMMY: begin
        cnt_n = cnt_r + 'd1;
        if (cnt_r == (DUMMY_CYCLES - 'd1)) begin
          cnt_n   = 'd0;
          state_n = READ;
        end
      end
      // ---
      WRITE: begin
        cnt_n = cnt_r + 'd1;
        dat_n = {dat_r[3:0], io3_io, io2_io, io1_io, io0_io};
        if (cnt_r == 'd1) begin
          mem_byte_n = {dat_r[3:0], io3_io, io2_io, io1_io, io0_io};
          cnt_n = 'd0;
          adr_n = adr_r + 'd1;
        end
      end
      // ---
      READ: begin
        //mem_byte_n = mem_r[adr_r];
        cnt_n = cnt_r + 'd1;
        if (cnt_r == 'd0) {io3_o_pre, io2_o_pre, io1_o_pre, io0_o_pre} = current_read[7:4];
        else              {io3_o_pre, io2_o_pre, io1_o_pre, io0_o_pre} = current_read[3:0];
        if (cnt_r == 'd1) begin
          cnt_n = 'd0;
          adr_n = adr_r + 'd1;
        end
      end
      // ---
      WAIT: begin
      end
      // ---
      default: begin
      end
    endcase
  end else begin
    state_n = CMD;
    cnt_n   = 'd0;
  end
end

`ifdef DEBUG
(* keep *) logic [127:0] dbg_ascii_state;
always_comb begin
  case(state_r)
  CMD:      dbg_ascii_state = "CMD";
  ADR:      dbg_ascii_state = "ADR";
  DUMMY:    dbg_ascii_state = "DUMMY";
  READ:     dbg_ascii_state = "READ";
  WRITE:    dbg_ascii_state = "WRITE";
  WAIT:     dbg_ascii_state = "WAIT";
  default:  dbg_ascii_state = "UNKNOWN";
  endcase
end
`endif


// Adopted from SERV
`ifdef SIGNATURE
(* keep *) logic sig_en;
(* keep *) logic halt_en;

// signature only uses sb, thus we can save the first byte and ignore the others

// RAM:   0x0{b10xx}xxxxxx
assign sig_en = (adr_r[23:20] == 4'hE) & (state_r == WRITE) & (cnt_r == 'd1) & (adr_r[1:0] == 'd0);

// big address within RAM: 0xF00000
assign halt_en = (adr_r[23:20] == 4'hF) & (state_r == WRITE) & (cnt_r == 'd1) & (adr_r[1:0] == 'd0);

logic [1023:0] signature_file;
integer f = 0;

initial
  /* verilator lint_off WIDTH */
  if ($value$plusargs("signature_file=%s", signature_file)) begin
    $display("Writing signature to %0s", signature_file);
    f = $fopen(signature_file, "w");
  end
  /* verilator lint_on WIDTH */

  always @(posedge sck_i) begin
    if (sig_en & (f != 0)) begin
      $fwrite(f, "%c", mem_byte_n[7:0]);
    end else if(halt_en) begin
      $display("Test complete");
      $finish;
    end
  end
`endif

	
endmodule
