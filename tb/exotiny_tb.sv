// Copyright (c) 2023 - 2024 Meinhard Kissich
// -----------------------------------------------------------------------------
// File  :  exotiny_tb.sv
// Usage :  Testbench to execute the riscvtests.
// -----------------------------------------------------------------------------

`timescale 1 ns / 1 ps

module exotiny_tb #(
  parameter CHUNKSIZE  = 4,
  parameter RFTYPE     = "BRAM",
  parameter CONF       = "MIN"
);


logic clk   = 1'b0;
logic rst_n = 1'b0;

always #10 clk = ~clk;

initial begin
  rst_n <= 1'b0;
  repeat (100) @(posedge clk);
  rst_n <= 1;
end

initial begin
  //if ($test$plusargs("vcd")) begin
    $dumpfile("tb.vcd");
    $dumpvars(0, exotiny_tb);
  //end
  //repeat (600000) @(posedge clk);
  //$display("TIMEOUT");
  //$fatal;
end

// Hack when solution when not traps are implemented.
reg [31:0] shift_reg = 32'd0;
reg prev_cpu_dmem_stb;

always @(posedge clk) begin
  prev_cpu_dmem_stb <= i_exotiny_sim.i_exotiny.wb_cpu_dmem_stb;
  if ((i_exotiny_sim.i_exotiny.wb_regs_adr[4:0] == 'hC) & i_exotiny_sim.i_exotiny.sel_regs & ~prev_cpu_dmem_stb & i_exotiny_sim.i_exotiny.wb_cpu_dmem_stb) begin
    $write("%c", i_exotiny_sim.i_exotiny.wb_mem_wdat);
    $fflush();
  end
end

always_ff @(posedge clk) begin
  if ((i_exotiny_sim.i_exotiny.wb_regs_adr[4:0] == 'hC) && i_exotiny_sim.i_exotiny.sel_regs & ~prev_cpu_dmem_stb & i_exotiny_sim.i_exotiny.wb_cpu_dmem_stb) begin
    shift_reg <= {shift_reg[23:0], i_exotiny_sim.i_exotiny.wb_cpu_dmem_wdat[7:0]};  // shift in new data
  end
end

`ifndef SIGNATURE
always_ff @(posedge clk) begin
  if (shift_reg == {"D", "O", "N", "E"}) begin
    $finish;
  end
  if (shift_reg[23:0] == {"E", "R", "R"}) begin
    $fatal;
  end
end
`endif

exotiny_sim #( 
  .CHUNKSIZE  ( CHUNKSIZE ),
  .CONF       ( CONF      ),
  .RFTYPE     ( RFTYPE    ),
  .GPOCNT     (  'd6      )
) i_exotiny_sim (
  .clk_i      ( clk   ),
  .rst_in     ( rst_n )
);


endmodule
