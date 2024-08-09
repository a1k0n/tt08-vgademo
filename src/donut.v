// render a ray-marched donut
// takes 8 clock cycles per pixel, so this will have to be pipelined for
// higher resolution

module donut (
  input clk,
  input rst_n,
  input [10:0] h_count,
  input [9:0] v_count,
  output reg donut_visible,
  output reg [5:0] donut_luma
);

parameter dz = 5;

// I'm sorry, this is totally incomprehensible even to me; I have lost the derivation
// but I promise to come back and explain it

reg signed [15:0] cA, sA, cB, sB;
reg signed [15:0] sAsB, cAsB, sAcB, cAcB;

// sine/cosine rotations
wire signed [15:0] cA1 = cA - (sA >>> 5);
wire signed [15:0] sA1 = sA + (cA1 >>> 5);
wire signed [15:0] cAsB1 = cAsB - (sAsB >>> 5);
wire signed [15:0] sAsB1 = sAsB + (cAsB1 >>> 5);
wire signed [15:0] cAcB1 = cAcB - (sAcB >>> 5);
wire signed [15:0] sAcB1 = sAcB + (cAcB1 >>> 5);

wire signed [15:0] cB1 = cB - (sB >>> 6);
wire signed [15:0] sB1 = sB + (cB1 >>> 6);
wire signed [15:0] cAcB2 = cAcB1 - (cAsB1 >>> 6);
wire signed [15:0] cAsB2 = cAsB1 + (cAcB2 >>> 6);
wire signed [15:0] sAcB2 = sAcB1 - (sAsB1 >>> 6);
wire signed [15:0] sAsB2 = sAsB1 + (sAcB2 >>> 6);

reg signed [15:0] ycA, ysA;
reg signed [15:0] rx, ry, rz;

/*
wire signed [15:0] p0x = (dz * sB) >>> 6;
wire signed [15:0] p0y = (dz * sAcB) >>> 6;
wire signed [15:0] p0z = -(dz * cAcB) >>> 6;
dz = 5, so just use shifts and adds here
*/
wire signed [15:0] p0x = (sB>>>6) + (sB>>>4);
wire signed [15:0] p0y = (sAcB>>>6) + (sAcB>>>4);
wire signed [15:0] p0z = (-cAcB>>>6) + (-cAcB>>>4);

wire signed [15:0] yincC = cA >>> 8;
wire signed [15:0] yincS = sA >>> 8;

wire signed [15:0] xincX = cB >>> 6;
wire signed [15:0] xincY = -(sAsB >>> 6);
wire signed [15:0] xincZ = cAsB >>> 6;

/*
wire signed [15:0] xsAsB = 76*xincY;
wire signed [15:0] xcAsB = -76*xincZ;
*/
// 01001100 = 76
wire signed [15:0] xsAsB = (xincY<<6) + (xincY<<3) + (xincY<<2);
wire signed [15:0] xcAsB = -((xincZ<<6) + (xincZ<<3) + (xincZ<<2));

// pre-step initial ray a bit to reduce iterations
wire signed [15:0] px = p0x + (rx>>>5);
wire signed [15:0] py = p0y + (ry>>>5);
wire signed [15:0] pz = p0z + (rz>>>5);

wire signed [15:0] lx = sB >>> 2;
wire signed [15:0] ly = (sAcB - cA) >>> 2;
wire signed [15:0] lz = (-cAcB - sA) >>> 2;

// fixme: change range from -32..31 to 0..63
wire signed [15:0] luma_unstable;
wire hit_unstable;

donuthit donuthit (
  .clk(clk),
  .start(h_count[2:0] == 0),
  .pxin(px),
  .pyin(py),
  .pzin(pz),
  .rxin(rx),
  .ryin(ry),
  .rzin(rz),
  .lxin(lx),
  .lyin(ly),
  .lzin(lz),
  .hit(hit_unstable),
  .light(luma_unstable)
);

always @(posedge clk) begin
  if (~rst_n) begin
    cA <= 16'h2d3f;
    sA <= 16'h2d3f;
    cB <= 16'h4000;
    sB <= 16'h0000;
    sAsB <= 16'h0000;
    cAsB <= 16'h0000;
    sAcB <= 16'h2d3f;
    cAcB <= 16'h2d3f;

  end else begin
    if (h_count == 0 && v_count == 0) begin
      // this is timed wrong but we want the first frame to not be garbage somehow
      // ycA/ysA*240; 240 = 256 - 16
      ycA <= -(yincC<<8) + (yincC<<4);
      ysA <= -(yincS<<8) + (yincS<<4);
      /*
      this will be garbage on the first scanline but i don't care
      rx <= -76*xincX - sB;
      ry <= -yincC*240 - xsAsB - sAcB;
      rz <= -yincS*240 + xcAsB + cAcB;
      */
      // also rotate cA, sA, cB, sB, cAsB, sAsB, cAcB, sAcB
      cA <= cA1;
      sA <= sA1;
      cB <= cB1;
      sB <= sB1;
      cAsB <= cAsB2;
      sAsB <= sAsB2;
      cAcB <= cAcB2;
      sAcB <= sAcB2;
    end
    if (h_count < 1220-8) begin
      if (h_count[2:0] == 0) begin
        // latch output registers
        donut_visible <= hit_unstable;
        // todo: convert from -32..31 to 0..63
        donut_luma <= {!luma_unstable[13], luma_unstable[12:8]};
      end else if (h_count[2:0] == 7) begin
        // step forward one pixel so that next clock donuthit's inputs are stable
        rx <= rx + xincX;
        ry <= ry + xincY;
        rz <= rz + xincZ;
      end
    end else if (h_count == vgademo.H_TOTAL-1) begin
      // step y
      ycA <= ycA + yincC;
      ysA <= ysA + yincS;
      // 76 = 01001100
      rx <= -((xincX<<6) + (xincX<<3) + (xincX<<2)) - sB;
      ry <= ycA - xsAsB - sAcB;
      rz <= ysA + xcAsB + cAcB;
    end
    // if h_count < 1220:
    //  - if h_count&7 == 0, load in new donuthit query
    // if h_count == 1220, compute next line constants
    // if v_count == 480, compute next frame constants
    //  - rotate sines, cosines, and combinations thereof

    // if h_count == H_TOTAL-8 && v_count == V_TOTAL-1, kick off the next frame
  end
end


endmodule

