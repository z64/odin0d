.PHONY: run check build

build: 0d.bin

run: build
	odin run .

check:
	odin check .

0d.bin: main.odin
	odin build .
