module serial_divider #(
    parameter DIVIDEND_WIDTH = 16,
    parameter DIVISOR_WIDTH = 8
)(
    input wire clk,
    input wire rst,
    input wire start,
    input wire [DIVIDEND_WIDTH-1:0] dividend,
    input wire [DIVISOR_WIDTH-1:0] divisor,
    output reg [DIVISOR_WIDTH-1:0] quotient,
    output reg done
);

localparam QUOTIENT_WIDTH = DIVISOR_WIDTH;

reg [DIVIDEND_WIDTH-1:0] dividend_reg;
reg [DIVISOR_WIDTH-1:0] divisor_reg;
reg [DIVISOR_WIDTH-1:0] sub_result;
reg [DIVISOR_WIDTH-1:0] remainder;
reg [$clog2(DIVIDEND_WIDTH+1)-1:0] count;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        dividend_reg <= 0;
        divisor_reg <= 0;
        quotient <= 0;
        remainder <= 0;
        count <= 0;
        done <= 0;
    end else if (start) begin
        dividend_reg <= dividend;
        divisor_reg <= divisor;
        quotient <= 0;
        remainder <= 0;
        count <= DIVIDEND_WIDTH;
        done <= 0;
    end else if (count > 0) begin
        sub_result = remainder - divisor_reg;
        if (sub_result[DIVISOR_WIDTH-1] == 0) begin
            remainder <= sub_result;
            quotient <= {quotient[QUOTIENT_WIDTH-2:0], 1'b1};
        end else begin
            quotient <= {quotient[QUOTIENT_WIDTH-2:0], 1'b0};
        end
        remainder <= {remainder[DIVISOR_WIDTH-2:0], dividend_reg[DIVIDEND_WIDTH-1]};
        dividend_reg <= {dividend_reg[DIVIDEND_WIDTH-2:0], 1'b0};
        count <= count - 1;
    end else if (count == 0) begin
        done <= 1;
    end
end

endmodule

