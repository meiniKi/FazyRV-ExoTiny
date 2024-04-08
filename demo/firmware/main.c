
#include "soc.h"


void fail(void)
{
  uint16_t i;

  while(1)
  {
    GPIO = 0x01;
    for (i=0; i<10; i++)
      asm volatile ("addi x0, x0, 1");

    GPIO = 0x00;
    for (i=0; i<1000; i++)
      asm volatile ("addi x0, x0, 1");
  }
}

void pass(void)
{
  uint16_t i;

  while(1)
  {
    GPIO = 0x01;
    for (i=0; i<100; i++)
      asm volatile ("addi x0, x0, 1");

    GPIO = 0x00;
    for (i=0; i<100; i++)
      asm volatile ("addi x0, x0, 1");
  }
}

void check_ram(void)
{
  uint32_t i;
  uint32_t data;

  // zeros
  for (uint8_t offset = 0; offset < 10; offset+=4)
  {
    asm volatile (
        "li t2, 0x00000000\n\t"
        "sw t2, 0(%[base])\n\t"
        "lw t1, 0(%[base])\n\t"
        "beq t1, t2, 1f\n\t"
        "jal fail\n\t"
        "1:\n\t"
        : // No output operands
        : [base] "r" (ADR_RAM+offset) // Input operands
        : "t1", "t2" // Clobber list
    );
  }

  // ones
  for (uint32_t offset = 0; offset < 100; offset+=4)
  {
    asm volatile (
        "li t2, 0xFFFFFFFF\n\t"
        "sw t2, 0(%[base])\n\t"
        "lw t1, 0(%[base])\n\t"
        "beq t1, t2, 1f\n\t"
        "jal fail\n\t"
        "1:\n\t"
        : // No output operands
        : [base] "r" (ADR_RAM+offset) // Input operands
        : "t1", "t2" // Clobber list
    );
  }

  // offset
  for (uint32_t offset = 0; offset < 100; offset+=4)
  {
    data = offset;
    asm volatile (
        "sw %[data], 0(%[base])\n\t"
        "lw t1, 0(%[base])\n\t"
        "beq t1, %[data], 1f\n\t"
        "jal fail\n\t"
        "1:\n\t"
        : // No output operands
        : [base] "r" (ADR_RAM+offset), [data] "r" (data) // Input operands
        : "t1" // Clobber list
    );
  }

}

void check_gpio(void)
{
  GPIO = 0x0;
  if (GPIO != 0x00) fail();

  GPIO = 0x02;
  if (GPIO != 0x02) fail();

  GPIO = 0x04;
  if (GPIO != 0x04) fail();

  GPIO = 0x08;
  if (GPIO != 0x08) fail();

  GPIO = 0x10;
  if (GPIO != 0x10) fail();

  // this should fail
  //GPIO = 0x80;
  //if (GPIO != 0x80) fail();
}



void main(void)
{
  check_ram();
  check_gpio();

  pass();
}
