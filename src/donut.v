module donut (
    input clk,
    input start,
    input signed [15:0] px,    // origin point
    input signed [15:0] py,
    input signed [15:0] pz,
    input signed [15:0] rx,    // ray direction
    input signed [15:0] ry,
    input signed [15:0] rz,
    input signed [15:0] lx,    // light direction
    input signed [15:0] ly,
    input signed [15:0] lz,
    output hit,                // hit flag
    output signed [15:0] light // light intensity
);

endmodule