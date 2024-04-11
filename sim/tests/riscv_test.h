#ifndef _ENV_PICORV32_TEST_H
#define _ENV_PICORV32_TEST_H

#ifndef TEST_FUNC_NAME
#  define TEST_FUNC_NAME mytest
#  define TEST_FUNC_TXT "mytest"
#  define TEST_FUNC_RET mytest_ret
#endif

#define RVTEST_RV32U
#define TESTNUM x28

// Define RVTEST_CODE_BEGIN in a way to avoid unaligned memory access
//#define RVTEST_CODE_BEGIN \
//	lui	a2,0x10000000>>12;	\
//	li  a1, 0x72756E00; \
//	sw	a1,0(a2);


#ifndef RVTEST_CODE_BEGIN
#define RVTEST_CODE_BEGIN		\
	.text;				\
	.global TEST_FUNC_NAME;		\
	.global TEST_FUNC_RET;		\
TEST_FUNC_NAME:				\
	lui	a0,%hi(.test_name);	\
	addi	a0,a0,%lo(.test_name);	\
	li	a2,0x2000000C;	\
.prname_next:				\
	lb	a1,0(a0);		\
	beq	a1,zero,.prname_done;	\
	sw	a1,0(a2);		\
	addi	a0,a0,1;		\
	jal	zero,.prname_next;	\
.test_name:				\
	.ascii TEST_FUNC_TXT;		\
	.byte 0x00;			\
	.balign 4, 0;			\
.prname_done:				\
	addi	a1,zero,'.';		\
	sw	a1,0(a2);		\
	sw	a1,0(a2);
#endif

#define RVTEST_PASS			\
	li	a0,0x2000000C;	\
	addi	a1,zero,'O';		\
	addi	a2,zero,'K';		\
	addi	a3,zero,'\n';		\
	sw	a1,0(a0);		\
	sw	a2,0(a0);		\
	sw	a3,0(a0);		\
	jal	zero,TEST_FUNC_RET;

#define RVTEST_FAIL			\
	li	a0,0x2000000C;	\
	addi	a1,zero,'E';		\
	addi	a2,zero,'R';		\
	addi	a3,zero,'O';		\
	addi	a4,zero,'\n';		\
	sw	a1,0(a0);		\
	sw	a2,0(a0);		\
	sw	a2,0(a0);		\
	sw	a3,0(a0);		\
	sw	a2,0(a0);		\
	sw	a4,0(a0);		\
	li a0,0x20000000;	\
	1: \
	li	t1, 0x29; \
	sw	t1,0(a0); \
	li	t1, 10; \
	2: \
	add t1,t1,-1; \
	beq t1,zero,3f; \
	j 2b; \
	3: \
	li	t1, 0x28; \
	sw	t1,0(a0); \
	li	t1, 1000; \
	4: \
	add t1,t1,-1; \
	beq t1,zero,5f; \
	j 4b; \
	5: \
	j 1b; \
	ebreak;

#define RVTEST_CODE_END
#define RVTEST_DATA_BEGIN .balign 4;
#define RVTEST_DATA_END

#endif
