
#include "soc.h"

void main (void)
{
  uint16_t i; 

  GPIO_REG = 0x01;

  for (i=0; i<10000; i++)
    asm volatile ("addi x0, x0, 1");

  // currently GPOs cannot be read back
  GPIO_REG = 0x00;

  for (i=0; i<10000; i++)
    asm volatile ("addi x0, x0, 1");

}
