//changed optimisation level from -Os to -O3 in AppData\Local\Arduino15\packages\esp32\hardware\esp32\1.0.4\platform.txt
#include "fabgl.h"
//changed max text rows from 25 in terminal.cpp in fabgl. just so ya know.

#define RED_0_PIN GPIO_NUM_32
#define RED_1_PIN GPIO_NUM_33
#define GREEN_0_PIN GPIO_NUM_25
#define GREEN_1_PIN GPIO_NUM_26
#define BLUE_0_PIN GPIO_NUM_27
#define BLUE_1_PIN GPIO_NUM_14
#define HSYNC_PIN GPIO_NUM_12
#define VSYNC_PIN GPIO_NUM_13

//#define DATA_CLK_PIN GPIO_NUM_23
#define DATA_CLK_PIN GPIO_NUM_34
#define INTERRUPT_OUT_PIN GPIO_NUM_22

#define DATA_BUS_PIN_7 GPIO_NUM_15
#define DATA_BUS_PIN_6 GPIO_NUM_4
#define DATA_BUS_PIN_5 GPIO_NUM_16
#define DATA_BUS_PIN_4 GPIO_NUM_17
#define DATA_BUS_PIN_3 GPIO_NUM_5
#define DATA_BUS_PIN_2 GPIO_NUM_18
#define DATA_BUS_PIN_1 GPIO_NUM_19
#define DATA_BUS_PIN_0 GPIO_NUM_21

#define SOUND_CLOCK_OUT_PIN GPIO_NUM_0
#define SOUND_CLOCK_FREQ 1789772
#define SOUND_CLOCK_CHANNEL 4
#define SOUND_CLOCK_DUTY_RES 1 // was 8
#define SOUND_CLOCK_DUTY 1 // was 128 //8 bit resolution - 128 = 50% duty

#define CPU_CLOCK_OUT_PIN GPIO_NUM_23
#define CPU_CLOCK_FREQ 2000000
#define CPU_CLOCK_CHANNEL 5
#define CPU_CLOCK_DUTY_RES 1 // was 8
#define CPU_CLOCK_DUTY 1 // was 128 //8 bit resolution - 128 = 50% duty

struct Coord
{
  int x;
  int y;
};

enum class commandState
{
  noCommand, //no command in progress, start a new one
  sendChar, //waiting for the char for the "sendChar" command
  sendStrng, //printing 0 terminated string
  cursorPosX, //waiting for cursor X position
  cursorPosY, //waiting for cursor Y position
  textForeground, //waiting for text foreground colour
  textBackground, //waiting for text background colour
  graphics, //one of the graphics commands
  bitmapData, //currently drawing bitmap
  spriteBitmapData, //currently receiving sprite bitmap
  makeSpriteVisible, // waiting for a sprite index to turn visible / invisible
  makeSpriteInvisible,
};

enum class gfxDrawMode
{
  point,
  line,
  rect,
  fillrect,
  bitmap,
  spriteGraphic,
  spriteMove
};

#define COLOUR 1
#define COORD 4
#define SPRITEINDEX 1
static uint8_t gfxCmdBytes[] = {
  COLOUR + COORD, //point
  COLOUR + COORD + COORD, //line
  COLOUR + COORD + COORD, //rect
  COLOUR + COORD + COORD, //filled rect
  COORD + COORD, //bitmap
  SPRITEINDEX + COORD, // sprite graphic
  SPRITEINDEX + COORD // sprite move
};
#undef COLOUR
#undef COORD
#undef SPRITEINDEX

fabgl::VGAController vgaController;
fabgl::Terminal      terminal;
//fabgl::Canvas        canvas(&vgaController);

volatile uint8_t pendingData = 0;
volatile bool dataPending = false;
commandState cmdState = commandState::noCommand;
gfxDrawMode drawMode = gfxDrawMode::point;
uint8_t currentGfxCmdByte = 0;
uint8_t gfxCmdBuffer[10];
Sprite sprites[256];
Bitmap spriteBitmaps[256];

uint8_t tempCursorX = 0; //used by "set cursor position" command
Coord bitmapPos;
Coord bitmapDim;
Coord currentBitmapPos;
uint8_t currentSpriteIndex = 0; // used for setting sprite graphic
uint8_t* spriteBitmapBuffer = NULL;

