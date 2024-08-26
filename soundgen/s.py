import numpy as np
import sounddevice as sd

snareA = '..x..xx...x..xx.'
kickA  = 'x...x...x...x...'

snareB = '..x...x..xx...x.'
kickB  = 'x...x..x.x..x...'

snareC = '..x...x...x..xxx'
kickC  = 'x...x..xx...x...'

snareD = '..x..xx...x...xx'
kickD  = '................'

songperiod = 256

snare = snareA + snareB + snareA + snareC + snareA + snareB + snareA + snareD
kick = kickA + kickB + kickA + kickC + kickA + kickB + kickA + kickD

#bass_chart_notes = 'AAAAAAAGFFFFFFFBCCCCCCCDEEEEEEEG'
#bass_chart_octs  = '00110010001100100011010100110100'

#                   1+2+3+4+1+2+3+4+1+2+3+4+1+2+3+4+
bass_chart_notes = 'AEAAAEAACCGCECCCDDD#D#DDFCFFGDGG'
bass_chart_octs  = '01100000000110100011010101100110'

#pulsAnote ='A....AB.C.DE..G.F.....A.D..G..F.E...ECA....GABCDB....CD.B.G.G...................................................................'
#pulsAnote = 'A...EAB.C.DEE.G.F...A.A.D..GA.F.E...ECA....GABCDB...ECD.B.G.G...E.E.A..A..E..EEEF.F.A..AA..F..FFE.E.E..G..E..GEEE.E..G..GE..GG.G'
#pulsAoct  = '00001000000010010011111111111111111111110100111111111111110001111110010111101121111001011110111111101011100101211110010012111102'
#pulsAarp  = 'AAAACABBCCDECDGCFBCCC.ACDCCGCFFCECCCGCACCCCGGBCDBECCBCDBBBGGEBBBCCCCCCCCCCCCCAAACCCCCCCCCCCAxxACCCCCCCCCCCCCCCGGBBBBBBBBBGGGBBBE'

#            1e+a2e+a3e+a4e+a1e+a2e+a3e+a4e+a1e+a2e+a3e+a4e+a1e+a2e+a3e+a4e+a1e+a2e+a3e+a4e+a1e+a2e+a3e+a4e+a1e+a2e+a3e+a4e+a1e+a2e+a3e+a4e+a
pulsAnot = 'A...A.....A...A.G...G.....G...G.#...#.....#...#.F...F...G...G...'
pulsAoct = '0000000000000000000000000000000000000000000000000000000000000000'
pulsAarp = 'EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEAAAAAAAAAAAAAAAAAAAAAAAABBBBBBBB'

pulsBnot = 'C...C.....A...C.G...C....CG...GG##..#.....#...#FFF..FF.FGG..GG..'
pulsBoct = '1000100000000000000000000100000001000000000000000100010101000100'
pulsBarp = 'EEEEEEEEEEEEEEEEEEEEGEEEEGCEEEECAAAAAAAAAAAAAAACACAAAAAABDBBBDBB'

pulsCnot = 'CCA.CAA..ACACCCAGGCCGCGE..GGG.GG#DD###.#.D###.#DFF.FF.CFGG.GG.GD'
pulsCoct = '0000011001100100001000100001001000100100001010011001000001001001'
pulsCarp = 'EEEEAEEEEEEEAAECEEEECEECEEEECECEAAADADAAAAADDAAAAACCAAFABBBBDBBB'

puls_chart_note = pulsAnot + pulsBnot + pulsAnot + pulsCnot
puls_chart_oct =  pulsAoct + pulsBoct + pulsAoct + pulsCoct
puls_chart_arp =  pulsAarp + pulsBarp + pulsAarp + pulsCarp

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
    freq = 55 * 2**((noteidx+3)/12)
    return freqinc(freq)

def letterinc(name, octave):
    idx = 'C.D.EF#G.A.B'.index(name)
    return noteinc(idx + 12*(ord(octave) - ord('0')))

def tri(x):
    return ((x&65535) ^ (x&32768 and -1 or 0) & 65535) - 16384

def saw(x):
    return ((x&65535) - 32768) >> 1

def dumpnotetbl(tables):
    ''' find all unique notes in bass_chart_notes and puls_chart_note, calc inc for oct 0 '''
    notes = set()
    for t in tables:
        for n in t:
            notes.add(n)
    incs = [(letterinc(n, '0'), n) for n in notes]
    incs = sorted(incs)
    hexout = []
    for inc, n in incs:
        if n == '.':
            continue
        print(f'"{n}": {hex(inc)}')
        hexout.append("%02x" % inc)
    print("data:", ' '.join(hexout))


