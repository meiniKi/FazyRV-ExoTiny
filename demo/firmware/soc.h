
#include "types.h"

#define GPIO (*((volatile uint32_t*)(0x20000000)))

#define ADR_RAM ((volatile uint32_t*)(0x10000000))