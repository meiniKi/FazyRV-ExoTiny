
#define TEST_ST_RD( testnum, load_inst, store_inst, write_data, result, offset, base ) \
    TEST_CASE( testnum, x3, result, \
      la  x1, base; \
      li  x2, write_data; \
      store_inst x2, offset(x1); \
      load_inst x3, offset(x1); \
    )

