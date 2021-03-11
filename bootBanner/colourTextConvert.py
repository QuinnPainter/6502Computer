# Converts a PNG image to a set of graphics commands to print that
# image on screen in text mode.
# Make sure the image is saved in 24 bit colour.

import sys
from PIL import Image

# Colour definitions
# may want to add "bright" colours later
# in order = Black, Red, Green, Yellow, Blue, Magenta, Cyan, White
colourTable = [(0, 0, 0), (255, 0, 0), (76, 255, 0), (255, 216, 0), (0, 38, 255), (178, 0, 255), (0, 255, 255), (255, 255, 255)]
drawCharacterCode = 219 # Character to draw the image with. 219 = filled in block

im = Image.open(sys.argv[1])
imArray = list(im.getdata())
outputArray = []
prevColour = None
for c in imArray:
    colourIndex = None
    for i in range(len(colourTable)):
        if (colourTable[i] == c):
            colourIndex = i
            break
    if (colourIndex == None):
        print("Unknown colour: " + str(c))
    if not colourIndex == prevColour:
        if not prevColour == None:
            outputArray.append(0) # terminate previous string
        outputArray.append(4) # Change Foreground Colour
        outputArray.append(colourIndex)
        outputArray.append(2) # start new string
    outputArray.append(drawCharacterCode)
    prevColour = colourIndex
outputArray.append(0) # terminate final string
outputByteArray = bytearray(outputArray)
outputFile = open(sys.argv[1].replace(".png", ".bin"), "wb")
outputFile.write(outputByteArray)
outputFile.close()