void IRAM_ATTR dataInterrupt()
{
  if (dataPending)
  {
    //We already have data queued. The host device needs to slow down!
    return;
  }
  pendingData = digitalRead(DATA_BUS_PIN_0) |
                digitalRead(DATA_BUS_PIN_1) << 1 |
                digitalRead(DATA_BUS_PIN_2) << 2 |
                digitalRead(DATA_BUS_PIN_3) << 3 |
                digitalRead(DATA_BUS_PIN_4) << 4 |
                digitalRead(DATA_BUS_PIN_5) << 5 |
                digitalRead(DATA_BUS_PIN_6) << 6 |
                digitalRead(DATA_BUS_PIN_7) << 7;
  dataPending = true;
}

void setup()
{
  pinMode(DATA_BUS_PIN_0, INPUT);
  pinMode(DATA_BUS_PIN_1, INPUT);
  pinMode(DATA_BUS_PIN_2, INPUT);
  pinMode(DATA_BUS_PIN_3, INPUT);
  pinMode(DATA_BUS_PIN_4, INPUT);
  pinMode(DATA_BUS_PIN_5, INPUT);
  pinMode(DATA_BUS_PIN_6, INPUT);
  pinMode(DATA_BUS_PIN_7, INPUT);
  pinMode(DATA_CLK_PIN, INPUT);
  pinMode(INTERRUPT_OUT_PIN, OUTPUT);
  digitalWrite(INTERRUPT_OUT_PIN, HIGH);
  attachInterrupt(DATA_CLK_PIN, dataInterrupt, FALLING);
  vgaController.begin(RED_1_PIN, RED_0_PIN, GREEN_1_PIN, GREEN_0_PIN, BLUE_1_PIN, BLUE_0_PIN, HSYNC_PIN, VSYNC_PIN);
  //vgaController.setResolution(VGA_512x384_60Hz, -1, -1);
  //vgaController.setResolution("\"640x400_60.00\" 19.52 640 648 712 784 400 401 404 415 -HSync +Vsync", -1, -1);
  vgaController.setResolution(VGA_400x300_60Hz, -1, -1);
  //vgaController.setResolution(QVGA_320x240_60Hz, -1, -1);

  terminal.begin(&vgaController);
  terminal.enableCursor(true);
  terminal.loadFont(&fabgl::FONT_8x8);
  //terminal.loadFont(&fabgl::FONT_9x15);
  terminal.clear(); //fix screwey cursor

  for (int i = 0; i < 256; i++)
  {
    sprites[i].moveTo(0, 0);
    sprites[i].visible = false;
  }
  vgaController.setSprites(sprites, 256);

  // Task has priority of 50, so should be faster than loop()
  //TaskHandle_t loopTask;
  //xTaskCreate(newLoop, "newLoopTask", 10000, NULL, 50, &loopTask);

  Serial.begin(9600);

  ledcSetup(SOUND_CLOCK_CHANNEL, SOUND_CLOCK_FREQ, SOUND_CLOCK_DUTY_RES);
  ledcAttachPin(SOUND_CLOCK_OUT_PIN, SOUND_CLOCK_CHANNEL);
  ledcWrite(SOUND_CLOCK_CHANNEL, SOUND_CLOCK_DUTY);

  ledcSetup(CPU_CLOCK_CHANNEL, CPU_CLOCK_FREQ, CPU_CLOCK_DUTY_RES);
  ledcAttachPin(CPU_CLOCK_OUT_PIN, CPU_CLOCK_CHANNEL);
  ledcWrite(CPU_CLOCK_CHANNEL, CPU_CLOCK_DUTY);
}

