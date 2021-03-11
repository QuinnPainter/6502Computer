#ifndef NewPS2Keyboard_h
#define NewPS2Keyboard_h

#include "Arduino.h"

class PS2Keyboard {
  public:
  	/**
  	 * This constructor does basically nothing. Please call the begin(int,int)
  	 * method before using any other method of this class.
  	 */
    PS2Keyboard();

    /**
     * Starts the keyboard "service" by registering the external interrupt.
     * setting the pin modes correctly and driving those needed to high.
     * The propably best place to call this method is in the setup routine.
     */
    static void begin(uint8_t dataPin, uint8_t irq_pin);

    /**
     * Returns ps2 scan code.
     */
    static uint8_t readScanCode();
};

#endif
