
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
  TEST_ST_OP( 2, lw, sw, 0x00000001, 0, 0x20000000 );
  TEST_ST_OP( 3, lw, sw, 0x00030401, 0, 0x20000008 );
  TEST_ST_WT_RD( 4, lw, sw, 0x750000FF, 0x00000000, 0, 0x40000000, 0x20000010, 0x1);

  # auto CS, cpol, spi ones, 4 bytes
  TEST_ST_OP( 5, lw, sw, 0x00000002, 0, 0x20000000 );
  TEST_ST_OP( 6, lw, sw, 0x00030601, 0, 0x20000008 );
  TEST_ST_WT_RD( 7, lw, sw, 0x750000FF, 0xFFFFFFFF, 0, 0x40000000, 0x20000010, 0x1);

  ######

  # auto CS, ~cpol, spi ones, 1 byte
  # (1) clear rx (zeros)
  TEST_ST_OP(107, lw, sw, 0x00000001, 0, 0x20000000 );
  TEST_ST_OP( 8, lw, sw, 0x00030401, 0, 0x20000008 );
  TEST_ST_WT_RD( 9, lw, sw, 0x00000000, 0x00000000, 0, 0x40000000, 0x20000010, 0x1);
  # (2) write 1 byte ones
  TEST_ST_OP(10, lw, sw, 0x00000002, 0, 0x20000000 );
  TEST_ST_OP(11, lw, sw, 0x00000401, 0, 0x20000008 );
  TEST_ST_WT_RD(12, lw, sw, 0x00000000, 0x000000FF, 0, 0x40000000, 0x20000010, 0x1);

  # auto CS, ~cpol, spi ones, 2 bytes
  # (1) clear rx (zeros)
  TEST_ST_OP(13, lw, sw, 0x00000001, 0, 0x20000000 );
  TEST_ST_OP(14, lw, sw, 0x00030401, 0, 0x20000008 );
  TEST_ST_WT_RD(15, lw, sw, 0x00000000, 0x00000000, 0, 0x40000000, 0x20000010, 0x1);
  # (2) write 2 bytes ones
  TEST_ST_OP(16, lw, sw, 0x00000002, 0, 0x20000000 );
  TEST_ST_OP(17, lw, sw, 0x00010401, 0, 0x20000008 );
  TEST_ST_WT_RD(18, lw, sw, 0x00000000, 0x0000FFFF, 0, 0x40000000, 0x20000010, 0x1);

  # auto CS, ~cpol, spi ones, 3 bytes
  # (1) clear rx (zeros)
  TEST_ST_OP(19, lw, sw, 0x00000001, 0, 0x20000000 );
  TEST_ST_OP(20, lw, sw, 0x00030401, 0, 0x20000008 );
  TEST_ST_WT_RD(21, lw, sw, 0x00000000, 0x00000000, 0, 0x40000000, 0x20000010, 0x1);
  # (2) write 2 bytes ones
  TEST_ST_OP(22, lw, sw, 0x00000002, 0, 0x20000000 );
  TEST_ST_OP(23, lw, sw, 0x00020401, 0, 0x20000008 );
  TEST_ST_WT_RD(24, lw, sw, 0x00000000, 0x00FFFFFF, 0, 0x40000000, 0x20000010, 0x1);

  # auto CS, ~cpol, spi ones, 4 bytes
  # (1) clear rx (zeros)
  TEST_ST_OP(25, lw, sw, 0x00000001, 0, 0x20000000 );
  TEST_ST_OP(26, lw, sw, 0x00030401, 0, 0x20000008 );
  TEST_ST_WT_RD(27, lw, sw, 0x00000000, 0x00000000, 0, 0x40000000, 0x20000010, 0x1);
  # (2) write 2 bytes ones
  TEST_ST_OP(28, lw, sw, 0x00000002, 0, 0x20000000 );
  TEST_ST_OP(29, lw, sw, 0x00030401, 0, 0x20000008 );
  TEST_ST_WT_RD(30, lw, sw, 0x00000000, 0xFFFFFFFF, 0, 0x40000000, 0x20000010, 0x1);

  ###

  # auto CS, ~cpol, spi zeros, 1 byte
  # (1) clear rx (ones)
  TEST_ST_OP(31, lw, sw, 0x00000002, 0, 0x20000000 );
  TEST_ST_OP(32, lw, sw, 0x00030401, 0, 0x20000008 );
  TEST_ST_WT_RD(33, lw, sw, 0x00000000, 0xFFFFFFFF, 0, 0x40000000, 0x20000010, 0x1);
  # (2) write 1 byte zeros
  TEST_ST_OP(34, lw, sw, 0x00000001, 0, 0x20000000 );
  TEST_ST_OP(35, lw, sw, 0x00000401, 0, 0x20000008 );
  TEST_ST_WT_RD(36, lw, sw, 0x00000000, 0xFFFFFF00, 0, 0x40000000, 0x20000010, 0x1);

  # auto CS, ~cpol, spi zeros, 2 bytes
  # (1) clear rx (ones)
  TEST_ST_OP(37, lw, sw, 0x00000002, 0, 0x20000000 );
  TEST_ST_OP(38, lw, sw, 0x00030401, 0, 0x20000008 );
  TEST_ST_WT_RD(39, lw, sw, 0x00000000, 0xFFFFFFFF, 0, 0x40000000, 0x20000010, 0x1);
  # (2) write 2 bytes zeros
  TEST_ST_OP(40, lw, sw, 0x00000001, 0, 0x20000000 );
  TEST_ST_OP(41, lw, sw, 0x00010401, 0, 0x20000008 );
  TEST_ST_WT_RD(42, lw, sw, 0x00000000, 0xFFFF0000, 0, 0x40000000, 0x20000010, 0x1);

  # auto CS, ~cpol, spi zeros, 3 bytes
  # (1) clear rx (ones)
  TEST_ST_OP(43, lw, sw, 0x00000002, 0, 0x20000000 );
  TEST_ST_OP(44, lw, sw, 0x00030401, 0, 0x20000008 );
  TEST_ST_WT_RD(45, lw, sw, 0x00000000, 0xFFFFFFFF, 0, 0x40000000, 0x20000010, 0x1);
  # (2) write 2 bytes zeros
  TEST_ST_OP(46, lw, sw, 0x00000001, 0, 0x20000000 );
  TEST_ST_OP(47, lw, sw, 0x00020401, 0, 0x20000008 );
  TEST_ST_WT_RD(48, lw, sw, 0x00000000, 0xFF000000, 0, 0x40000000, 0x20000010, 0x1);

  # auto CS, ~cpol, spi zeros, 4 bytes
  # (1) clear rx (ones)
  TEST_ST_OP(49, lw, sw, 0x00000002, 0, 0x20000000 );
  TEST_ST_OP(50, lw, sw, 0x00030401, 0, 0x20000008 );
  TEST_ST_WT_RD(51, lw, sw, 0x00000000, 0xFFFFFFFF, 0, 0x40000000, 0x20000010, 0x1);
  # (2) write 2 bytes zeros
  TEST_ST_OP(52, lw, sw, 0x00000001, 0, 0x20000000 );
  TEST_ST_OP(53, lw, sw, 0x00030401, 0, 0x20000008 );
  TEST_ST_WT_RD(54, lw, sw, 0x00000000, 0x00000000, 0, 0x40000000, 0x20000010, 0x1);

  ###

  # auto CS, ~cpol, spi loopback, 1 byte
  # (1) clear rx (zeros)
  TEST_ST_OP(55, lw, sw, 0x00000001, 0, 0x20000000 );
  TEST_ST_OP(56, lw, sw, 0x00030401, 0, 0x20000008 );
  TEST_ST_WT_RD(57, lw, sw, 0x00000000, 0x00000000, 0, 0x40000000, 0x20000010, 0x1);
  # (2) write 1 byte ones
  TEST_ST_OP(58, lw, sw, 0x00000000, 0, 0x20000000 );
  TEST_ST_OP(59, lw, sw, 0x00000401, 0, 0x20000008 );
  TEST_ST_WT_RD(60, lw, sw, 0xC0FFEEC0, 0x000000C0, 0, 0x40000000, 0x20000010, 0x1);

  # auto CS, ~cpol, spi loopback, 2 byte
  # (1) clear rx (zeros)
  TEST_ST_OP(61, lw, sw, 0x00000001, 0, 0x20000000 );
  TEST_ST_OP(62, lw, sw, 0x00030401, 0, 0x20000008 );
  TEST_ST_WT_RD(63, lw, sw, 0x00000000, 0x00000000, 0, 0x40000000, 0x20000010, 0x1);
  # (2) write 1 byte ones
  TEST_ST_OP(64, lw, sw, 0x00000000, 0, 0x20000000 );
  TEST_ST_OP(65, lw, sw, 0x00010401, 0, 0x20000008 );
  TEST_ST_WT_RD(66, lw, sw, 0xC0FFEEC0, 0x0000C0FF, 0, 0x40000000, 0x20000010, 0x1);

  # auto CS, ~cpol, spi loopback, 3 byte
  # (1) clear rx (zeros)
  TEST_ST_OP(67, lw, sw, 0x00000001, 0, 0x20000000 );
  TEST_ST_OP(68, lw, sw, 0x00030401, 0, 0x20000008 );
  TEST_ST_WT_RD(69, lw, sw, 0x00000000, 0x00000000, 0, 0x40000000, 0x20000010, 0x1);
  # (2) write 1 byte ones
  TEST_ST_OP(70, lw, sw, 0x00000000, 0, 0x20000000 );
  TEST_ST_OP(71, lw, sw, 0x00020401, 0, 0x20000008 );
  TEST_ST_WT_RD(72, lw, sw, 0xC0FFEEC0, 0x00C0FFEE, 0, 0x40000000, 0x20000010, 0x1);

  # auto CS, ~cpol, spi loopback, 4 byte
  # (1) clear rx (zeros)
  TEST_ST_OP(73, lw, sw, 0x00000001, 0, 0x20000000 );
  TEST_ST_OP(74, lw, sw, 0x00030401, 0, 0x20000008 );
  TEST_ST_WT_RD(75, lw, sw, 0x00000000, 0x00000000, 0, 0x40000000, 0x20000010, 0x1);
  # (2) write 1 byte ones
  TEST_ST_OP(76, lw, sw, 0x00000000, 0, 0x20000000 );
  TEST_ST_OP(77, lw, sw, 0x00030401, 0, 0x20000008 );
  TEST_ST_WT_RD(78, lw, sw, 0xC0FFEEC0, 0xC0FFEEC0, 0, 0x40000000, 0x20000010, 0x1);

  ###

  # auto CS, ~cpol, spi loopback, 1 byte
  # (1) clear rx (zeros)
  TEST_ST_OP(79, lw, sw, 0x00000001, 0, 0x20000000 );
  TEST_ST_OP(80, lw, sw, 0x00030401, 0, 0x20000008 );
  TEST_ST_WT_RD(81, lw, sw, 0x00000000, 0x00000000, 0, 0x40000000, 0x20000010, 0x1);
  # (2) write 1 byte ones
  TEST_ST_OP(82, lw, sw, 0x00000000, 0, 0x20000000 );
  TEST_ST_OP(83, lw, sw, 0x00000401, 0, 0x20000008 );
  TEST_ST_WT_RD(84, lw, sw, 0xA55AA55A, 0x000000A5, 0, 0x40000000, 0x20000010, 0x1);

  # auto CS, ~cpol, spi loopback, 2 byte
  # (1) clear rx (zeros)
  TEST_ST_OP(85, lw, sw, 0x00000001, 0, 0x20000000 );
  TEST_ST_OP(86, lw, sw, 0x00030401, 0, 0x20000008 );
  TEST_ST_WT_RD(87, lw, sw, 0x00000000, 0x00000000, 0, 0x40000000, 0x20000010, 0x1);
  # (2) write 1 byte ones
  TEST_ST_OP(88, lw, sw, 0x00000000, 0, 0x20000000 );
  TEST_ST_OP(89, lw, sw, 0x00010401, 0, 0x20000008 );
  TEST_ST_WT_RD(90, lw, sw, 0xA55AA55A, 0x0000A55A, 0, 0x40000000, 0x20000010, 0x1);

  # auto CS, ~cpol, spi loopback, 3 byte
  # (1) clear rx (zeros)
  TEST_ST_OP(91, lw, sw, 0x00000001, 0, 0x20000000 );
  TEST_ST_OP(92, lw, sw, 0x00030401, 0, 0x20000008 );
  TEST_ST_WT_RD(93, lw, sw, 0x00000000, 0x00000000, 0, 0x40000000, 0x20000010, 0x1);
  # (2) write 1 byte ones
  TEST_ST_OP(94, lw, sw, 0x00000000, 0, 0x20000000 );
  TEST_ST_OP(95, lw, sw, 0x00020401, 0, 0x20000008 );
  TEST_ST_WT_RD(96, lw, sw, 0xA55AA55A, 0x00A55AA5, 0, 0x40000000, 0x20000010, 0x1);

  # auto CS, ~cpol, spi loopback, 4 byte
  # (1) clear rx (zeros)
  TEST_ST_OP(97, lw, sw, 0x00000001, 0, 0x20000000 );
  TEST_ST_OP(98, lw, sw, 0x00030401, 0, 0x20000008 );
  TEST_ST_WT_RD(99, lw, sw, 0x00000000, 0x00000000, 0, 0x40000000, 0x20000010, 0x1);
  # (2) write 1 byte ones
  TEST_ST_OP(100, lw, sw, 0x00000000, 0, 0x20000000 );
  TEST_ST_OP(101, lw, sw, 0x00030401, 0, 0x20000008 );
  TEST_ST_WT_RD(102, lw, sw, 0xA55AA55A, 0xA55AA55A, 0, 0x40000000, 0x20000010, 0x1);


  TEST_PASSFAIL

RVTEST_CODE_END

  .data
RVTEST_DATA_BEGIN

  TEST_DATA

RVTEST_DATA_END
