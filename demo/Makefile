
MAKE = make

prepare:
	fusesoc library add exotiny ../

demo.sim:
	$(MAKE) -C firmware
	fusesoc run --target=demo_sim exotiny --firmware=$(shell pwd)/firmware/build/firmware.hex --DEBUG --SIM

demo.icoboard:
	fusesoc run --target=demo_icoboard exotiny

clean:
	$(MAKE) -C firmware clean
	rm -rf build
