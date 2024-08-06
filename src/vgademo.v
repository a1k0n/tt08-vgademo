module vgademo (
    input clk48,
    input pause_n,
    input rst_n,
    output vsync,  // vsync
    output hsync,  // hsync
    output [1:0] b_out, // Blue
    output [1:0] g_out, // Green
    output [1:0] r_out  // Red
);

// VGA timing parameters for 640x480 @ 60Hz
parameter H_DISPLAY = 1220;
parameter H_FRONT_PORCH = 31;
parameter H_SYNC_PULSE = 183;
parameter H_BACK_PORCH = 92;
parameter H_TOTAL = 1525;  // ideally 1525.322; run clock at 4.7989844 MHz for better VGA timing

parameter V_DISPLAY = 480;
parameter V_FRONT_PORCH = 10;
parameter V_SYNC_PULSE = 2;
parameter V_BACK_PORCH = 33;
parameter V_TOTAL = 525;

reg [10:0] frame = 0;
reg [10:0] h_count = 0;
reg [9:0] v_count = 0;

// Generate sync signals
wire display_active = (h_count < H_DISPLAY) && (v_count < V_DISPLAY);
assign hsync = ~((h_count >= (H_DISPLAY + H_FRONT_PORCH)) && (h_count < (H_DISPLAY + H_FRONT_PORCH + H_SYNC_PULSE)));
assign vsync = ~((v_count >= (V_DISPLAY + V_FRONT_PORCH)) && (v_count < (V_DISPLAY + V_FRONT_PORCH + V_SYNC_PULSE)));

reg signed [15:0] a_cos = 16'h4000;
reg signed [15:0] a_sin = 16'h0000;
reg signed [15:0] b_cos;
reg signed [15:0] b_sin;
wire signed [15:0] acos1 = a_cos - (a_sin >>> 6);
wire signed [15:0] bcos1 = b_cos - (b_sin >>> 7);
task step_sincos;
    begin
        a_cos <= acos1;
        a_sin <= a_sin + (acos1 >>> 6);
    end
endtask

wire [9:0] scrolltext_height = (a_sin >>> 7) + 186 + (b_cos >>> 9);

wire [2:0] chardata;
wire [6:0] scrollv = v_count[6:0] - scrolltext_height[6:0];
wire [10:0] scrollh = h_count + (frame<<3) + (frame<<2);
charrom charrom (
    .sym(scrollh[9:8]),
    .xaddr(scrollh[7:3]),
    .yaddr(scrollv[6:2]),
    .data(chardata)
);
wire [2:0] scrolltext_palidx = scrollh[10] ? chardata[2:0] : 0;
wire [5:0] char_r, char_g, char_b;
palette palette (
    .color(scrolltext_palidx),
    .r(char_r),
    .g(char_g),
    .b(char_b)
);


reg signed [15:0] a_scrollx = 0;
reg signed [15:0] a_scrolly = 0;

/*
reg [17:0] lfsr = 18'h1FAF5;
always @(posedge clk48) begin
    lfsr <= {lfsr[16:0], lfsr[17] ~^ lfsr[10]};
end
*/

task new_frame;
    begin
        if (~rst_n) begin
            frame <= 0;
            a_scrollx <= 0;
            a_scrolly <= 0;
            a_cos <= 16'h4000;
            a_sin <= 16'h0000;
        end else if (pause_n) begin
            frame <= frame + 1;
            a_scrollx <= a_scrollx + (a_cos >>> 10);
            a_scrolly <= a_scrolly + (a_sin >>> 11);
            step_sincos;
        end
        linelfsr <= 13'h1AFA;
    end
endtask

// start the 3D plane halfway down the screen
parameter PLANE_Y_START = 240;
parameter PLANE_Y_SKIPLINES = 33;
wire [8:0] plane_y = v_count - PLANE_Y_START + PLANE_Y_SKIPLINES;
wire display_plane = v_count >= PLANE_Y_START;
reg [17:0] plane_u;
reg [10:0] plane_du;
wire [9:0] plane_v = plane_du;
wire [10:0] plane_dx;
reg [12:0] linelfsr = 13'h1AFA;

// we can compute this at the beginning of the previous line; it'll get picked
// up at the end.
recip16 plane_dx_div (
    .clk(clk48),
    .start(h_count == H_DISPLAY - 16),
    .denom(plane_y+1),
    .recip(plane_dx)
);

// runs during hblank
task start_of_next_line;
    begin
        plane_du <= plane_dx;
        plane_u <= -(plane_dx * (H_DISPLAY>>1));
        // plane_v <= plane_dx;
        b_cos <= a_cos;
        b_sin <= a_sin;

        linelfsr <= linelfsr[0] ? (linelfsr>>1) ^ 13'h1159 : linelfsr>>1;
    end
