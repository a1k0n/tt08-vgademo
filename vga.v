module vga_generator (
    input clk48,
    output gpio_0,  // vsync
    output gpio_1,  // hsync
    output gpio_a0, // Blue
    output gpio_a1, // Green
    output gpio_a2  // Red
);

// VGA timing parameters for 640x480 @ 60Hz
parameter H_DISPLAY = 1220;
parameter H_FRONT_PORCH = 31;
parameter H_SYNC_PULSE = 183;
parameter H_BACK_PORCH = 92;
parameter H_TOTAL = H_DISPLAY + H_FRONT_PORCH + H_SYNC_PULSE + H_BACK_PORCH;

parameter V_DISPLAY = 480;
parameter V_FRONT_PORCH = 10;
parameter V_SYNC_PULSE = 2;
parameter V_BACK_PORCH = 33;
parameter V_TOTAL = 525;

// Border width
parameter BORDER_WIDTH_X = 40;
parameter BORDER_WIDTH_Y = 20;

// Generate sync signals
wire display_active = (h_count < H_DISPLAY) && (v_count < V_DISPLAY);
assign gpio_1 = ~((h_count >= (H_DISPLAY + H_FRONT_PORCH)) && (h_count < (H_DISPLAY + H_FRONT_PORCH + H_SYNC_PULSE)));
assign gpio_0 = ~((v_count >= (V_DISPLAY + V_FRONT_PORCH)) && (v_count < (V_DISPLAY + V_FRONT_PORCH + V_SYNC_PULSE)));

reg [10:0] frame = 0;
reg [10:0] h_count = 0;
reg [9:0] v_count = 0;

reg signed [15:0] a_cos = 16'h4000;
reg signed [15:0] a_sin = 16'h0000;
wire signed [15:0] acos1 = a_cos - (a_sin >>> 6);
task step_sincos;
    begin
        a_cos <= acos1;
        a_sin <= a_sin + (acos1 >>> 6);
    end
endtask

wire [9:0] scrolltext_height = (a_sin >>> 7) + 186;

wire [2:0] chardata;
wire [6:0] scrollv = v_count - scrolltext_height;
wire [8:0] scrollh = h_count + (frame<<3) + (frame<<2);
charrom charrom (
    .char(scrollh[8]),
    .xaddr(scrollh[7:3]),
    .yaddr(scrollv[6:2]),
    .data(chardata)
);
wire [5:0] char_r, char_g, char_b;
palette palette (
    .color(chardata[2:0]),
    .r(char_r),
    .g(char_g),
    .b(char_b)
);


reg signed [15:0] a_scrollx = 0;
reg signed [15:0] a_scrolly = 0;

reg [17:0] lfsr = 18'h1FAF5;
always @(posedge clk48) begin
    lfsr <= {lfsr[16:0], lfsr[17] ~^ lfsr[10]};
end

task new_frame;
    begin
        frame <= frame + 1;
        a_scrollx <= a_scrollx + (a_cos >>> 10);
        a_scrolly <= a_scrolly + (a_sin >>> 11);
        step_sincos;
    end
endtask

// start the 3D plane halfway down the screen
parameter PLANE_Y_START = 240;
parameter PLANE_Y_SKIPLINES = 20;
wire [7:0] plane_y = v_count - PLANE_Y_START;//  + PLANE_Y_SKIPLINES;
wire display_plane = v_count >= PLANE_Y_START;
reg [17:0] plane_u;
reg [9:0] plane_v;
wire [10:0] plane_dx;
plane_dx_rom plane_dx_rom (
    .y(plane_y+1),  // load for next line while we're in hblank for previous line
    .dx(plane_dx)
);

// runs during hblank
task start_of_next_line;
    begin
        plane_u <= -(plane_dx * (H_DISPLAY>>1));
        plane_v <= plane_dx;
    end
endtask

// Horizontal and vertical counters
always @(posedge clk48) begin
    if (h_count == H_TOTAL - 1) begin
        h_count <= 0;
        if (v_count == V_TOTAL - 1) begin
            v_count <= 0;
            new_frame;
        end else
            v_count <= v_count + 1;
    end else begin
        h_count <= h_count + 1;
    end

    if (h_count == H_DISPLAY)
        start_of_next_line;
    else if (h_count < H_DISPLAY)
        plane_u <= plane_u + plane_dx;
end

// Generate checkerboard pattern with border
//wire [10:0] hscroll = h_count + a_scrollx;
//wire [9:0] vscroll = v_count + a_scrolly;
//wire checkerboard = display_plane ? (plane_u[16] ^ plane_v[6]) : hscroll[7] ^ vscroll[6];
wire [10:0] hscroll = display_plane ? (plane_u[17:9] + a_scrollx) : h_count + a_scrollx;
wire [9:0] vscroll = display_plane ? (plane_v[9:1] + a_scrolly) : v_count + a_scrolly;
wire checkerboard = hscroll[7] ^ vscroll[6];

wire colorbar_active = (v_count < V_FRONT_PORCH + 8) && (h_count < 128*8);

wire char_active = chardata != 0 && ((v_count >= scrolltext_height) && (v_count < scrolltext_height + 32*4));
wire [5:0] r = char_active ? char_r : checkerboard ? hscroll[8:3] : 0;
wire [5:0] g = char_active ? char_g : checkerboard ? vscroll[8:3] : 0;
wire [5:0] b = char_active ? char_b : checkerboard ? vscroll[7:2] : 0;

// Bayer dithering
// i is h_count[2:0] and j is v_count[2:0]
// M(i,j) = bit_reverse(bit_interleave(i^j, i))
// bit_interleave(i,j) = i[0]j[0]i[1]j[1]i[2]j[2]
wire [2:0] bayer_i = h_count[2:0] ^ frame[0];
wire [2:0] bayer_j = v_count[2:0];
wire [5:0] bayer = {bayer_i[0]^bayer_j[0], bayer_i[0], bayer_i[1]^bayer_j[1], bayer_i[1], bayer_i[2]^bayer_j[2], bayer_i[2]};

// if r < lfsr[5:0] then rdither = 0 else rdither = 1
wire rdither1 = colorbar_active ? h_count[7] : r > lfsr[5:0];
wire gdither1 = colorbar_active ? h_count[8] : g > lfsr[11:6];
wire bdither1 = colorbar_active ? h_count[9] : b > lfsr[17:12];

wire rdither2 = colorbar_active ? h_count[7] : r > bayer;
wire gdither2 = colorbar_active ? h_count[8] : g > bayer;
wire bdither2 = colorbar_active ? h_count[9] : b > bayer;

wire rdither = frame[7] ? rdither1 : rdither2;
wire gdither = frame[7] ? gdither1 : gdither2;
wire bdither = frame[7] ? bdither1 : bdither2;

// Assign color outputs
assign gpio_a2 = display_active && rdither; // Red
assign gpio_a1 = display_active && gdither; // Green
assign gpio_a0 = display_active && bdither; // Blue

endmodule
