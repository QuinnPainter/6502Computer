import sys

if (len(sys.argv) < 3):
    print("Need source and destination files!")
    sys.exit()
    
with open(sys.argv[1], "rb") as f:
    asm = f.read()
    
writeString = "#include \"Arduino.h\"\nconst uint8_t toWrite[] PROGMEM = {"

for b in asm:
    writeString += hex(b) + ","

# remove trailing comma
writeString = writeString[:-1]

writeString += "};"

with open(sys.argv[2], "w") as outputFile:
    outputFile.write(writeString)