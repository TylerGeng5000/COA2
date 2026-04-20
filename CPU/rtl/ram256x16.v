`include "defines.vh"

// 256 x 16 RAM
// - Synchronous read: rdata updates on posedge clk
// - Write on posedge clk when we=1
// Note: Vivado can infer BRAM from this style.
module Ram256x16 #(
  parameter INIT_FILE = ""  // optional: hex file for simulation (readmemh)
)(
  input                 clk,
  input  [`ADDR_W-1:0]  addr,
  input                 we,
  input  [`DATA_W-1:0]  wdata,
  output reg [`DATA_W-1:0] rdata
);
  reg [`DATA_W-1:0] mem [0:(1<<`ADDR_W)-1];

  integer i;
  initial begin
    // Initialize to zeros to avoid X-propagation in simulation.
    for (i = 0; i < (1<<`ADDR_W); i = i + 1) begin
      mem[i] = {`DATA_W{1'b0}};
    end
    // Optional program/data preload.
    if (INIT_FILE != "") begin
      $readmemh(INIT_FILE, mem);
    end
  end

  always @(posedge clk) begin
    // Read-first behavior (rdata gets old mem[addr])
    rdata <= mem[addr];
    if (we) begin
      mem[addr] <= wdata;
    end
  end
endmodule
