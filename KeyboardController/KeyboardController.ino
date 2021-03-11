#include "NewPS2Keyboard.h"

#define PS2_DATAPIN 2
#define PS2_CLKPIN 3

#define OUTPUT_PIN0 21
#define OUTPUT_PIN1 20
#define OUTPUT_PIN2 19
#define OUTPUT_PIN3 18
#define OUTPUT_PIN4 15
#define OUTPUT_PIN5 14
#define OUTPUT_PIN6 16
#define OUTPUT_PIN7 10

#define DATATAKENPIN 7
#define INTERRUPTOUTPIN 8

#define LED_BLINK_MILLIS 100

//Backtick is `

namespace keys
{
  enum keyPositions
  {
    LShift = 0, RShift, LCtrl, RCtrl, Win, Alt, AltGr, Menu,
    CapsLk, Tab, Esc, Enter, Backspace, Del, Insert, PrtScr,
    ScrLk, PauseBrk, Home, PgUp, PgDown, End, NumLk, Up,
    Down, Left, Right, F1, F2, F3, F4, F5, // End of 32 "control" codes
    Space, UN33, UN34, Hash, UN36, UN37, UN38, Quote,
    UN40, UN41, UN42, UN43, Comma, Minus, Dot, Fslash,
    Zero, One, Two, Three, Four, Five, Six, Seven,
    Eight, Nine, UN58, Semicolon, UN60, Equals, UN62, UN63,
    UN64, UN65, UN66, UN67, UN68, UN69, UN70, UN71,
    UN72, UN73, UN74, UN75, UN76, UN77, UN78, UN79,
    UN80, UN81, UN82, UN83, UN84, UN85, UN86, UN87,
    UN88, UN89, UN90, LeftSquare, Bslash, RightSquare, UN94, UN95,
    Backtick, A, B, C, D, E, F, G,
    H, I, J, K, L, M, N, O,
    P, Q, R, S, T, U, V, W,
    X, Y, Z, UN123, UN124, UN125, UN126, UN127,
    
    F6, F7, F8, //Start of unused keys
    F9, F10, F11, F12, NumDiv, NumMul, NumMinus, NumPlus,
    Num1, Num2, Num3, Num4, Num5, Num6, Num7, Num8,
    Num9, Num0, NumDot, NumEnter,
    INVALID
  };
}

//https://techdocs.altium.com/display/FPGA/PS2+Keyboard+Scan+Codes

