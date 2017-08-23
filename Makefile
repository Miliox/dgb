DCC    = dmd
DFLAGS = -w
LIBS   =
SRC    = src
TST    = tst
OBJ    = obj
OUT    = $(shell basename `pwd`)

SOURCES = $(wildcard $(SRC)/*.d)

.PHONY = all debug release profile clean test run

all: debug

debug:   DFLAGS += -g -debug
release: DFLAGS += -O -release -inline -noboundscheck
profile: DFLAGS += -g -O -profile

test: $(OUT)

run: $(OUT)
	@./$(OUT)

debug release profile: $(OUT)

$(OUT): $(SOURCES)
	@$(DCC) $(DFLAGS) -of$@ $(SOURCES) $(LIBS)

clean:
	@rm -f *~ $(OUT) trace.{def,log}

