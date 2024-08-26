import numpy as np
import sounddevice as sd

snareA = '..x...x...x...x.'
kickA  = 'x...x...x...x...'

snareB = '..x...x...x...x.'
kickB  = 'x...x..x.x..x...'

snareC = '..x...x...x..xxx'
kickC  = 'x...x..xx...x...'

snareD = '..x...x...x...xx'
kickD  = '................'

songperiod = 128

snare = snareA + snareB + snareA + snareC + snareA + snareB + snareA + snareD
kick = kickA + kickB + kickA + kickC + kickA + kickB + kickA + kickD

bass_chart_notes = 'AAAAAAAGFFFFFFFBCCCCCCCDEEEEEEEG'
bass_chart_octs  = '00110010001100100011010100110100'

#            1e+a2e+a3e+a4e+a1e+a2e+a3e+a4e+a1e+a2e+a3e+a4e+a1e+a2e+a3e+a4e+a1e+a2e+a3e+a4e+a1e+a2e+a3e+a4e+a1e+a2e+a3e+a4e+a1e+a2e+a3e+a4e+a
#pulsAnote ='A....AB.C.DE..G.F.....A.D..G..F.E...ECA....GABCDB....CD.B.G.G...................................................................'
pulsAnote = 'A...EAB.C.DEE.G.F...A.A.D..GA.F.E...ECA....GABCDB...ECD.B.G.G...E.E.A..A..E..EEEF.F.A..AA..F..FFE.E.E..G..E..GEEE.E..G..GE..GG.G'
pulsAoct  = '00001000000010010011111111111111111111110100111111111111110001111110010111101121111001011110111111101011100101211110010012111102'
pulsAarp  = 'AAAACABBCCDECDGCFBCCC.ACDCCGCFFCECCCGCACCCCGGBCDBECCBCDBBBGGEBBBCCCCCCCCCCCCCAAACCCCCCCCCCCAxxACCCCCCCCCCCCCCCGGBBBBBBBBBGGGBBBE'

#pulsAnote ='A...E...A...E...F...A...F...A...C...E...C...E...E...E...G...E...E.E.A..A..E..EEEF.F.A..AA..F..FFE.E.E..G..E..GEEE.E..G..GE..GG.G'
#pulsAoct  ='01111111011111110111111101111111011111110111111101111111011111111110010111101121111001011110111111101011100101211110010012111102'
#pulsAarp  ='ACCCCCCCACCCCCCCFCCCCCCCFCCCCCCCCCCCGCCCCCCCGCCCECCCBBBBGBBBBBBBCCCCCCCCCCCCCAAACCCCCCCCCCCAxxACCCCCCCCCCCCCCCGGBBBBBBBBBGGGBBBE'

samples_per_tick = 256
bpm = 120
# samplerate = 48MHz / 1024 = 46.875kHz
# beat rate = 48MHz/1024/512 = ~91.55Hz
# we have four actual "sub-beats" per "beat" in terms of BPM
# so we have 4*BPM/60 sub-beats per second
# so beat rate is 48MHz * 60 / (1024*512*4*BPM)
ticks_per_beat = round(48e6 * 60 / (1024*samples_per_tick*4*bpm))
actualbpm = 48e6 * 60 / (1024*samples_per_tick*4 * ticks_per_beat)
print("ticks_per_beat =", ticks_per_beat, "actual bpm", actualbpm)

# find increment for 16bit tri reg bass @ A440
# freq = inc * 48MHz/(1024 * 65536)
# inc = freq * 1024 * 65536 / 48e6

def freqinc(freq):
    return round(freq * 1024 * 65536 / 48e6)

def noteinc(noteidx):
    freq = 55 * 2**(noteidx/12)
    return freqinc(freq)

def tri(x):
    return ((x&65535) ^ (x&32768 and -1 or 0) & 65535) - 16384