void loop()
{
  //while (true)
  {
  if (dataPending)
  {
    switch (cmdState)
    {
      case commandState::noCommand:
      {
        switch (pendingData)
        {
          case 0x00: // Clear Screen
            //terminal.clear();
            terminal.write("\e[;H"); //Move the cursor to the top left
            for (int y = 0; y < vgaController.getScreenHeight(); y++)
            {
              for (int x = 0; x < vgaController.getScreenWidth(); x++)
              {
                setPixel(x, y, {0, 0, 0});
              }
            }
            break;
          case 0x01: // Send Char
            cmdState = commandState::sendChar;
            break;
          case 0x02: // Send String
            cmdState = commandState::sendStrng;
            break;
          case 0x03: // Set Cursor Position
            cmdState = commandState::cursorPosX;
            break;
          case 0x04: // Set Text Foreground Colour
            cmdState = commandState::textForeground;
            break;
          case 0x05: // Set Text Background Colour
            cmdState = commandState::textBackground;
            break;
          case 0x06: // Enable Cursor
            terminal.enableCursor(true);
            break;
          case 0x07: // Disable Cursor
            terminal.enableCursor(false);
            break;
          case 0x20: // Draw Point
            cmdState = commandState::graphics;
            drawMode = gfxDrawMode::point;
            break;
          case 0x21: // Draw Line
            cmdState = commandState::graphics;
            drawMode = gfxDrawMode::line;
            break;
          case 0x22: // Draw Rect
            cmdState = commandState::graphics;
            drawMode = gfxDrawMode::rect;
            break;
          case 0x23: // Draw Filled Rect
            cmdState = commandState::graphics;
            drawMode = gfxDrawMode::fillrect;
            break;
          case 0x26: // Draw Bitmap
            cmdState = commandState::graphics;
            drawMode = gfxDrawMode::bitmap;
            break;
          case 0x27: // Update Sprite Graphic
            cmdState = commandState::graphics;
            drawMode = gfxDrawMode::spriteGraphic;
            break;
          case 0x28: // Move Sprite
            cmdState = commandState::graphics;
            drawMode ; gfxDrawMode::spriteMove;
            break;
          case 0x29: // Make Sprite Visible
            cmdState = commandState::makeSpriteVisible;
            break;
          case 0x2A: // Make Sprite Invisible
            cmdState = commandState::makeSpriteInvisible;
            break;
          case 0x2B: // Clear Sprites
            for (int i = 0; i < 256; i++)
            {
              sprites[i].moveTo(0, 0);
              sprites[i].visible = false;
              sprites[i].clearBitmaps();
            }
            vgaController.refreshSprites();
            break;
        }
        break;
      }
      case commandState::sendChar:
      {
        terminal.write(pendingData);
        cmdState = commandState::noCommand;
        break;
      }
      case commandState::sendStrng:
      {
        if (pendingData == 0)
        {
          cmdState = commandState::noCommand;
          break;
        }
        terminal.write(pendingData);
        break;
      }
      case commandState::cursorPosX:
      {
        tempCursorX = pendingData;
        cmdState = commandState::cursorPosY;
        break;
      }
      case commandState::cursorPosY:
      {
        char commandToWrite[11];
        snprintf(commandToWrite, sizeof(commandToWrite), "\e[%u;%uH", pendingData, tempCursorX); 
        terminal.write(commandToWrite);
        cmdState = commandState::noCommand;
        break;
      }
      case commandState::textForeground:
      {
        terminal.setForegroundColor(static_cast<Color>(pendingData & 0xF), false);
        cmdState = commandState::noCommand;
        break;
      }
      case commandState::textBackground:
      {
        terminal.setBackgroundColor(static_cast<Color>(pendingData & 0xF), false);
        cmdState = commandState::noCommand;
        break;
      }
      case commandState::graphics:
      {
        gfxCmdBuffer[currentGfxCmdByte] = pendingData;
        currentGfxCmdByte++;
        if (currentGfxCmdByte >= gfxCmdBytes[static_cast<int>(drawMode)])
        {
          switch (drawMode)
          {
            case gfxDrawMode::point:
            {
              RGB222 c = getColour222(gfxCmdBuffer[0]);
              Coord coord = getCoord(gfxCmdBuffer[1], gfxCmdBuffer[2], gfxCmdBuffer[3], gfxCmdBuffer[4]);
              setPixel(coord.x, coord.y, c);
              break;
            }
            case gfxDrawMode::line:
            {
              RGB222 c = getColour222(gfxCmdBuffer[0]);
              Coord coord1 = getCoord(gfxCmdBuffer[1], gfxCmdBuffer[2], gfxCmdBuffer[3], gfxCmdBuffer[4]);
              Coord coord2 = getCoord(gfxCmdBuffer[5], gfxCmdBuffer[6], gfxCmdBuffer[7], gfxCmdBuffer[8]);
              if (coord1.x == coord2.x) // Vertical line
              {
                drawVertLine(coord1.x, coord1.y, coord2.y, c);
              }
              else if (coord1.y == coord2.y) // Horizontal line
              {
                drawHoriLine(coord1.y, coord1.x, coord2.x, c);
              }
              else // Bresenham's algorithm
              {
                int dx = abs(coord2.x - coord1.x);
                int dy = abs(coord2.y - coord1.y);
                int sx = coord1.x < coord2.x ? 1 : -1;
                int sy = coord1.y < coord2.y ? 1 : -1;
                int err = (dx > dy ? dx : -dy) / 2;
                while (true)
                {
                  setPixel(coord1.x, coord1.y, c);
                  if (coord1.x == coord2.x && coord1.y == coord2.y) { break; }
                  int e2 = err;
                  if (e2 > -dx)
                  {
                    err -= dy;
                    coord1.x += sx;
                  }
                  if (e2 < dy)
                  {
                    err += dx;
                    coord1.y += sy;
                  }
                }
              }
              break;
            }
            case gfxDrawMode::rect:
            {
              RGB222 c = getColour222(gfxCmdBuffer[0]);
              Coord coord1 = getCoord(gfxCmdBuffer[1], gfxCmdBuffer[2], gfxCmdBuffer[3], gfxCmdBuffer[4]);
              Coord coord2 = getCoord(gfxCmdBuffer[5], gfxCmdBuffer[6], gfxCmdBuffer[7], gfxCmdBuffer[8]);
              drawHoriLine(coord1.y, coord1.x, coord2.x, c);
              drawHoriLine(coord2.y, coord1.x, coord2.x, c);
              drawVertLine(coord1.x, coord1.y, coord2.y, c);
              drawVertLine(coord2.x, coord1.y, coord2.y, c);
              break;
            }
            case gfxDrawMode::fillrect:
            {
              RGB222 c = getColour222(gfxCmdBuffer[0]);
              Coord coord1 = getCoord(gfxCmdBuffer[1], gfxCmdBuffer[2], gfxCmdBuffer[3], gfxCmdBuffer[4]);
              Coord coord2 = getCoord(gfxCmdBuffer[5], gfxCmdBuffer[6], gfxCmdBuffer[7], gfxCmdBuffer[8]);
              int x1 = min(coord1.x, coord2.x);
              int x2 = max(coord1.x, coord2.x);
              int y1 = min(coord1.y, coord2.y);
              int y2 = max(coord1.y, coord2.y);
              for (; y1 <= y2; y1++)
              {
                for (; x1 <= x2; x1++)
                {
                  setPixel(x1, y1, c);
                }
              }
              break;
            }
            case gfxDrawMode::bitmap:
            {
              bitmapPos = getCoord(gfxCmdBuffer[0], gfxCmdBuffer[1], gfxCmdBuffer[2], gfxCmdBuffer[3]);
              bitmapDim = getCoord(gfxCmdBuffer[4], gfxCmdBuffer[5], gfxCmdBuffer[6], gfxCmdBuffer[7]);
              currentBitmapPos = bitmapPos;
              break;
            }
            case gfxDrawMode::spriteGraphic:
            {
              currentSpriteIndex = gfxCmdBuffer[0];
              bitmapDim = getCoord(gfxCmdBuffer[1], gfxCmdBuffer[2], gfxCmdBuffer[3], gfxCmdBuffer[4]);
              if (spriteBitmapBuffer != NULL)
              {
                free(spriteBitmapBuffer);
              }
              spriteBitmapBuffer = (uint8_t*)malloc(bitmapDim.x * bitmapDim.y);
              if (spriteBitmapBuffer == NULL)
              {
                //Out of memory!
                drawMode = gfxDrawMode::point; //Cancel drawing sprite
              }
              currentBitmapPos = {0, 0};
              break;
            }
            case gfxDrawMode::spriteMove:
            {
              Coord c = getCoord(gfxCmdBuffer[1], gfxCmdBuffer[2], gfxCmdBuffer[3], gfxCmdBuffer[4]);
              sprites[gfxCmdBuffer[0]].moveTo(c.x, c.y);
              vgaController.refreshSprites();
              break;
            }
          }
          currentGfxCmdByte = 0;
          if (drawMode == gfxDrawMode::bitmap)
          {
            cmdState = commandState::bitmapData;
          }
          else if (drawMode == gfxDrawMode::spriteGraphic)
          {
            cmdState = commandState::spriteBitmapData;
          }
          else
          {
            cmdState = commandState::noCommand;
          }
        }
        break;
      }
      case commandState::bitmapData:
      {
        if (!(pendingData & 0b10000000))
        {
          setPixel(currentBitmapPos.x, currentBitmapPos.y, getColour222(pendingData));
        }
        currentBitmapPos.x++;
        if (currentBitmapPos.x >= bitmapPos.x + bitmapDim.x)
        {
          currentBitmapPos.x = bitmapPos.x;
          currentBitmapPos.y++;
          if (currentBitmapPos.y >= bitmapPos.y + bitmapDim.y)
          {
            cmdState = commandState::noCommand;
          }
        }
        break;
      }
      case commandState::spriteBitmapData:
      {
        int bufferIndex = currentBitmapPos.x + (currentBitmapPos.y * bitmapDim.x);
        if (pendingData & 0b10000000)
        {
          spriteBitmapBuffer[bufferIndex] = 0;
        }
        else
        {
          // Swap ARGB to ABGR
          uint8_t toSend = 0b11000000;
          toSend |= (pendingData & 0x3) << 4;
          toSend |= pendingData & 0xC;
          toSend |= (pendingData & 0x30) >> 4;
          spriteBitmapBuffer[bufferIndex] = toSend;
        }
        currentBitmapPos.x++;
        if (currentBitmapPos.x >= bitmapDim.x)
        {
          currentBitmapPos.x = 0;
          currentBitmapPos.y++;
          if (currentBitmapPos.y >= bitmapDim.y)
          {
            sprites[currentSpriteIndex].clearBitmaps();
            spriteBitmaps[currentSpriteIndex] = Bitmap(bitmapDim.x, bitmapDim.y, spriteBitmapBuffer, PixelFormat::RGBA2222, RGB888(0, 0, 0), true);
            sprites[currentSpriteIndex].addBitmap(&spriteBitmaps[currentSpriteIndex]);
            vgaController.refreshSprites();
            cmdState = commandState::noCommand;
          }
        }
        break;
      }
      case commandState::makeSpriteVisible:
        sprites[pendingData].visible = true;
        vgaController.refreshSprites();
        cmdState = commandState::noCommand;
        break;
      case commandState::makeSpriteInvisible:
        sprites[pendingData].visible = false;
        vgaController.refreshSprites();
        cmdState = commandState::noCommand;
        break;
    }
    dataPending = false;
    digitalWrite(INTERRUPT_OUT_PIN, LOW);
    ets_delay_us(2); // Delay 2 microseconds (2MHz clock period is 0.5 microseconds)
    digitalWrite(INTERRUPT_OUT_PIN, HIGH);
  }
  }
}

