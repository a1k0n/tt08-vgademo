module vga_generator (
    input clk48,
    output gpio_0,  // hsync
    output gpio_1,  // vsync
    output gpio_a0, // Red
    output gpio_a1, // Green
    output gpio_a2  // Blue
);

    // VGA timing parameters for 640x480 @ 60Hz
    parameter H_DISPLAY = 640;
    parameter H_FRONT_PORCH = 16;
    parameter H_SYNC_PULSE = 96;
    parameter H_BACK_PORCH = 48;
    parameter H_TOTAL = H_DISPLAY + H_FRONT_PORCH + H_SYNC_PULSE + H_BACK_PORCH;

    parameter V_DISPLAY = 480;
    parameter V_FRONT_PORCH = 10;
    parameter V_SYNC_PULSE = 2;
    parameter V_BACK_PORCH = 33;
    parameter V_TOTAL = V_DISPLAY + V_FRONT_PORCH + V_SYNC_PULSE + V_BACK_PORCH;

    reg [9:0] h_count = 0;
    reg [9:0] v_count = 0;

    // Generate 25MHz pixel clock from 48MHz input clock
    reg [1:0] clk_divider = 0;
    wire pixel_clk = clk_divider[0];
    always @(posedge clk48) begin
        clk_divider <= clk_divider + 1;
    end

    // Horizontal and vertical counters
    always @(posedge pixel_clk) begin
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

    // Generate checkerboard pattern
    wire display_active = (h_count < H_DISPLAY) && (v_count < V_DISPLAY);
    wire [4:0] grid_x = h_count[5:1];  // Divide horizontal count by 32
    wire [4:0] grid_y = v_count[5:1];  // Divide vertical count by 32
    wire checker = grid_x[0] ^ grid_y[0];

    // Assign color outputs
    assign gpio_a0 = display_active && checker; // Red
    assign gpio_a1 = display_active && checker; // Green
    assign gpio_a2 = display_active && checker; // Blue

endmodule