#define NK keys::INVALID
const uint8_t scancodes[256] = {
  NK, keys::F9, NK, keys::F5, keys::F3, keys::F1, keys::F2, keys::F12,
  NK, keys::F10, keys::F8, keys::F6, keys::F4, keys::Tab, keys::Backtick, NK,
  NK, keys::Alt, keys::LShift, NK, keys::LCtrl, keys::Q, keys::One, NK,
  NK, NK, keys::Z, keys::S, keys::A, keys::W, keys::Two, NK,
  NK, keys::C, keys::X, keys::D, keys::E, keys::Four, keys::Three, NK,
  NK, keys::Space, keys::V, keys::F, keys::T, keys::R, keys::Five, NK,
  NK, keys::N, keys::B, keys::H, keys::G, keys::Y, keys::Six, NK,
  NK, NK, keys::M, keys::J, keys::U, keys::Seven, keys::Eight, NK,
  NK, keys::Comma, keys::K, keys::I, keys::O, keys::Zero, keys::Nine, NK,
  NK, keys::Dot, keys::Fslash, keys::L, keys::Semicolon, keys::P, keys::Minus, NK,
  NK, NK, keys::Quote, NK, keys::LeftSquare, keys::Equals, NK, NK,
  keys::CapsLk, keys::RShift, keys::Enter, keys::RightSquare, NK, keys::Bslash, NK, NK,
  NK, NK, NK, NK, NK, NK, keys::Backspace, NK,
  NK, keys::Num1, NK, keys::Num4, keys::Num7, NK, NK, NK,
  keys::Num0, keys::NumDot, keys::Num2, keys::Num5, keys::Num6, keys::Num8, keys::Esc, keys::NumLk,
  keys::F11, keys::NumPlus, keys::Num3, keys::NumMinus, keys::NumMul, keys::Num9, keys::ScrLk, NK,
  NK, NK, NK, keys::F7, NK, NK, NK, NK,
  NK, NK, NK, NK, NK, NK, NK, NK,
  NK, NK, NK, NK, NK, NK, NK, NK,
  NK, NK, NK, NK, NK, NK, NK, NK,
  NK, NK, NK, NK, NK, NK, NK, NK,
  NK, NK, NK, NK, NK, NK, NK, NK,
  NK, NK, NK, NK, NK, NK, NK, NK,
  NK, NK, NK, NK, NK, NK, NK, NK,
  NK, NK, NK, NK, NK, NK, NK, NK,
  NK, NK, NK, NK, NK, NK, NK, NK,
  NK, NK, NK, NK, NK, NK, NK, NK,
  NK, NK, NK, NK, NK, NK, NK, NK,
  NK, NK, NK, NK, NK, NK, NK, NK,
  NK, NK, NK, NK, NK, NK, NK, NK,
  NK, NK, NK, NK, NK, NK, NK, NK,
  NK, NK, NK, NK, NK, NK, NK, NK
};
const uint8_t ext_scancodes[256] = {
  NK, NK, NK, NK, NK, NK, NK, NK,
  NK, NK, NK, NK, NK, NK, NK, NK,
  NK, keys::AltGr, NK, NK, keys::RCtrl, NK, NK, NK,
  NK, NK, NK, NK, NK, NK, NK, keys::Win, //Left Win
  NK, NK, NK, NK, NK, NK, NK, keys::Win, //Right Win
  NK, NK, NK, NK, NK, NK, NK, keys::Menu,
  NK, NK, NK, NK, NK, NK, NK, NK,
  NK, NK, NK, NK, NK, NK, NK, NK,
  NK, NK, NK, NK, NK, NK, NK, NK,
  NK, NK, keys::NumDiv, NK, NK, NK, NK, NK,
  NK, NK, NK, NK, NK, NK, NK, NK,
  NK, NK, keys::NumEnter, NK, NK, NK, NK, NK,
  NK, NK, NK, NK, NK, NK, NK, NK,
  NK, keys::End, NK, keys::Left, keys::Home, NK, NK, NK,
  keys::Insert, keys::Del, keys::Down, NK, keys::Right, keys::Up, NK, NK,
  NK, NK, keys::PgDown, NK, NK, keys::PgUp, NK, NK,
  NK, NK, NK, NK, NK, NK, NK, NK,
  NK, NK, NK, NK, NK, NK, NK, NK,
  NK, NK, NK, NK, NK, NK, NK, NK,
  NK, NK, NK, NK, NK, NK, NK, NK,
  NK, NK, NK, NK, NK, NK, NK, NK,
  NK, NK, NK, NK, NK, NK, NK, NK,
  NK, NK, NK, NK, NK, NK, NK, NK,
  NK, NK, NK, NK, NK, NK, NK, NK,
  NK, NK, NK, NK, NK, NK, NK, NK,
  NK, NK, NK, NK, NK, NK, NK, NK,
  NK, NK, NK, NK, NK, NK, NK, NK,
  NK, NK, NK, NK, NK, NK, NK, NK,
  NK, NK, NK, NK, NK, NK, NK, NK,
  NK, NK, NK, NK, NK, NK, NK, NK,
  NK, NK, NK, NK, NK, NK, NK, NK,
  NK, NK, NK, NK, NK, NK, NK, NK
};
#undef NK

uint8_t keyBuffer[256] = {}; // this only works with 256, for some reason?
uint8_t writeIndex = 0; //      some sort of strange compiler thing, I guess
uint8_t readIndex = 0;
bool breakMode = false;
bool extendMode = false;
uint8_t ignoreNum = 0;
unsigned long ledBlinkTimerStart = 0;
bool ledBlinkTimerEnabled = false;
bool HostReady = true;
bool first = true; // when the computer starts, it doesn't send the ready signal
bool firstKey = true; // keyboard always sends [ on boot, for some reason