def notehex(notelist, masktrack):
    notes = []
    mask = []
    for i in range(len(masktrack)):
        if masktrack[i] == '.':
            notes.append('x')
            mask.append('0')
        else:
            notes.append(str('CDEF#GAB'.index(notelist[i])))
            mask.append('1')
    return ' '.join(notes), ' '.join(mask)

def numhex(notelist, masktrack):
    nums = []
    for i in range(len(masktrack)):
        if masktrack[i] == '.':
            nums.append('x')
        else:
            nums.append(str(notelist[i]))
    return ' '.join(nums)


def dumptracks():
    notes, mask = notehex(puls_chart_note, puls_chart_note)
    note2, _ = notehex(puls_chart_arp, puls_chart_note)
    octs = numhex(puls_chart_oct, puls_chart_note)
    print("pulsmask: ", mask)
    print("pulsfreq1:", notes)
    print("pulsfreq2:", note2)
    print("pulsoct:  ", octs)

    bass, _ = notehex(bass_chart_notes, bass_chart_notes)
    bassoct = numhex(bass_chart_octs, bass_chart_notes)
    print("bassfreq: ", bass)
    print("bassoct:  ", bassoct)

    print("kick:  ", ' '.join([x == 'x' and '1' or '0' for x in kick]))
    print("snare: ", ' '.join([x == 'x' and '1' or '0' for x in snare]))

class audiogen:
    def __init__(self):
        self.tickcount = 0
        self.tri_osc_p = 0
        self.tri_osc_i = 0
        self.puls_osc_p = 0
        self.puls_osc_i = 0
        self.puls_osc_i1 = 0
        self.puls_osc_i2 = 0
        self.puls_vol = 0
        self.beatcount = 0
        self.songpos = 0
        self.lfsr = 0x1caf
        self.lfsr_vol = 16
        self.bass_inc = 0
        self.kick_frames = 0

    # Assume we have a function that generates or reads our audio data
    def get_next_audio_chunk(self, frame_count):
        out = np.zeros(frame_count, np.float32)
        t = self.tickcount
        for i in range(frame_count):
            o = (tri(self.tri_osc_p) + (self.lfsr >> self.lfsr_vol)) >> 1
            o += (((self.puls_osc_p&8192) - 4096) << 1) >> self.puls_vol
            out[i] = o
            self.tri_osc_p = (self.tri_osc_p + self.tri_osc_i) & 65535
            self.puls_osc_p = (self.puls_osc_p + self.puls_osc_i) & 16383
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
        if self.kick_frames > 0:
            self.tri_osc_i -= (self.tri_osc_i+7) >> 3
            self.kick_frames -= 1
        else:
            self.tri_osc_i = self.bass_inc
        # add swing
        tb = ticks_per_beat - 5 + 10*(self.songpos&1)
        #tb = ticks_per_beat
        if self.beatcount >= tb:
            self.beat()
            self.beatcount = 0
        if (self.beatcount&3 == 0) and self.lfsr_vol < 16:
            self.lfsr_vol += 1
        if (self.beatcount&7 == 0) and self.puls_vol < 16:
            self.puls_vol += 1

    def beat(self):
        perc_mask = len(kick)-1
        if kick[self.songpos & perc_mask] == 'x':
            self.kick()
        if snare[self.songpos & perc_mask] == 'x':
            self.snare()

        p = (self.songpos//2) % len(bass_chart_notes)
        self.bass_inc = letterinc(bass_chart_notes[p], bass_chart_octs[p])

        p = (self.songpos) % len(puls_chart_note)
        pulsnote = puls_chart_note[p]
        if pulsnote != '.':
            self.puls_osc_i1 = letterinc(pulsnote, puls_chart_oct[p])
            self.puls_osc_i2 = letterinc(puls_chart_arp[p], puls_chart_oct[p])
            self.puls_vol = 0
        # print("bass_inc", bassnote, bassidx + bassoct*12, self.bass_inc, "puls", self.puls_osc_i1, self.puls_osc_i2)
        self.songpos += 1
        self.songpos &= (songperiod-1)

    def kick(self):
        self.tri_osc_i = 0x1c0
        self.kick_frames = 7

    def snare(self):
        self.lfsr_vol = 1


gen = audiogen()
def audio_callback(outdata, frames, time, status):
    if status:
        print(status)
    outdata[:] = gen.get_next_audio_chunk(frames).reshape(-1, 1) * (1.0/32768.0)


def main():
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

if __name__ == '__main__':
    #dumpnotetbl([bass_chart_notes])
    dumpnotetbl([bass_chart_notes, puls_chart_note, puls_chart_arp])
    dumptracks()
    main()
