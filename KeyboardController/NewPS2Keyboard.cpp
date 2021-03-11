//Based on "PS2Keyboard"
//https://www.pjrc.com/teensy/td_libs_PS2Keyboard.html

#include "NewPS2Keyboard.h"

#define BUFFER_SIZE 45
static volatile uint8_t buffer[BUFFER_SIZE];
static volatile uint8_t head, tail;
static uint8_t DataPin;

// The ISR for the external interrupt
void ps2interrupt(void) {
	static uint8_t bitcount=0;
	static uint8_t incoming=0;
	static uint32_t prev_ms=0;
	uint32_t now_ms;
	uint8_t n, val;

	val = digitalRead(DataPin);
	now_ms = millis();
	if (now_ms - prev_ms > 250) {
		bitcount = 0;
		incoming = 0;
	}
	prev_ms = now_ms;
	n = bitcount - 1;
	if (n <= 7) {
		incoming |= (val << n);
	}
	bitcount++;
	if (bitcount == 11) {
		uint8_t i = head + 1;
		if (i >= BUFFER_SIZE) { i = 0; }
		if (i != tail) {
			buffer[i] = incoming;
			head = i;
		}
        
		bitcount = 0;
		incoming = 0;
	}
}

uint8_t PS2Keyboard::readScanCode() {
	if (tail == head) { return 0; }
	tail++;
	if (tail >= BUFFER_SIZE) { tail = 0; }
	return buffer[tail];
}

PS2Keyboard::PS2Keyboard() {
  // nothing to do here, begin() does it all
}

void PS2Keyboard::begin(uint8_t data_pin, uint8_t irq_pin) {
  uint8_t irq_num = 255;

  DataPin = data_pin;

  // initialize the pins
  pinMode(irq_pin, INPUT_PULLUP);
  pinMode(data_pin, INPUT_PULLUP);

  //Arduino Pro Micro interrupt pins
  switch(irq_pin) {
    case 3:
      irq_num = 0;
      break;
    case 2:
      irq_num = 1;
      break;
    case 0:
      irq_num = 2;
      break;
    case 1:
      irq_num = 3;
      break;
    case 7:
      irq_num = 4;
      break;
  }

  head = 0;
  tail = 0;
  if (irq_num < 255) {
    attachInterrupt(irq_num, ps2interrupt, FALLING);
  }
}


