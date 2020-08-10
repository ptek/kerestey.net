engine=$(shell find dist-newstyle/build/x86_64-osx -type f -name 'engine' | sort | head -1)

build:
	$(engine) build

watch:
	$(engine) watch

check:
	$(engine) check

rebuild:
	rm -rf _site _cache
	make build

build-engine:
	cabal new-build
