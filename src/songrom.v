`default_nettype none

module notetbl (
  input wire [2:0] note,
  output wire [7:0] inc
);

  reg [7:0] rom[0:7];
  initial begin
    $readmemh("../data/notetbl.hex", rom);
  end
  assign inc = rom[note];

endmodule

module songtriggers (
  input wire [7:0] songpos,
  output wire kick,
  output wire snare,
  output wire pulse
);

  reg kickrom[0:127];
  reg snarerom[0:127];
  reg pulsemaskrom[0:255];
  initial begin
    $readmemh("../data/kick.hex", kickrom);
    $readmemh("../data/snare.hex", snarerom);
    $readmemh("../data/pulsemask.hex", pulsemaskrom);
  end
  assign kick = kickrom[songpos[6:0]];
  assign snare = snarerom[songpos[6:0]];
  assign pulse = pulsemaskrom[songpos[7:0]];

endmodule

module bassline (
  input wire [7:0] songpos,
  output wire [2:0] note,
  output wire [0:0] octave
);

  reg [2:0] noterom[0:31];
  reg octrom[0:31];
  initial begin
    $readmemh("../data/bassline.hex", noterom);
    $readmemh("../data/bassoct.hex", octrom);
  end
  assign note = noterom[songpos[5:1]];
  assign octave = octrom[songpos[5:1]];
endmodule

module pulsetrack (
  input wire [7:0] songpos,
  input wire arpidx, // 0 or 1 for arpeggios, alternates every 4 frames
  output wire [2:0] note,
  output wire octave
);

  reg [2:0] pulse1rom[0:255];
  reg [2:0] pulse2rom[0:255];
  reg pulseoctrom[0:255];
  initial begin
    $readmemh("../data/pulse1.hex", pulse1rom);
    $readmemh("../data/pulse2.hex", pulse2rom);
    $readmemh("../data/pulseoct.hex", pulseoctrom);
  end

  assign note = arpidx ? pulse2rom[songpos[7:0]] : pulse1rom[songpos[7:0]];
  assign octave = pulseoctrom[songpos[7:0]];

endmodule