inline void drawHoriLine(int y, int startX, int endX, RGB222 c)
{
  if (endX < startX)
  {
    for (int i = endX; i <= startX; i++)
    {
      setPixel(i, y, c);
    }
  }
  else
  {
    for (int i = startX; i <= endX; i++)
    {
      setPixel(i, y, c);
    }
  }
}

inline void drawVertLine(int x, int startY, int endY, RGB222 c)
{
  if (endY < startY)
  {
    for (int i = endY; i <= startY; i++)
    {
      setPixel(x, i, c);
    }
  }
  else
  {
    for (int i = startY; i <= endY; i++)
    {
      setPixel(x, i, c);
    }
  }
}

inline void setPixel(int x, int y, RGB222 c)
{
  if (checkCoord(x, y))
  {
    vgaController.setRawPixel(x, y, vgaController.createRawPixel(c));
    //canvas.setPixel(x, y, {c.R << 6, c.G << 6, c.B << 6});
  }
}

inline RGB888 getColour888(uint8_t c)
{
  return {(c & 0b00110000) << 2, (c & 0b00001100) << 4, (c & 0b00000011) << 6};
}

inline RGB222 getColour222(uint8_t c)
{
  return {(c & 0b00110000) >> 4, (c & 0b00001100) >> 2, c & 0b00000011};
}

