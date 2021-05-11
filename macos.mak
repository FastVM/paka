OPT=0
BIN=bin
TMP=tmp
UNICODE=$(TMP)/UnicodeData.txt

all: $(BIN)
	ldc2 -i purr/app.d ext/*/plugin.d -O$(OPT) -of=$(BIN)/purr -Jtmp $(DFLAGS) 

$(TMP):
	mkdir -p $(TMP)

$(BIN):
	mkdir -p $(BIN)
	
$(UNICODE): dummy
ifeq ($(wildcard $(UNICODE)),)
	$(RUN) mkdir -p $(dir $(UNICODE))
	$(RUN) curl https://www.unicode.org/Public/UCD/latest/ucd/UnicodeData.txt > $@
else
ifeq ($(BOOL_RECURL),TRUE)
	$(RUN) mkdir -p $(dir $(UNICODE))
	$(RUN) curl https://www.unicode.org/Public/UCD/latest/ucd/UnicodeData.txt > $@
else
endif
endif