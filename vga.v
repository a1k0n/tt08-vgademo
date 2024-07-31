module vga_generator (
    input clk48,
    output gpio_0,  // hsync
    output gpio_1,  // vsync
    output gpio_a0, // Red
    output gpio_a1, // Green
    output gpio_a2  // Blue
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
    parameter BORDER_WIDTH = 20;

    reg [10:0] h_count = 0;
    reg [9:0] v_count = 0;

    // Horizontal and vertical counters
    always @(posedge clk48) begin
        if (h_count == H_TOTAL - 1) begin
            h_count <= 0;
            if (v_count == V_TOTAL - 1)
                v_count <= 0;
            else
                v_count <= v_count + 1;
        end else begin
            h_count <= h_count + 1;
        end
    end

    // Generate sync signals
    assign gpio_0 = ~((h_count >= (H_DISPLAY + H_FRONT_PORCH)) && (h_count < (H_DISPLAY + H_FRONT_PORCH + H_SYNC_PULSE)));
    assign gpio_1 = ~((v_count >= (V_DISPLAY + V_FRONT_PORCH)) && (v_count < (V_DISPLAY + V_FRONT_PORCH + V_SYNC_PULSE)));

    // Generate checkerboard pattern with border
    wire display_active = (h_count < H_DISPLAY) && (v_count < V_DISPLAY);
    wire checker = h_count[7] ^ v_count[6];
    
    wire border = (h_count < BORDER_WIDTH) || (h_count >= H_DISPLAY - BORDER_WIDTH) ||
                  (v_count < BORDER_WIDTH) || (v_count >= V_DISPLAY - BORDER_WIDTH);

    // Assign color outputs
    assign gpio_a0 = display_active && (border || checker); // Red
    assign gpio_a1 = display_active && (border || checker); // Green
    assign gpio_a2 = display_active && (border || checker); // Blue

endmodule
