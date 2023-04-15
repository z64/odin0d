.PHONY: run check build

ODIN_FLAGS ?= -debug -o:none

build: demo_basics.bin demo_drawio.bin

run: build
	./demo_basics.bin
	./demo_drawio.bin

check:
	odin check demo_basics
	odin check demo_drawio

demo_basics.bin: demo_basics/*.odin 0d/*.odin
	odin build demo_basics $(ODIN_FLAGS)

demo_drawio.bin: demo_drawio/*.odin 0d/*.odin
	odin build demo_drawio $(ODIN_FLAGS)
