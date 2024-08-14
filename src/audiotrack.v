module audiotrack (
  input clk48,
  input rst_n,
  output [15:0] audio_sample,
  output reg out);

reg [15:0] noise_lfsr;

reg [15:0] snare_env;
reg signed [15:0] snare_y1;  // IIR filter state
wire [13:0] snare_x = snare_env[15:2] & noise_lfsr[13:0];
wire signed [15:0] snare_dry = {{2{snare_x[13]}}, snare_x};
wire signed [15:0] snare_out = snare_dry - snare_y1;
wire signed [15:0] snare_y1_ = snare_dry + (snare_out>>>1);

reg [13:0] kick_osci;  // oscillator increment
reg [20:0] kick_oscp;  // oscillator position
reg signed [15:0] kick_y1;  // IIR filter state
// derive triangle wave from oscillator position
wire signed [15:0] kick_tri = (kick_oscp[20:5] ^ {16{kick_oscp[20]}}) - 16384;
// high-pass filter the triangle for the final output
wire signed [15:0] kick_out = kick_tri + kick_y1;
wire signed [15:0] kick_y1_ = kick_out - (kick_out>>>8) - kick_tri;

/*
reg signed [15:0] cos, sin;
wire signed [15:0] cos1 = cos - (sin >>> 4);
wire signed [15:0] sin1 = sin + (cos1 >>> 4);
*/
// clock divisor
// first 10 bits: nominal output samplerate is 48MHz / 1024
// next 14 bits: count out 16k samples per beat
reg [31:0] clock_div;
wire [9:0] sample_div = clock_div[9:0];
wire [13:0] beat_div = clock_div[23:10];
wire [7:0] beat = clock_div[31:24];

reg [15:0] sigma_delta_accum;
// convert signed 16-bit -32768..32768 to unsigned 16-bit 0..65535
//wire [15:0] audio_sample = (snare_out + kick_out) ^ 16'h8000;
assign audio_sample = (snare_out + kick_out) ^ 16'h8000;

wire [16:0] sigma_delta_accum_ = sigma_delta_accum + audio_sample;

always @(posedge clk48) begin
  if (~rst_n) begin
    //cos <= 16384;
    //sin <= 0;
    clock_div <= 0;
    sigma_delta_accum <= 0;
    kick_osci <= 0;
    kick_oscp <= 0;
    kick_y1 <= 0;
    noise_lfsr <= 16'h1CAF;
    snare_env <= 0;
    snare_y1 <= 0;
  end else begin
    if (sample_div == 10'b0) begin
      //cos <= cos1;
      //sin <= sin1;
      noise_lfsr <= noise_lfsr[15] ? (noise_lfsr<<1) ^ 16'h8016 : noise_lfsr<<1;
      if (beat_div == 14'b0) begin
        if (beat[1:0] == 0) begin
          kick_osci <= 14'h3fff;
          kick_oscp <= 0;
          kick_y1 <= 0;
        end else if (beat[1:0] == 2) begin
          snare_env <= 16'hffff;
          snare_y1 <= 0;
        end
        // kick_oscp <= 0;
      end else begin
        kick_oscp <= kick_oscp + {7'b0, kick_osci};
        kick_osci <= kick_osci - ((kick_osci+2047) >> 11);
        kick_y1 <= kick_y1_;

        snare_env <= snare_env - ((snare_env+4095) >> 12);
        snare_y1 <= snare_y1_;
      end
    end
    clock_div <= clock_div + 1;
    sigma_delta_accum <= sigma_delta_accum_[15:0];
    out <= sigma_delta_accum_[16];
  end
end

endmodule
