
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

  # auto CS, ~cpol, spi zeros, 4 bytes
  TEST_ST_OP( 2, lw, sw, 0x00000003, 0, 0x20000000 );
  TEST_ST_OP( 3, lw, sw, 0x00030401, 0, 0x20000008 );
  TEST_ST_WT_RD( 4, lw, sw, 0x750000FF, 0x00000000, 0, 0x40000000, 0x20000010, 0x1);

  ######

  # auto CS, ~cpol, spi ones, 1 byte
  # (1) clear rx (zeros)
  TEST_ST_OP(107, lw, sw, 0x00000003, 0, 0x20000000 );
  TEST_ST_OP( 8, lw, sw, 0x00030401, 0, 0x20000008 );
  TEST_ST_WT_RD( 9, lw, sw, 0x00000000, 0x00000000, 0, 0x40000000, 0x20000010, 0x1);

  # auto CS, ~cpol, spi ones, 2 bytes
  # (1) clear rx (zeros)
  TEST_ST_OP(13, lw, sw, 0x00000003, 0, 0x20000000 );
  TEST_ST_OP(14, lw, sw, 0x00030401, 0, 0x20000008 );
  TEST_ST_WT_RD(15, lw, sw, 0x00000000, 0x00000000, 0, 0x40000000, 0x20000010, 0x1);

  # auto CS, ~cpol, spi ones, 3 bytes
  # (1) clear rx (zeros)
  TEST_ST_OP(19, lw, sw, 0x00000003, 0, 0x20000000 );
  TEST_ST_OP(20, lw, sw, 0x00030401, 0, 0x20000008 );
  TEST_ST_WT_RD(21, lw, sw, 0x00000000, 0x00000000, 0, 0x40000000, 0x20000010, 0x1);

  # auto CS, ~cpol, spi loopback, 1 byte
  # (2) write 1 byte ones
  TEST_ST_OP(58, lw, sw, 0x00000000, 0, 0x20000000 );
  TEST_ST_OP(59, lw, sw, 0x00000401, 0, 0x20000008 );
  TEST_ST_WT_RD(60, lw, sw, 0xC0FFEEC0, 0x000000C0, 0, 0x40000000, 0x20000010, 0x1);

  # TODO: fix io shortage in testbench

  TEST_PASSFAIL

RVTEST_CODE_END

  .data
RVTEST_DATA_BEGIN

  TEST_DATA

RVTEST_DATA_END
