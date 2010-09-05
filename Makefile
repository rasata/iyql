SRCROOT = $(shell pwd)

PREFIX  = /usr/local

FIND    = find
INSTALL = install
HC      = ghc
HPC     = hpc

HCFLAGS =

MAIN_IYQL = dist/bin/iyql
MAIN_SRC  = $(foreach d,$(shell $(FIND) src/main/haskell/Yql -type d),$(wildcard $(d)/*.hs))
TEST_IYQL = dist/bin/test_iyql
TEST_SRC  = $(foreach d,$(shell $(FIND) src/test/haskell/Test/Yql -type d),$(wildcard $(d)/*.hs))

.PHONY: default
default: compile

.PHONY: compile
compile: $(MAIN_IYQL)

.PHONY: compile-hpc
compile-hpc: HCFLAGS += -fhpc
compile-hpc: $(MAIN_IYQL)

.PHONY: install
install: compile
	$(INSTALL) -m 0755 $(MAIN_IYQL) $(PREFIX)/bin

.PHONY: test
test: $(TEST_IYQL)
	$(TEST_IYQL)

.PHONY: test-hpc
test-hpc: compile-hpc $(TEST_IYQL)
	-@$(TEST_IYQL) >/dev/null
	$(HPC) markup --destdir=dist/hpc test_iyql.tix
	$(HPC) report test_iyql.tix

.PHONY: clean
clean:
	$(FIND) src/main/haskell -name \*.o -exec rm -f {} \;
	$(FIND) src/main/haskell -name \*.hi -exec rm -f {} \;
	$(FIND) src/test/haskell -name \*.o -exec rm -f {} \;
	$(FIND) src/test/haskell -name \*.hi -exec rm -f {} \;
	rm -f -r dist
	rm -f -r test_iyql.tix
	rm -f -r .hpc

dist:
	@[ -d $(@) ] || mkdir $(@)

dist/bin: dist
	@[ -d $(@) ] || mkdir $(@)

$(MAIN_IYQL): src/main/haskell/iyql.hs $(MAIN_SRC) dist/bin
	$(HC) -o $(@) -isrc/main/haskell --make $(HCFLAGS) $(<)

$(TEST_IYQL): src/test/haskell/test_iyql.hs $(MAIN_SRC) $(TEST_SRC) dist/bin
	$(HC) -o $(@) -isrc/test/haskell -isrc/main/haskell --make $(HCFLAGS) $(<)

