// donut ray-marching hit test
module donuthit (
    input clk,
    input start,
    input signed [15:0] pxin,    // origin point
    input signed [15:0] pyin,
    input signed [15:0] pzin,
    input signed [15:0] rxin,    // ray direction
    input signed [15:0] ryin,
    input signed [15:0] rzin,
    input signed [15:0] lxin,    // light direction
    input signed [15:0] lyin,
    input signed [15:0] lzin,
    // these are valid after 8 clocks
    output reg hit,                // hit flag
    output reg signed [15:0] light // light intensity
);

// torus radii
parameter r1 = 1;
parameter r2 = 2;

parameter r1i = r1*256;
parameter r2i = r2*256;

reg signed [15:0] px, py, pz;    // origin point
reg signed [15:0] rx, ry, rz;    // ray direction
reg signed [15:0] lx, ly, lz;    // light direction
reg signed [15:0] t;             // distance along ray

/*
wire signed [15:0] prev_t = start ? 512 : t;
wire signed [15:0] prev_px = start ? pxin : px;
wire signed [15:0] prev_py = start ? pyin : py;
wire signed [15:0] prev_pz = start ? pzin : pz;
wire signed [15:0] prev_rx = start ? rxin : rx;
wire signed [15:0] prev_ry = start ? ryin : ry;
wire signed [15:0] prev_rz = start ? rzin : rz;
wire signed [15:0] prev_lx = start ? lxin : lx;
wire signed [15:0] prev_ly = start ? lyin : ly;
wire signed [15:0] prev_lz = start ? lzin : lz;
*/
wire signed [15:0] prev_t = t;
wire signed [15:0] prev_px = px;
wire signed [15:0] prev_py = py;
wire signed [15:0] prev_pz = pz;
wire signed [15:0] prev_rx = rx;
wire signed [15:0] prev_ry = ry;
wire signed [15:0] prev_rz = rz;
wire signed [15:0] prev_lx = lx;
wire signed [15:0] prev_ly = ly;
wire signed [15:0] prev_lz = lz;


wire signed [15:0] t0;
wire signed [15:0] t1 = t0 - r2i;
wire signed [15:0] t2;
wire signed [15:0] step1_lx, step2_lz;
wire signed [15:0] d = t2 - r1i;

wire signed [29:0] px_projected = d * prev_rx;
wire signed [29:0] py_projected = d * prev_ry;
wire signed [29:0] pz_projected = d * prev_rz;
wire _unused_ok = &{px_projected[13:0], py_projected[13:0], pz_projected[13:0]};

cordic2step cordicxy (
  .xin(prev_px),
  .yin(prev_py),
  .x2in(prev_lx),
  .y2in(prev_ly),
  .length(t0),
  .x2out(step1_lx)
);

cordic2step cordicxz (
  .xin(prev_pz),
  .yin(t1),
  .x2in(prev_lz),
  .y2in(step1_lx),
  .length(t2),
  .x2out(step2_lz)
);

// on start, clock in all inputs (can't assume they're valid after start)
always @(posedge clk) begin
  if (start) begin
    // these do not get recomputed every step, so just latch them
    rx <= rxin;
    ry <= ryin;
    rz <= rzin;
    lx <= lxin;
    ly <= lyin;
    lz <= lzin;
    t <= 512 + d;
    hit <= 1;
    px <= pxin;
    py <= pyin;
    pz <= pzin;
  end else begin
    t <= t + d;
    hit <= hit & (prev_t < 2048);
  px <= prev_px + (px_projected[29:14]);
  py <= prev_py + (py_projected[29:14]);
  pz <= prev_pz + (pz_projected[29:14]);
  end
  light <= step2_lz;
end

endmodule
