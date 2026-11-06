.PHONY: install build test fmt check

install:
	forge soldeer install

build:
	forge build

test:
	forge test -vvv

fmt:
	forge fmt

check:
	forge fmt --check
	forge build
	forge test -vvv
