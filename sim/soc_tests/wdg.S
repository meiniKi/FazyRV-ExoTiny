
#*****************************************************************************
# wdg.S
#-----------------------------------------------------------------------------
#
# Test wdg register
#

#include "../tests/riscv_test.h"
#include "../tests/test_macros.h"

RVTEST_RV32U
RVTEST_CODE_BEGIN

  #-------------------------------------------------------------
  # WDG write and readback
  #-------------------------------------------------------------

  # do watchdog things here!
  li   t0, 0x80000000      # Load base address of watchdog into t0

  # enable watchdog
  li   t1, 0x1             # Load value 0x1 into t1
  sb   t1, 0(t0)           # Store byte t1 to address in t0

  # wait some time
  li   t2, 100      # Load a large value for delay
delay_loop:
    addi t2, t2, -1       # Decrement t2
    bnez t2, delay_loop   # If t2 != 0, repeat loop

  # disable watchdog
  li   t1, 0x0             # Load value 0x1 into t1
  sb   t1, 0(t0)           # Store byte t1 to address in t0

  # enable watchdog
  li   t1, 0x1             # Load value 0x1 into t1
  sb   t1, 0(t0)           # Store byte t1 to address in t0

  # wait some more time
  li   t2, 200     # Load a large value for delay

  # This breaks the test suite, as the core gets reset
  # Added to manually test whether the reset logic works
  #li x1, 0x04;
  #li x2, 0x20000000;
  #sb x1, 0(x2);

delay_loop2:
    addi t2, t2, -1       # Decrement t2
    bnez t2, delay_loop2   # If t2 != 0, repeat loop

  # this delay loop is enough to trigger a reset cycle via the watchdog
  # afterwards the watchdog is disabled as it resets itself at the end of this sequence

  # Program custom wdcnt value (timeout value)
  # timeout count: 255
  # enable wdg: 1
  li   t1, (0x0A << 4) | 0x1
  sw   t1, 0(t0)           # Store byte t1 to address in t0

  # wait some more time
  li   t2, 200     # Load a large value for delay
delay_loop3:
    addi t2, t2, -1       # Decrement t2
    bnez t2, delay_loop3   # If t2 != 0, repeat loop

  # for happy test:
  TEST_ST_OP( 2, lb, sb, 0b00000001, 0, 0x20000000 );
  TEST_ST_OP( 3, lb, sb, 0b00000010, 0, 0x20000000 );
  TEST_ST_OP( 4, lb, sb, 0b00000100, 0, 0x20000000 );
  TEST_ST_OP( 5, lb, sb, 0b00000000, 0, 0x20000000 );

  TEST_PASSFAIL

RVTEST_CODE_END

  .data
RVTEST_DATA_BEGIN

  TEST_DATA

RVTEST_DATA_END
