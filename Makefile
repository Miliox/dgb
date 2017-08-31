DCC    = dmd
DFLAGS = -w
LIBS   =
SRC    = source
OBJ    = obj
OUT    = $(shell basename `pwd`)

SOURCES = $(wildcard $(SRC)/*.d)

.PHONY = all debug release profile clean test run

all: debug

debug:   DFLAGS += -g -debug
release: DFLAGS += -O -release -inline -noboundscheck
profile: DFLAGS += -g -O -profile
test:    DFLAGS += -g -debug -unittest

run: $(OUT)
	@./$(OUT)

debug release profile test: $(OUT)

$(OUT): $(SOURCES)
	@$(DCC) $(DFLAGS) -of$@ $(SOURCES) $(LIBS)

clean:
	@rm -f *~ $(OUT) trace.{def,log}

