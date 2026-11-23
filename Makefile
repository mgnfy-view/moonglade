.PHONY: install build test fmt check

install:
	cd packages/contracts && forge soldeer install

build:
	cd packages/contracts && forge build

test:
	cd packages/contracts && forge test -vvv

fmt:
	cd packages/contracts && forge fmt

check:
	cd packages/contracts && forge fmt --check
	cd packages/contracts && forge build
	cd packages/contracts && forge test -vvv
