
MAKE = make

prepare:
	fusesoc library add exotiny ../

demo.sim:
	$(MAKE) -C firmware
	fusesoc run --target=demo_sim exotiny --firmware=$(shell pwd)/firmware/build/firmware.hex --DEBUG --SIM

demo.icebreaker:
	fusesoc run --target=demo_icebreaker exotiny

clean:
	$(MAKE) -C firmware clean
	rm -rf build
