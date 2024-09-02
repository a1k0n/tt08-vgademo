`default_nettype none

module vgademo (
    input clk48,
    input rst_n,
    output reg vsync,  // vsync
    output reg hsync,  // hsync
    output reg [1:0] b_out, // Blue
    output reg [1:0] g_out, // Green
    output reg [1:0] r_out, // Red
    output audio_out 
);

wire [15:0] audio_sample;
reg [6:0] scanline_audio_sample;  // sampled on hblank, used to show oscilloscope
wire [2:0] audio_kick_frames;
wire [3:0] audio_snare_frames;
wire [7:0] audio_songpos;
audiotrack soundtrack(
    .clk48(clk48),
    .rst_n(rst_n),
    .audio_sample(audio_sample),
    .kick_frames_out(audio_kick_frames),
    .snare_frames_out(audio_snare_frames),
    .songpos_out(audio_songpos),
    .out(audio_out)
);

// VGA timing parameters for 640x480 @ 60Hz
parameter H_DISPLAY = 1220;
parameter H_FRONT_PORCH = 31;
parameter H_SYNC_PULSE = 183;
parameter H_BACK_PORCH = 92;
parameter H_TOTAL = 1525;  // ideally 1525.322; run clock at 47.989844 MHz for better VGA timing :)

parameter V_DISPLAY = 480;
parameter V_FRONT_PORCH = 10;
parameter V_SYNC_PULSE = 2;
parameter V_BACK_PORCH = 33;
parameter V_TOTAL = 525;

parameter CHARROM_HEIGHT = 28;

reg [10:0] frame;
reg [10:0] h_count;
reg [9:0] v_count;

wire display_active = (h_count < H_DISPLAY) && (v_count < V_DISPLAY);

reg signed [15:0] a_cos;
reg signed [15:0] a_sin;
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

// --- sine scroller
//wire [9:0] scrolltext_height = (a_sin >>> 7) + 186 + (b_cos >>> 9);
//wire [9:0] scrolltext_height = (a_sin >>> 9) + 93 + (b_cos >>> 9);
wire [9:0] scrolltext_height = PLANE_Y_START - 32 - CHARROM_HEIGHT*4 + (b_cos >>> 9);
//wire [2:0] chardata;
wire char_active_;
wire [6:0] scrollv = (display_plane ? plane_v[8:2] : v_count[6:0]) - scrolltext_height[6:0];
wire [10:0] scrollh = (display_plane ? plane_u[20:10] : h_count - 610) + (frame<<3) + (frame<<2);
charmask charmask (
    .xaddr(scrollh[9:3]),
    .yaddr(scrollv[6:2]),
    .data(char_active_)
);
wire char_active = scrollh[10] & char_active_;
wire scrolltext_active = char_active && ((v_count >= scrolltext_height) && (v_count < scrolltext_height + CHARROM_HEIGHT*4));
wire shadow_active = char_active && ((plane_v[9:2] >= scrolltext_height) && (plane_v[9:2] < scrolltext_height + CHARROM_HEIGHT*4));
wire [2:0] scrolltext_palidx = scrollh[6:4] + scrollv[5:3];
//wire [2:0] scrolltext_palidx = (scrollh[6:1] + scrollv[5:0]) >> 3;
wire [5:0] char_r, char_g, char_b;
palette palette (
    .color(scrolltext_palidx),
    .r(char_r),
    .g(char_g),
    .b(char_b)
);

reg signed [15:0] a_scrollx;
reg signed [15:0] a_scrolly;

task new_frame;
    begin
        frame <= frame + 1;
        a_scrollx <= a_scrollx + (a_cos >>> 10);
        a_scrolly <= a_scrolly + (a_sin >>> 11);
        step_sincos;
        linelfsr <= 13'h1AFA;
    end
endtask

// start the 3D plane halfway down the screen
parameter PLANE_Y_START = 240;
parameter PLANE_Y_SKIPLINES = 33;
wire [8:0] plane_y = v_count - PLANE_Y_START + PLANE_Y_SKIPLINES - audio_kick_frames;
wire display_plane = v_count >= PLANE_Y_START;
reg [20:0] plane_u;
reg [10:0] plane_du;
wire [10:0] plane_v = plane_du;  // hack: the vertical component happens to be equal to the horizontal step size
wire [10:0] plane_dx;
reg [12:0] linelfsr;

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
        //plane_u <= -(plane_dx * (H_DISPLAY>>1));
        plane_u <= -((plane_dx<<1) + (plane_dx<<5) + (plane_dx<<6) + (plane_dx<<9));
        b_cos <= a_cos;
        b_sin <= a_sin;

        linelfsr <= linelfsr[0] ? (linelfsr>>1) ^ 13'h1159 : linelfsr>>1;

        scanline_audio_sample <= audio_sample[15:9];
    end
endtask

// Horizontal and vertical counters
always @(posedge clk48 or negedge rst_n) begin
    if (~rst_n) begin
        h_count <= 0;
        v_count <= 0;
        frame <= 0;
        a_scrollx <= 0;
        a_scrolly <= 0;
        a_cos <= 16'h4000;
        a_sin <= 16'h0000;
    end else begin
        if (h_count == H_TOTAL - 1) begin
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
end

// Generate checkerboard pattern with border
//wire [10:0] hscroll = h_count + a_scrollx;
//wire [9:0] vscroll = v_count + a_scrolly;
//wire checkerboard = display_plane ? (plane_u[16] ^ plane_v[6]) : hscroll[7] ^ vscroll[6];
wire [11:0] hscroll = plane_u[20:9] + a_scrollx[11:0];
wire [10:0] vscroll = plane_v[10:1] + a_scrolly[10:0];
wire checkerboard = hscroll[7] ^ vscroll[6];

wire [3:0] checker_i = hscroll[10:7];
wire [3:0] checker_j = vscroll[9:6];
wire [3:0] checker_bayer = {
    checker_j[0], checker_i[1]^checker_j[1],
    checker_i[0], checker_i[2]^checker_j[2]
    //checker_i[2], checker_i[2]^checker_j[2],
};

//wire active_tile = audio_songpos[7:6] == 3 && (checker_i + checker_j) <= audio_songpos[5:2];
wire active_tile = audio_songpos[7:6] == 3 && checker_bayer == audio_songpos[3:0];

wire [5:0] checker_raw_r = (active_tile ? 63 : 0) | (checkerboard ? hscroll[8:3] : 0);
wire [5:0] checker_raw_g = (active_tile ? 63 : 0) | (checkerboard ? vscroll[8:3] : 0);
wire [5:0] checker_raw_b = (active_tile ? 63 : 0) | (checkerboard ? vscroll[7:2] : 0);

wire [5:0] checker_r = shadow_active ? {2'b0, checker_raw_r[5:2]} : checker_raw_r;
wire [5:0] checker_g = shadow_active ? {2'b0, checker_raw_g[5:2]} : checker_raw_g;
wire [5:0] checker_b = shadow_active ? {2'b0, checker_raw_b[5:2]} : checker_raw_b;

// --- starfield

wire [10:0] starfield_x = linelfsr[12:2] + (frame<<1) + (linelfsr[1] ? frame<<2 : 0) + (linelfsr[0] ? frame<<3 : 0);
//wire star_pixel = h_count >= starfield_x && h_count < starfield_x + 3;
wire star_pixel = h_count >= starfield_x && h_count < starfield_x + 2 + (7^(audio_snare_frames[3:1]));
wire starfield = !display_plane;

// --- oscilloscope
wire oscilloscope_active = h_count[10:0] < {4'b0, scanline_audio_sample};
wire oscilloscope_active2 = h_count[10:0] < {4'b0, scanline_audio_sample-6'd8};
wire [5:0] scope_r = oscilloscope_active2 ? 15 : 63;
wire [5:0] scope_g = oscilloscope_active2 ? 31 : 63;
wire [5:0] scope_b = oscilloscope_active2 ? 31 : 63;

// --- final color mux
wire [5:0] r = oscilloscope_active ? scope_r : scrolltext_active ? char_r : starfield ? (star_pixel ? 63 : 0) : checker_r;
wire [5:0] g = oscilloscope_active ? scope_g : scrolltext_active ? char_g : starfield ? (star_pixel ? 63 : 0) : checker_g;
wire [5:0] b = oscilloscope_active ? scope_b : scrolltext_active ? char_b : starfield ? (star_pixel ? 63 : 0) : checker_b;

// Bayer dithering
// this is a 8x4 Bayer matrix which gets toggled every frame (so the other 8x4 elements are actually on odd frames)
wire [2:0] bayer_i = h_count[2:0] ^ {3{frame[0]}};
wire [1:0] bayer_j = v_count[1:0];
wire [2:0] bayer_x = {bayer_i[2], bayer_i[1]^bayer_j[1], bayer_i[0]^bayer_j[0]};
wire [4:0] bayer = {bayer_x[0], bayer_i[0], bayer_x[1], bayer_i[1], bayer_x[2]};

// output dithered 2 bit color from 6 bit color and 5 bit Bayer matrix
function [1:0] dither2;
    input [5:0] color6;
    input [4:0] bayer5;
    begin
        dither2 = ({1'b0, color6} + {2'b0, bayer5} + color6[0]) >> 5;
    end
endfunction

wire [1:0] rdither = dither2(r, bayer);
wire [1:0] gdither = dither2(g, bayer);
wire [1:0] bdither = dither2(b, bayer);

always @(posedge clk48) begin
    // Generate sync signals
    hsync <= ~((h_count >= (H_DISPLAY + H_FRONT_PORCH)) && (h_count < (H_DISPLAY + H_FRONT_PORCH + H_SYNC_PULSE)));
    vsync <= ~((v_count >= (V_DISPLAY + V_FRONT_PORCH)) && (v_count < (V_DISPLAY + V_FRONT_PORCH + V_SYNC_PULSE)));
    // Assign color outputs
    r_out <= display_active ? rdither : 0; // Red
    g_out <= display_active ? gdither : 0; // Green
    b_out <= display_active ? bdither : 0; // Blue
end

endmodule
