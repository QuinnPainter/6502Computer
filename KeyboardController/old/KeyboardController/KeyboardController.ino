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

#define REGSEL_PIN0 4
#define REGSEL_PIN1 5
#define REGSEL_PIN2 6
#define REGSEL_PIN3 7

#define PAUSEBRK_PULSE_MILLIS 500

#define LED_BLINK_MILLIS 100

//Backtick is `

namespace keys
{
  enum keyPositions
  {
    LShift = 0, RShift = 1, LCtrl, RCtrl, Win, Alt, AltGr, Menu,
    CapsLk, Tab, Esc, Enter, Backspace, Del, Insert, PrtScr,
    ScrLk, PauseBrk, Home, PgUp, PgDown, End, NumLk, Backtick,
    One, Two, Three, Four, Five, Six, Seven, Eight,
    Nine, Zero, Minus, Equals, Q, W, E, R,
    T, Y, U, I, O, P, LeftSquare, RightSquare,
    A, S, D, F, G, H, J, K,
    L, Semicolon, Quote, Hash, Bslash, Z, X, C,
    V, B, N, M, Comma, Dot, Fslash, UNUSED1,
    Up, Down, Left, Right, Space, ZRpt, XRpt, CRpt,
    F1, F2, F3, F4, F5, F6, F7, F8,
    F9, F10, F11, F12, NumDiv, NumMul, NumMinus, NumPlus,
    Num1, Num2, Num3, Num4, Num5, Num6, Num7, Num8,
    Num9, Num0, NumDot, NumEnter, CapsToggle, NumLkToggle, ScrLkToggle,
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

bool keyStates[8*16] = {};
uint8_t prevRegSelect = 0xFF;
bool breakMode = false;
bool extendMode = false;
uint8_t ignoreNum = 0;
unsigned long pauseBrkTimerStart = 0;
bool pauseBrkTimerEnabled = false;
bool keyChangeHappened = false;
unsigned long ledBlinkTimerStart = 0;
bool ledBlinkTimerEnabled = false;

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
  pinMode(REGSEL_PIN0, INPUT);
  pinMode(REGSEL_PIN1, INPUT);
  pinMode(REGSEL_PIN2, INPUT);
  pinMode(REGSEL_PIN3, INPUT);
  keyboard.begin(PS2_DATAPIN, PS2_CLKPIN);
}

void loop()
{
  keyChangeHappened = false;
  unsigned long currentTime = millis();
  if (pauseBrkTimerEnabled && (currentTime-pauseBrkTimerStart > PAUSEBRK_PULSE_MILLIS))
  {
    keyStates[keys::PauseBrk] = false;
    pauseBrkTimerEnabled = false;
    keyChangeHappened = true;
  }
  if (ledBlinkTimerEnabled && (currentTime-ledBlinkTimerStart > LED_BLINK_MILLIS))
  {
    ledBlinkTimerEnabled = false;
    RXLED0;
  }
  uint8_t code = keyboard.readScanCode();
  if (code > 0)
  {
    if (ignoreNum > 0)
    {
      ignoreNum--;
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
      //So I just pulse it for a while
      keyStates[keys::PauseBrk] = true;
      pauseBrkTimerStart = currentTime;
      pauseBrkTimerEnabled = true;
      
      //It's also a bunch of scancodes so we need to ignore the rest
      ignoreNum = 7;
      keyChangeHappened = true;
    }
    else if (extendMode && code == 0x12)
    {
      //Prt Scr is also long
      ignoreNum = 2;
      keyStates[keys::PrtScr] == true;
      extendMode = false;
      keyChangeHappened = true;
    }
    else if (extendMode && breakMode && code == 0x7C)
    {
      //Why does Prt Scr have such a strange break code?
      ignoreNum = 3;
      keyStates[keys::PrtScr] == false;
      extendMode = false;
      breakMode = false;
      keyChangeHappened = true;
    }
    else
    {
      uint8_t key = extendMode ? ext_scancodes[code] : scancodes[code];
      if (key != keys::INVALID)
      {
        keyStates[key] = !breakMode;
        if (key == keys::Z)
        {
          keyStates[keys::ZRpt] = keyStates[keys::Z];
        }
        else if (key == keys::X)
        {
          keyStates[keys::XRpt] = keyStates[keys::X];
        }
        else if (key == keys::C)
        {
          keyStates[keys::CRpt] = keyStates[keys::C];
        }
        if (breakMode)
        {
          switch (key)
          {
            case keys::CapsLk:
            {
              keyStates[keys::CapsToggle] = !keyStates[keys::CapsToggle];
              break;
            }
            case keys::NumLk:
            {
              keyStates[keys::NumLkToggle] = !keyStates[keys::NumLkToggle];
              break;
            }
            case keys::ScrLk:
            {
              keyStates[keys::ScrLkToggle] = !keyStates[keys::ScrLkToggle];
              break;
            }
          }
        }
      }
      extendMode = false;
      breakMode = false;
      keyChangeHappened = true;
    }
    /*
    uint8_t key = scancodes[code];
    Serial.print("key: ");
    Serial.print((int)key);
    Serial.print(" scan: ");
    Serial.println((int)code);
    */
    ledBlinkTimerStart = currentTime;
    ledBlinkTimerEnabled = true;
    RXLED1;
  }

  uint8_t regSelect = digitalRead(REGSEL_PIN0) |
                      digitalRead(REGSEL_PIN1) << 1 |
                      digitalRead(REGSEL_PIN2) << 2 |
                      digitalRead(REGSEL_PIN3) << 3;
  if ((regSelect != prevRegSelect) || keyChangeHappened)
  {
    uint8_t startIndex = regSelect * 8;
    digitalWrite(OUTPUT_PIN0, keyStates[startIndex]);
    digitalWrite(OUTPUT_PIN1, keyStates[startIndex + 1]);
    digitalWrite(OUTPUT_PIN2, keyStates[startIndex + 2]);
    digitalWrite(OUTPUT_PIN3, keyStates[startIndex + 3]);
    digitalWrite(OUTPUT_PIN4, keyStates[startIndex + 4]);
    digitalWrite(OUTPUT_PIN5, keyStates[startIndex + 5]);
    digitalWrite(OUTPUT_PIN6, keyStates[startIndex + 6]);
    digitalWrite(OUTPUT_PIN7, keyStates[startIndex + 7]);
    prevRegSelect = regSelect;
  }
}
