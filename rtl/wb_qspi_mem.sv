
// ROM:
//  * Assume: Flash SPI is set to QSPI, i.e., QE high, non-volatile

// Write to RAM: Problem is be != 4'hF
// * sending addr for each byte too slow
// * thus, we read the word and
// * write back the modifed version
// -> some overhead but better trade-off

// Limitations
// * Writes to ROM write to the same address in RAM, take care
//   if be[3:0] != 'b1111 it may also read data from flash and writes it to the RAM
//   assume be[3:0] != 'b0000

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

localparam INSTR_QRD = 32'b???1_???1_???1_???0_???1_???0_???1_???1; // (8'hEB == 8'b1110_1011)
localparam INSTR_QWD = 32'b???0_???0_???1_???1_???1_???0_???0_???0; // (8'h38 == 8'b0011_1000)

//localparam RAM_INSTR_TO_QSPI = 32'b???0_???0_???1_???1_???0_???1_???0_???1; // (8'h35 == 8'b0011_0101;
localparam RAM_INSTR_TO_QSPI = 32'b0000_0000_0001_0001_0000_0001_0000_0001; // (8'h35 == 8'b0011_0101;

localparam RAM_RD_HIGHZ_CYCLES = 'd7;
localparam ROM_RD_HIGHZ_CYCLES = 'd4;

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

logic         crm_r, crm_n;
logic [31:0]  data_i_padded;

assign data_i_padded = {  wb_mem_dat_i[ 7: 4], wb_mem_dat_i[ 3: 0],
                          wb_mem_dat_i[15:12], wb_mem_dat_i[11: 8],
                          wb_mem_dat_i[23:20], wb_mem_dat_i[19:16],
                          wb_mem_dat_i[31:28], wb_mem_dat_i[27:24]};


assign sck_o = ~clk_i; //& (state_r != IDLE) & rst_in; save area

logic [4:0] data_idx;
assign data_idx = {cnt_r - {offset, 1'b0}, 2'b00};

assign sd_o = (state_r == DATA_W) ? data_i_padded[data_idx +: 4] : dat_r[31 -: 4];

logic [1:0] offset;
assign offset = (wb_mem_be_i[0] | ~wb_mem_we_i) ? 'd0 :
                wb_mem_be_i[1]                  ? 'd1 :
                wb_mem_be_i[2]                  ? 'd2 : 'd3 ;

logic [2:0] cnt_to_write_init;
assign cnt_to_write_init = &wb_mem_be_i                     ? 'd7 :
                          |wb_mem_be_i & (~(&wb_mem_be_i))  ? 'd3 : 'd1;


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
    cnt_r     <= 'd7;
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
  cnt_n         = cnt_r - 'b1;
  dat_n         = (dat_r << 'd4);
  crm_n         = crm_r;

  case (state_r)
    INIT: begin
      sd_oen_o    = 4'b0001;
      cs_rom_on   = 1'b1;
      cs_ram_on   = 1'b0 | ~rst_in;
      if (cnt_r == 'h0) begin
        state_n = IDLE;
      end
    end
    // ---
    IDLE: begin
      cs_rom_on = 1'b1;
      cs_ram_on = 1'b1;
      if (wb_mem_stb_i == 1'b1) begin
        state_n = INSTR;
        cnt_n   = 'd7;

        if (wb_mem_we_i) begin
          // CASE: write to RAM
          dat_n = INSTR_QWD;
        end else begin
          // Case B: read from RAM or ROM in non-continuous mode
          dat_n = INSTR_QRD;

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
      sd_oen_o  = 4'b0001;
      if (cnt_r == 'h0) begin
        state_n = ADDR;
        dat_n   = adr_init;
        crm_n   = crm_r | (~sel_rom_ram_i & USE_CONTINUOUS_READ_MODE);
        if (sel_rom_ram_i)  cnt_n = 'd5;
        else                cnt_n = 'd7;
      end
    end
    //---
    ADDR: begin
      sd_oen_o  = 4'b1111;
      if (cnt_r == 'h0) begin
        dat_n = data_i_padded; // only needed when writing in case smaller
        if (wb_mem_we_i) begin
          // write: must be ram here
          state_n = DATA_W;
          cnt_n   = cnt_to_write_init;
        end else begin
          // read
          state_n = DUMMY;
          if (sel_rom_ram_i)  cnt_n = (RAM_RD_HIGHZ_CYCLES - 'd1);
          else                cnt_n = (ROM_RD_HIGHZ_CYCLES - 'd1);
        end
      end
    end
    //---
    DUMMY: begin
      if (cnt_r == 'h0) begin
        // must be a read here
        state_n = DATA_R;
        cnt_n   = 'd7;
      end
    end
    //---
    DATA_R: begin
      dat_n = {dat_r[27:0], sd_i};  // shift in this way to just have one shift direction
      if (cnt_r == 'h0) begin
        state_n = ACK;
      end
    end
    //---
    DATA_W: begin
      sd_oen_o = 4'b1111;
      if (cnt_r == 'h0) begin
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
