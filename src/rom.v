module charrom (
  input wire [6:0] xaddr,
  input wire [4:0] yaddr,
  output wire [2:0] data
);

  wire [11:0] cxy = {yaddr, xaddr};
  reg [2:0] rom[0:3584];
  initial begin
    $readmemh("../data/charrom.hex", rom);
  end
  assign data = rom[cxy];

endmodule

module palette (
  input wire [2:0] color,
  output wire [5:0] r,
  output wire [5:0] g,
  output wire [5:0] b
);
  
    reg [5:0] r_table[0:7];
    reg [5:0] g_table[0:7];
    reg [5:0] b_table[0:7];
    initial begin
      $readmemh("../data/palette_r.hex", r_table);
      $readmemh("../data/palette_g.hex", g_table);
      $readmemh("../data/palette_b.hex", b_table);
    end
    assign r = r_table[color];
    assign g = g_table[color];
    assign b = b_table[color];
endmodule