endtask

// Horizontal and vertical counters
always @(posedge clk48) begin
    if (~rst_n) begin
        h_count <= 0;
        v_count <= 0;
    end else if (h_count == H_TOTAL - 1) begin
        h_count <= 0;
        if (v_count == V_TOTAL - 1) begin
            v_count <= 0;
            new_frame;
        end else
            v_count <= v_count + 1;
    end else begin
        h_count <= h_count + 1;
        b_cos <= bcos1;
        b_sin <= b_sin + (bcos1 >>> 7);
    end

    // Start of next line, plus clock cycles to account for divider to finish
    if (h_count == H_DISPLAY)
        start_of_next_line;
    else if (h_count < H_DISPLAY)
        plane_u <= plane_u + plane_du;
end

// Generate checkerboard pattern with border
//wire [10:0] hscroll = h_count + a_scrollx;
//wire [9:0] vscroll = v_count + a_scrolly;
//wire checkerboard = display_plane ? (plane_u[16] ^ plane_v[6]) : hscroll[7] ^ vscroll[6];
wire [10:0] hscroll = (display_plane ? plane_u[17:9] : h_count) + a_scrollx;
wire [9:0] vscroll = (display_plane ? plane_v[9:1] : v_count) + a_scrolly;
wire checkerboard = hscroll[7] ^ vscroll[6];

wire [10:0] starfield_x = linelfsr[12:2] + (frame<<1) + (linelfsr[1] ? frame<<2 : 0) + (linelfsr[0] ? frame<<3 : 0);
wire star_pixel = h_count >= starfield_x && h_count < starfield_x + 3;
wire starfield = !display_plane;

wire colorbar_active = (v_count < 8) && (h_count < 128*8);
wire colorbar2_active = !colorbar_active && (v_count < 16) && (h_count < 128*8);

wire char_active = scrolltext_palidx != 0 && ((v_count >= scrolltext_height) && (v_count < scrolltext_height + 32*4));
wire [5:0] r = char_active ? char_r : starfield ? (star_pixel ? 63 : 0) : checkerboard ? hscroll[8:3] : 0;
wire [5:0] g = char_active ? char_g : starfield ? (star_pixel ? 63 : 0) : checkerboard ? vscroll[8:3] : 0;
wire [5:0] b = char_active ? char_b : starfield ? (star_pixel ? 63 : 0) : checkerboard ? vscroll[7:2] : 0;

// Bayer dithering
// i is h_count[2:0] and j is v_count[2:0]
// M(i,j) = bit_reverse(bit_interleave(i^j, i))
// bit_interleave(i,j) = i[0]j[0]i[1]j[1]i[2]j[2]
wire [2:0] bayer_i = h_count[2:0] ^ frame[0];
wire [2:0] bayer_j = v_count[2:0];// + frame[1];
//wire [5:0] bayer = {bayer_i[0]^bayer_j[0], bayer_i[0], bayer_i[1]^bayer_j[1], bayer_i[1], bayer_i[2]^bayer_j[2], bayer_i[2]};
// this is a 8x4 Bayer matrix which gets toggled every frame (so the other 8x4 elements are actually on odd frames)
wire [4:0] bayer = {bayer_i[0], bayer_i[1]^bayer_j[1], bayer_i[1], bayer_i[2]^bayer_j[2], bayer_i[2]};

// if r < lfsr[5:0] then rdither = 0 else rdither = 1
/*
wire rdither1 = colorbar_active ? h_count[7] : r > lfsr[5:0];
wire gdither1 = colorbar_active ? h_count[8] : g > lfsr[11:6];
wire bdither1 = colorbar_active ? h_count[9] : b > lfsr[17:12];
*/

// output dithered 2 bit color from 6 bit color and 5 bit Bayer matrix
function [1:0] dither2;
    input [5:0] color6;
    input [4:0] bayer5;
    begin
        dither2 = ({1'b0, color6} + {2'b0, bayer5}) >> 5;
    end
endfunction

wire [1:0] rdither = colorbar2_active ? dither2(h_count[5:0], bayer) : colorbar_active ? h_count[5:4] : dither2(r, bayer);
wire [1:0] gdither = colorbar2_active ? dither2(h_count[7:2], bayer) : colorbar_active ? h_count[7:6] : dither2(g, bayer);
wire [1:0] bdither = colorbar2_active ? dither2(h_count[9:4], bayer) : colorbar_active ? h_count[9:8] : dither2(b, bayer);

// Assign color outputs
assign r_out = display_active ? rdither : 0; // Red
assign g_out = display_active ? gdither : 0; // Green
assign b_out = display_active ? bdither : 0; // Blue

endmodule