PS2Keyboard keyboard;

void setup() {
  pinMode(OUTPUT_PIN0, OUTPUT);
  pinMode(OUTPUT_PIN1, OUTPUT);
  pinMode(OUTPUT_PIN2, OUTPUT);
  pinMode(OUTPUT_PIN3, OUTPUT);
  pinMode(OUTPUT_PIN4, OUTPUT);
  pinMode(OUTPUT_PIN5, OUTPUT);
  pinMode(OUTPUT_PIN6, OUTPUT);
  pinMode(OUTPUT_PIN7, OUTPUT);
  pinMode(DATATAKENPIN, INPUT);
  digitalWrite(INTERRUPTOUTPIN, HIGH);
  pinMode(INTERRUPTOUTPIN, OUTPUT);
  //attachInterrupt(digitalPinToInterrupt(DATATAKENPIN), DataTakenISR, FALLING);
  keyboard.begin(PS2_DATAPIN, PS2_CLKPIN);
}

/*void DataTakenISR()
{
  HostReady = true;
}*/

inline void handleKey(uint8_t key)
{
  if (key < 128)
  {
    key |= (breakMode ? 0x80 : 0);
    keyBuffer[writeIndex] = key;
    writeIndex = (writeIndex + 1) & 0x0F;
  }
  extendMode = false;
  breakMode = false;
}

void loop()
{
  if (!first) { HostReady = !digitalRead(DATATAKENPIN); }
  if (HostReady && (readIndex != writeIndex))
  {
    uint8_t dataByte = keyBuffer[readIndex];
    digitalWrite(OUTPUT_PIN7, dataByte & 0b10000000);
    digitalWrite(OUTPUT_PIN6, dataByte & 0b01000000);
    digitalWrite(OUTPUT_PIN5, dataByte & 0b00100000);
    digitalWrite(OUTPUT_PIN4, dataByte & 0b00010000);
    digitalWrite(OUTPUT_PIN3, dataByte & 0b00001000);
    digitalWrite(OUTPUT_PIN2, dataByte & 0b00000100);
    digitalWrite(OUTPUT_PIN1, dataByte & 0b00000010);
    digitalWrite(OUTPUT_PIN0, dataByte & 0b00000001);
    readIndex = (readIndex + 1) & 0x0F;
    HostReady = false;
    first = false;
    digitalWrite(INTERRUPTOUTPIN, LOW);
    digitalWrite(INTERRUPTOUTPIN, HIGH);
  }
  unsigned long currentTime = millis();
  if (ledBlinkTimerEnabled && (currentTime-ledBlinkTimerStart > LED_BLINK_MILLIS))
  {
    ledBlinkTimerEnabled = false;
    RXLED0;
  }
  uint8_t code = keyboard.readScanCode();
  if (code > 0)
  {
    if (firstKey)
    {
      firstKey = false;
    }
    else if (ignoreNum > 0)
    {
      ignoreNum--;
    }
    else if (code == 0xAA || code == 0xFC)
    {
      //Ignore bootup success / fail code
    }
    else if (code == 0xF0)
    {
      breakMode = true;
    }
    else if (code == 0xE0)
    {
      extendMode = true;
    }
    else if (code == 0xE1)
    {
      //Pause Break doesn't have a break code
      handleKey(keys::PauseBrk);
      
      //It's also a bunch of scancodes so we need to ignore the rest
      ignoreNum = 7;
    }
    else if (extendMode && code == 0x12)
    {
      //Prt Scr is also long
      ignoreNum = 2;
      handleKey(keys::PrtScr);
    }
    else if (extendMode && breakMode && code == 0x7C)
    {
      //Why does Prt Scr have such a strange break code?
      ignoreNum = 3;
      handleKey(keys::PrtScr);
    }
    else
    {
      handleKey(extendMode ? ext_scancodes[code] : scancodes[code]);
    }
    ledBlinkTimerStart = currentTime;
    ledBlinkTimerEnabled = true;
    RXLED1;
  }
}
