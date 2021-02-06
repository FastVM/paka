INSTALLER=bash $(BIN)/install.sh
DO_INSTALL=$(DC_CMD)
ENV=\$$

$(DC_CMD): $(BIN)/install.sh
	$(RUN) $(INSTALLER) install --path $(BIN) $(COMPILER) > $(BIN)/info.sh
	$(RUN) rm -f $(DC_CMD)
	$(RUN) echo "#!/usr/bin/env bash" > $(DC_CMD)
	$(RUN) ($(INSTALLER) get-path --path $(BIN) $(DC_CMD_PRE) | tr "\n" " "; echo $(ENV)@) >> $(DC_CMD)
	$(RUN) chmod +x $(DC_CMD)

getcomp: $(DO_INSTALL)

$(BIN)/install.sh:
	$(RUN) mkdir -p $(BIN)
	$(RUN) curl https://dlang.org/install.sh > $(BIN)/install.sh 2>/dev/null

dcomp: $(ALL_REQURED)
