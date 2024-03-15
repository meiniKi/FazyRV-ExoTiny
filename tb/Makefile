
YOSYS ?= yosys
NEXTPNR_ICE40=nextpnr-ice40
VERILATOR=verilator

SRCS_FAZY 	= $(wildcard ../rtl/*.v ../rtl/*.sv)
SRCS_SOC	= $(wildcard rtl/*.v rtl/*.sv)

lint:
	$(VERILATOR) --lint-only -Wall -Wno-GENUNNAMED -Wno-WIDTHEXPAND -Wno-UNUSEDPARAM -Wno-UNUSEDSIGNAL -Wno-WIDTHTRUNC -Wno-CASEOVERLAP $(SRCS_FAZY) $(SRCS_SOC)

icebreaker.json: $(SRCS_FAZY) $(SRCS_SOC)
	$(YOSYS) -l icebreaker.log -p 'synth_ice40 -top fazy_soc -json icebreaker.json' $^

icebreaker_syn.v: icebreaker.json
	yosys -p 'read_json icebreaker.json; write_verilog icebreaker_syn.v'

icebreaker.asc: icebreaker.pcf icebreaker.json
	nextpnr-ice40 --log pnr.log --freq 10 --up5k --package sg48 --asc icebreaker.asc --pcf icebreaker.pcf --json icebreaker.json

icebreaker.bin: icebreaker.asc
	icetime -d up5k -c 12 -mtr icebreaker.rpt icebreaker.asc
	icepack icebreaker.asc icebreaker.bin

clean:
	rm -vrf icebreaker.json icebreaker.asc icebreaker.log

.PHONY: clean icebreaker.json icebreaker_syn.v icebreaker.bin