class audiogen:
    def __init__(self):
        self.tickcount = samples_per_tick-1
        self.tri_osc_p = 0
        self.tri_osc_i = 0
        self.puls_osc_p = 0
        self.puls_osc_i = 0
        self.puls_osc_i1 = 0
        self.puls_osc_i2 = 0
        self.puls_vol = 0
        self.beatcount = ticks_per_beat-1
        self.songpos = 0
        self.lfsr = 0x1caf
        self.lfsr_vol = 16
        self.tri_decay = 0
        self.bass_inc = 0

    # Assume we have a function that generates or reads our audio data
    def get_next_audio_chunk(self, frame_count):
        out = np.zeros(frame_count, np.float32)
        t = self.tickcount
        for i in range(frame_count):
            o = (tri(self.tri_osc_p) + (self.lfsr >> self.lfsr_vol)) >> 1
            o += ((self.puls_osc_p&32768) - 16384) >> (self.puls_vol+1)
            out[i] = o
            self.tri_osc_p = (self.tri_osc_p + max(self.tri_osc_i,  self.bass_inc))&65535
            self.puls_osc_p = (self.puls_osc_p + self.puls_osc_i) & 65535
            self.lfsr = self.lfsr&0x8000 and ((self.lfsr<<1)^0x8016) or (self.lfsr<<1)
            self.lfsr &= 0xffff

            t += 1
            if t == samples_per_tick:
                self.tick()
                t = 0

        self.tickcount = t
        return out
    
    def tick(self):
        self.puls_osc_i = self.beatcount&4 and self.puls_osc_i2 or self.puls_osc_i1
        self.beatcount += 1
        if self.tri_decay:
            self.tri_osc_i -= (self.tri_osc_i+7)>>3
        if self.beatcount == ticks_per_beat:
            self.beat()
            self.beatcount = 0
        if (self.beatcount&3 == 0) and self.lfsr_vol < 16:
            self.lfsr_vol += 1
        if (self.beatcount&7 == 0) and self.puls_vol < 16:
            self.puls_vol += 1

    def beat(self):
        if kick[self.songpos] == 'x':
            self.kick()
        if snare[self.songpos] == 'x':
            self.snare()

        p = (self.songpos//2) % len(bass_chart_notes)
        bassnote = bass_chart_notes[p]
        bassoct = ord(bass_chart_octs[p]) - ord('0')
        bassidx = 'A.BC.D.EF.G.'.index(bassnote[0])
        self.bass_inc = noteinc(bassidx + bassoct*12)

        p = (self.songpos) % len(pulsAnote)
        pulsnote = pulsAnote[p]
        if pulsnote != '.':
            pulsoct = ord(pulsAoct[p]) - ord('0')
            pulsidx = 'A.BC.D.EF.G.'.index(pulsnote)
            self.puls_osc_i1 = noteinc(pulsidx + (pulsoct+2)*12)
            pulsidx = 'A.BC.D.EF.G.'.index(pulsAarp[p])
            self.puls_osc_i2 = noteinc(pulsidx + (pulsoct+2)*12)
            self.puls_vol = 0
        #print("bass_inc", bassnote, bassidx + bassoct*12, self.bass_inc)
        self.songpos += 1
        self.songpos &= (songperiod-1)

    def kick(self):
        self.tri_osc_i = 0x1c0
        self.tri_decay = 1

    def snare(self):
        self.lfsr_vol = 1

gen = audiogen()

def audio_callback(outdata, frames, time, status):
    if status:
        print(status)
    outdata[:] = gen.get_next_audio_chunk(frames).reshape(-1, 1) * (1.0/32768.0)

# Set up the stream
sample_rate = 46875
channels = 1
blocksize = 2048  # Adjust this value based on your needs

stream = sd.OutputStream(
    samplerate=sample_rate,
    channels=channels,
    callback=audio_callback,
    blocksize=blocksize
)

# Start the stream
stream.start()

print(f"Actual sample rate: {stream.samplerate} Hz")


# Keep the stream running
input("Press Enter to stop the audio stream...")

# Stop the stream
stream.stop()
stream.close()
