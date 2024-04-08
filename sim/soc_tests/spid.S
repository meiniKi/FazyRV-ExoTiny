
#*****************************************************************************
# spid.S
#-----------------------------------------------------------------------------
#
# Test gpo register
#

#include "../tests/riscv_test.h"
#include "../tests/test_macros.h"
#include "test_macros_custom.h"

RVTEST_RV32U
RVTEST_CODE_BEGIN

  #-------------------------------------------------------------
  # spi_data, currently relies on manual inspection
  #-------------------------------------------------------------

  # auto CS, ~cpol, spi 0xAA, 1 byte
  TEST_ST_OP( 2, lw, sw, 0x00000001, 0, 0x20000000 );
  TEST_ST_OP( 3, lw, sw, 0x00010401, 0, 0x20000008 );
  TEST_ST_RD( 4, lw, sw, 0x750000FF, 0xAAAAAAAA, 0, 0x40000000 );

  # auto CS, cpol, spi 0xAA, 1 byte
  TEST_ST_OP( 5, lw, sw, 0x00000001, 0, 0x20000000 );
  TEST_ST_OP( 6, lw, sw, 0x00010601, 0, 0x20000008 );
  TEST_ST_RD( 7, lw, sw, 0x750000FF, 0xAAAAAAAA, 0, 0x40000000 );


  TEST_PASSFAIL

RVTEST_CODE_END

  .data
RVTEST_DATA_BEGIN

  TEST_DATA

RVTEST_DATA_END