inline Coord getCoord(uint8_t b1, uint8_t b2, uint8_t b3, uint8_t b4)
{
  return {(int)b1 | ((int)b2 << 8), (int)b3 | ((int)b4 << 8)};
}

inline bool checkCoord(int x, int y)
{
  return (x < vgaController.getScreenWidth() && y < vgaController.getScreenHeight());
}

/*
void slowPrintf(const char * format, ...)
{
  va_list ap;
  va_start(ap, format);
  int size = vsnprintf(nullptr, 0, format, ap) + 1;
  if (size > 0) {
    char buf[size + 1];
    vsnprintf(buf, size, format, ap);
    for (int i = 0; i < size; ++i) {
      Terminal.write(buf[i]);
      delay(25);
    }
  }
  va_end(ap);
}

void demo1()
{
  Terminal.write("\e[40;32m"); // background: black, foreground: green
  Terminal.write("\e[2J");     // clear screen
  Terminal.write("\e[1;1H");   // move cursor to 1,1
  slowPrintf("* * * * W E L C O M E   T O   F a b G L * * * *\r\n");
  slowPrintf("2019 by Fabrizio Di Vittorio  -   www.fabgl.com\r\n");
  slowPrintf("===============================================\r\n\n");
  slowPrintf("This is a VGA Controller, PS2 Mouse and Keyboard Controller, Graphics Library,  Game Engine and ANSI/VT Terminal for the ESP32\r\n\n");
  slowPrintf("Current settings\r\n");
  slowPrintf("Screen Size   : %d x %d\r\n", VGAController.getScreenWidth(), VGAController.getScreenHeight());
  slowPrintf("Terminal Size : %d x %d\r\n", Terminal.getColumns(), Terminal.getRows());
  slowPrintf("Free Memory   : %d bytes\r\n\n", heap_caps_get_free_size(MALLOC_CAP_8BIT));
}

void demo2()
{
  Terminal.write("\e[40;32m"); // background: black, foreground: green
  slowPrintf("8 or 64 colors supported (depends by GPIOs used)\r\n");
  slowPrintf("ANSI colors:\r\n");
  // foregrounds
  Terminal.write("\e[31mRED\t"); delay(500);
  Terminal.write("\e[32mGREEN\t"); delay(500);
  Terminal.write("\e[33mYELLOW\t"); delay(500);
  Terminal.write("\e[34mBLUE\t"); delay(500);
  Terminal.write("\e[35mMAGENTA\t"); delay(500);
  Terminal.write("\e[36mCYAN\t"); delay(500);
  Terminal.write("\e[37mWHITE\r\n"); delay(500);
  Terminal.write("\e[90mHBLACK\t"); delay(500);
  Terminal.write("\e[91mHRED\t"); delay(500);
  Terminal.write("\e[92mHGREEN\t"); delay(500);
  Terminal.write("\e[93mHYELLOW\t"); delay(500);
  Terminal.write("\e[94mHBLUE\t"); delay(500);
  Terminal.write("\e[95mHMAGENTA\t"); delay(500);
  Terminal.write("\e[96mHCYAN\t"); delay(500);
  Terminal.write("\e[97mHWHITE\r\n"); delay(500);
  // backgrounds
  Terminal.write("\e[40mBLACK\t"); delay(500);
  Terminal.write("\e[41mRED\e[40m\t"); delay(500);
  Terminal.write("\e[42mGREEN\e[40m\t"); delay(500);
  Terminal.write("\e[43mYELLOW\e[40m\t"); delay(500);
  Terminal.write("\e[44mBLUE\e[40m\t"); delay(500);
  Terminal.write("\e[45mMAGENTA\e[40m\t"); delay(500);
  Terminal.write("\e[46mCYAN\e[40m\t"); delay(500);
  Terminal.write("\e[47mWHITE\e[40m\r\n"); delay(500);
  Terminal.write("\e[100mHBLACK\e[40m\t"); delay(500);
  Terminal.write("\e[101mHRED\e[40m\t"); delay(500);
  Terminal.write("\e[102mHGREEN\e[40m\t"); delay(500);
  Terminal.write("\e[103mHYELLOW\e[40m\t"); delay(500);
  Terminal.write("\e[104mHBLUE\e[40m\t"); delay(500);
  Terminal.write("\e[105mHMAGENTA\e[40m\t"); delay(500);
  Terminal.write("\e[106mHCYAN\e[40m\r\n"); delay(500);
}

void demo3()
{
  Terminal.write("\e[40;32m"); // background: black, foreground: green
  slowPrintf("\nSupported styles:\r\n");
  slowPrintf("\e[0mNormal\r\n");
  slowPrintf("\e[1mBold\e[0m\r\n");
  slowPrintf("\e[3mItalic\e[0m\r\n");
  slowPrintf("\e[4mUnderlined\e[0m\r\n");
  slowPrintf("\e[5mBlink\e[0m\r\n");
  slowPrintf("\e[7mInverse\e[0m\r\n");
  slowPrintf("\e[1;3mBoldItalic\e[0m\r\n");
  slowPrintf("\e[1;3;4mBoldItalicUnderlined\e[0m\r\n");
  slowPrintf("\e[1;3;4;5mBoldItalicUnderlinedBlinking\e[0m\r\n");
  slowPrintf("\e[1;3;4;5;7mBoldItalicUnderlinedBlinkingInverse\e[0m\r\n");
  slowPrintf("\e#6Double Width Line\r\n");
  slowPrintf("\e#6\e#3Double Height Line\r\n"); // top half
  slowPrintf("\e#6\e#4Double Height Line\r\n"); // bottom half
}

void demo4()
{
  Canvas cv(&VGAController);
  Terminal.write("\e[40;32m"); // background: black, foreground: green
  slowPrintf("\nMixed text and graphics:\r\n");
  slowPrintf("Points...\r\n");
  for (int i = 0; i < 500; ++i) {
    cv.setPenColor(random(256), random(256), random(256));
    cv.setPixel(random(cv.getWidth()), random(cv.getHeight()));
    delay(15);
  }
  delay(500);
  slowPrintf("\e[40;32mLines...\r\n");
  for (int i = 0; i < 50; ++i) {
    cv.setPenColor(random(256), random(256), random(256));
    cv.drawLine(random(cv.getWidth()), random(cv.getHeight()), random(cv.getWidth()), random(cv.getHeight()));
    delay(50);
  }
  delay(500);
  slowPrintf("\e[40;32mRectangles...\r\n");
  for (int i = 0; i < 50; ++i) {
    cv.setPenColor(random(256), random(256), random(256));
    cv.drawRectangle(random(cv.getWidth()), random(cv.getHeight()), random(cv.getWidth()), random(cv.getHeight()));
    delay(50);
  }
  delay(500);
  slowPrintf("\e[40;32mEllipses...\r\n");
  for (int i = 0; i < 50; ++i) {
    cv.setPenColor(random(256), random(256), random(256));
    cv.drawEllipse(random(cv.getWidth()), random(cv.getHeight()), random(cv.getWidth()), random(cv.getHeight()));
    delay(50);
  }
  for (int i = 0; i < 30; ++i) {
    Terminal.write("\e[40;32mScrolling...\r\n");
    delay(250);
  }
}

void demo5()
{
  Terminal.write("\e[40;93m"); // background: black, foreground: yellow
  Terminal.write("\e[2J");     // clear screen
  slowPrintf("\e[10;56HFast Rendering");
  slowPrintf("\e[12;50HThis is a VT/ANSI animation");
  Terminal.write("\e[20h"); // automatic new line on
  Terminal.write("\e[92m"); // light-green
  Terminal.enableCursor(false);
  for (int j = 0; j < 4; ++j) {
    for (int i = 0; i < sizeof(vt_animation); ++i) {
      Terminal.write(vt_animation[i]);
      if (vt_animation[i] == 0x1B && vt_animation[i + 1] == 0x5B && vt_animation[i + 2] == 0x48)
        delay(120); // pause 100ms every frame
    }
  }
  Terminal.enableCursor(true);
  Terminal.write("\e[20l"); // automatic new line off
}
*/
