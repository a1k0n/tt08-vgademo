`default_nettype none

// non-restoring division algorithm
// divides 65536 by a 9-bit input to yield a 16-bit fixed-point reciprocal
module recip16 (
  input clk,
  input start,
  input [8:0] denom,
  output [15:0] recip
);

reg [3:0] i;
reg [25:0] r;
reg [25:0] d;
reg [15:0] q;

assign recip = (q - ~q) - {15'b0, r[25]};

always @(posedge clk) begin
  if (start) begin
    d <= {1'b0, denom, 16'b0};
    r <= (65536<<1) - {1'b0, denom, 16'b0};
    i <= 1;
    q <= 1;
  end else if (i != 0) begin
    if (r[25]) begin  // r < 0
      r <= (r<<1) + d;
      q <= (q<<1);
    end else begin
      r <= (r<<1) - d;
      q <= (q<<1) | 1;
    end
    i <= i + 1;
  end
end

endmodule

