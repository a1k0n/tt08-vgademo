module charrom (
  input wire char,
  input wire [4:0] xaddr,
  input wire [4:0] yaddr,
  output wire [2:0] data
);

  wire [10:0] cxy = {char, yaddr, xaddr};
  reg [9:0] rom[2047:0];
  initial begin
    $readmemh("rom.hex", rom);
  end
  assign data = rom[cxy];

endmodule

module palette (
  input wire [2:0] color,
  output wire [5:0] r,
  output wire [5:0] g,
  output wire [5:0] b
);
  
    reg [5:0] r_table[7:0];
    reg [5:0] g_table[7:0];
    reg [5:0] b_table[7:0];
    initial begin
      $readmemh("r.hex", r_table);
      $readmemh("g.hex", g_table);
      $readmemh("b.hex", b_table);
    end
    assign r = r_table[color];
    assign g = g_table[color];
    assign b = b_table[color];
endmodule

module plane_dx_rom (
  input wire [7:0] y,
  output wire [10:0] dx
);
  reg [10:0] dx_table[240:0];
  initial begin
    $readmemh("plane_dx.hex", dx_table);
  end
  assign dx = dx_table[y];
endmodule
