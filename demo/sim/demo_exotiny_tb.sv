// Copyright (c) 2024 Meinhard Kissich
// -----------------------------------------------------------------------------
// File  :  demo_exotiny_tb.sv
// Usage :  Testbench to execute ExoTiny demo.
// -----------------------------------------------------------------------------

`timescale 1 ns / 1 ps

module demo_exotiny_tb;

localparam CHUNKSIZE  = 2;
localparam RFTYPE     = "LOGIC";
localparam CONF       = "MIN";

logic clk   = 1'b0;
logic rst_n = 1'b0;

always #20 clk = ~clk;

initial begin
  rst_n <= 1'b0;
  repeat (100) @(posedge clk);
  rst_n <= 1;
end

initial begin
  $dumpfile("tb.vcd");
  $dumpvars(0, demo_exotiny_tb);
end

exotiny_sim #( 
  .CHUNKSIZE ( CHUNKSIZE  ),
  .CONF      ( CONF       ),
  .RFTYPE    ( RFTYPE     )
) i_exotiny_sim (
  .clk_i      ( clk   ),
  .rst_in     ( rst_n )
);

endmodule
