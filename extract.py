import sys
from collections import defaultdict
from PIL import Image
import numpy as np


def extract_colormap_info(image_path):
    # Open the image
    with Image.open(image_path) as img:
        # Ensure the image is in 'P' mode (palette mode)
        if img.mode != 'P':
            raise ValueError("Image is not in palette mode")

        # Get the palette
        palette = img.getpalette()

        # Convert palette to RGB tuples
        palette_rgb = [tuple(palette[i:i+3]) for i in range(0, len(palette), 3)]

        # Get the colormap indices
        colormap_indices = np.array(img)

    return colormap_indices, palette_rgb

# Usage
image_path = '32X32-FI.png'
indices, palette = extract_colormap_info(image_path)


def tohash(row):
    state = 0
    out = []
    for px in row:
        if px == state:
            out.append('7')
        else:
            out.append(str(px))
            state = px
    return ''.join(out)

rowhist = defaultdict(int)
for i in range(10):
    for j in range(192):
        row = indices[j, i*32:(i+1)*32]
        rowhist[tohash(row)] += 1

print("unique rows:", len(rowhist))
# find most frequent rows
sorted_rowhist = sorted(rowhist.items(), key=lambda x: x[1], reverse=True)
for i in range(20):
    print("row", i, sorted_rowhist[i])

hist = np.zeros(len(palette), dtype=int)
# re-extract the numeric indices from the row histogram and find the deduplicated palette histogram
for rowhash, count in rowhist.items():
    row = [int(x) for x in rowhash]
    for x in row:
        hist[x] += 1
sumhist = sum(hist)
print("palette histogram", [hex(x) for x in hist], hex(sumhist), "binary entropy",
       (np.log(sumhist) - np.log(hist))/np.log(2),
       sum(hist*(np.log(sumhist) - np.log(hist))/np.log(2)))
scaled = np.cumsum(hist) * 256 // sumhist
print("rescaled cumulative", [hex(x) for x in scaled])
print("rescaled frequency ", hex(scaled[0]), [hex(x) for x in np.diff(scaled)])

print("Palette R:", ''.join(["%02x " % (r>>2) for r,g,b in palette]))
print("Palette G:", ''.join(["%02x " % (g>>2) for r,g,b in palette]))
print("Palette B:", ''.join(["%02x " % (b>>2) for r,g,b in palette]))


def getletter(asciicode):
    x = 32*((asciicode - 32) % 10)
    y = 32*((asciicode - 32) // 10)
    print(asciicode, x, y)
    return indices[y:y+32, x:x+32]


def printletter(asciicode):
    letter = getletter(asciicode)
    for row in letter:
        print(' '.join([str(x) for x in row]))


letter = 'A'
if len(sys.argv) > 1:
    letter = sys.argv[1][0]

printletter(ord(letter))
