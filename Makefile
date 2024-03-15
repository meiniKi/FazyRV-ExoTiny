
YOSYS ?= yosys
NEXTPNR_ICE40=nextpnr-ice40
VERILATOR=verilator

SRCS_FAZY 	= $(wildcard ../rtl/*.v ../rtl/*.sv)
SRCS_SOC	= $(wildcard rtl/*.v rtl/*.sv)

WORK_DIR_MAIN		:= work

WORK_DIR_RISCOF			:= $(WORK_DIR_MAIN)/work_riscof
SUMMARY_DIR_RISCOF 		:= $(WORK_DIR_MAIN)/summary_riscof

riscof.prepare: dv/config.ini
	fusesoc library add exotiny .
	riscof arch-test --clone
	riscof validateyaml --config=dv/config.ini

# param: <CHUNKSIZE>-<CONF>-<RFTYPE>
riscof.run.%: $(SRC_DESIGN) $(SRC_SYNTH)
	@echo "${BLUE}Simulating riscvtests for $*...${RESET}"
	$(eval CHUNKSIZE=$(word 1,$(subst -, ,$*)))
	$(eval CONF=$(word 2,$(subst -, ,$*)))
	$(eval RF=$(word 3,$(subst -, ,$*)))
	@echo "CHUNKSIZE: $(CHUNKSIZE)"
	@echo "CONF: $(CONF)"
	@echo "RF: $(RF)"
	mkdir -p $(WORK_DIR_RISCOF)
	mkdir -p $(SUMMARY_DIR_RISCOF)
	export RISCOF_CHUNKSIZE=$(CHUNKSIZE)
	export RISCOF_CONF=$(CONF)
	export RISCOF_RFTYPE=$(RF)
	riscof testlist --config=dv/config.ini --suite=riscv-arch-test/riscv-test-suite/ --env=riscv-arch-test/riscv-test-suite/env
	riscof run --no-browser --config=dv/config.ini --suite=riscv-arch-test/riscv-test-suite/ --env=riscv-arch-test/riscv-test-suite/env 2>&1 | tee $(SUMMARY_DIR_RISCOF)/tmp.txt
	@ ! grep -q -e "Failed" -e "ERROR" $(SUMMARY_DIR_RISCOF)/tmp.txt
	@echo $$? > $(SUMMARY_DIR_RISCOF)/$*.log
	@rm $(SUMMARY_DIR_RISCOF)/tmp.txt
# riscof exit code does not report failures, see Issue #102
# workaround using the tmp.txt file


clean:
	rm -vrf icebreaker.json icebreaker.asc icebreaker.log

.PHONY: clean icebreaker.json icebreaker_syn.v icebreaker.bin

