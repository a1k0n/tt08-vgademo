module audiotrack (
  input clk48,
  input rst_n,
  output [2:0] kick_frames_out,
  output [3:0] snare_frames_out,
  output [7:0] songpos_out,
  output [15:0] audio_sample,
  output reg out);

reg [14:0] noise_lfsr;
reg [3:0] noise_vol;
assign snare_frames_out = noise_vol;
//wire [15:0] noise_mask = 16'hffff >> noise_vol;
//wire [15:0] noise_output = {2'b0, noise_lfsr[13:0] & noise_mask[13:0]};
wire signed [15:0] noise_output = {3'b0, noise_lfsr[12:0]} >>> noise_vol;

reg [13:0] pulse_osc_p;
reg [3:0] pulse_vol;
wire pulse_octave;
// either 1100... or 0100.. (positive or negative)
// which means the shift has to do sign extension
wire signed [15:0] pulse_output = {pulse_octave ? pulse_osc_p[12] : pulse_osc_p[13], 1'h1, 14'h0} >>> (2+pulse_vol);

// triangle oscillator, which is fed by kick drum and bassline via mux
reg [15:0] tri_osc_p;  // oscillator position
reg [8:0] tri_osc_i;  // oscillator increment for kick drum and bass

// kick drum
reg [2:0] kick_frames;
assign kick_frames_out = kick_frames;

wire [8:0] bassline_inc;

//reg signed [15:0] kick_y1;  // IIR filter state
// derive triangle wave from oscillator position
wire signed [15:0] tri_output = ((tri_osc_p ^ {16{tri_osc_p[15]}}) - 16384) >>> 1;

// clock divisor
// 1024 clocks per sample
reg [9:0] sample_div;
// 256 samples per tick
reg [7:0] tick_div;
// ~20 ticks per beat (actually varies due to swing, either 15 or 25)
reg [4:0] beat_div;
// 256 beats for the whole song
reg [7:0] songpos;
assign songpos_out = songpos;

wire [10:0] sample_div_ = sample_div + 1;
wire [8:0] tick_div_ = tick_div + 1;

// swing the beat
wire [4:0] ticks_per_beat = songpos[0] ? 18+5 : 18-5;

reg [15:0] sigma_delta_accum;
// convert signed 16-bit -32768..32768 to unsigned 16-bit 0..65535
//wire [15:0] audio_sample = (snare_out + kick_out) ^ 16'h8000;
assign audio_sample = (tri_output + noise_output + pulse_output) ^ 16'h8000;
//assign audio_sample = (tri_output + noise_output) ^ 16'h8000;
//assign audio_sample = tri_output ^ 16'h8000;

wire [16:0] sigma_delta_accum_ = sigma_delta_accum + audio_sample;

wire [7:0] songpos_next = songpos + 1;

// load the triggers one step ahead, because we're going to latch the volumes of
// each channel but the actual bass and pulse notes are purely combinatorial
wire trigger_kick;
wire trigger_snare;
wire trigger_pulse;
songtriggers triggers (
  .songpos(songpos_next),
  .kick(trigger_kick),
  .snare(trigger_snare),
  .pulse(trigger_pulse)
);

wire [2:0] bassnote;
wire [7:0] bassnote_inc;
wire bassoct;
bassline bassline (
  .songpos(songpos),
  .note(bassnote),
  .octave(bassoct)
);

notetbl bassnote_tbl (
  .note(bassnote),
  .inc(bassnote_inc)
);

assign bassline_inc = bassnote_inc << bassoct;

wire [2:0] pulse_note;
wire pulse_trigger;
wire [7:0] pulse_osc_i;
pulsetrack pulsetrack (
  .songpos(songpos),
  .arpidx(beat_div[2]),
  .note(pulse_note),
  .octave(pulse_octave)
);

notetbl pulse_note_tbl (
  .note(pulse_note),
  .inc(pulse_osc_i)
);

task step_beat;
  begin
    songpos <= songpos_next;
    if (trigger_kick) begin
      tri_osc_i <= 9'h1c0;
      kick_frames <= 7;
    end
    if (trigger_snare) begin
      noise_vol <= 0;
    end
    if (trigger_pulse) begin
      pulse_vol <= 0;
    end
  end
endtask

task step_tick;
  begin
    if (beat_div == 0) begin
      step_beat;
      beat_div <= ~ticks_per_beat;
    end else begin
      beat_div <= beat_div + 1;
      if (kick_frames > 0) begin
        kick_frames <= kick_frames - 1;
        tri_osc_i <= tri_osc_i - (tri_osc_i >> 3);
        //$display("kick_frames=%d tri_osc_i=%d", kick_frames, tri_osc_i);
      end else begin
        tri_osc_i <= bassline_inc;
      end
      if (beat_div[1:0] == 3) begin
        noise_vol <= noise_vol == 15 ? 15 : noise_vol + 1;
      end
      if (beat_div[2:0] == 7) begin
        pulse_vol <= pulse_vol == 15 ? 15 : pulse_vol + 1;
      end
    end
  end
endtask

task gen_sample;
  begin
    tick_div <= tick_div_[7:0];
    if (tick_div_[8] == 1) begin  // on carry-out, increment beat_div
      step_tick;
    end
    noise_lfsr <= {noise_lfsr[0], noise_lfsr[0] ^ noise_lfsr[14], noise_lfsr[13:1]};
    tri_osc_p <= tri_osc_p + {6'b0, tri_osc_i};
    pulse_osc_p <= pulse_osc_p + {4'b0, pulse_osc_i};
  end
endtask

always @(posedge clk48 or negedge rst_n) begin
  if (~rst_n) begin
    sigma_delta_accum <= 0;
    noise_lfsr <= 15'h1CAF;
    noise_vol <= 15;
    pulse_vol <= 15;
    kick_frames <= 3'b0;
    tri_osc_i <= 9'b0;

    sample_div <= 10'b0;
    tick_div <= 8'b0;
    beat_div <= 5'b0;
    songpos <= 8'hFF;

  end else begin
    if (sample_div_[10] == 1) begin  // on carry-out, increment tick_div
      gen_sample;
    end
    sample_div <= sample_div_[9:0];
    sigma_delta_accum <= sigma_delta_accum_[15:0];
    out <= sigma_delta_accum_[16];
  end
end

endmodule
