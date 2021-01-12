
FROM_DIR=$(dir $(realpath $(firstword $(MAKEFILE_LIST))))
OUT_DIR=$(FROM_DIR)/dlang
INSTALLER=$(OUT_DIR)/install.sh
INSTALL=bash $(INSTALLER)
COMPILER=dmd

install: $(OUT_DIR) $(INSTALLER)
	$(INSTALL) install --path $(OUT_DIR) $(COMPILER)

run: install
	$(INSTALL) get-path --path $(OUT_DIR) $(COMPILER)

install_help: $(OUT_DIR) $(INSTALLER)
	$(INSTALL) --help

$(INSTALLER):
	curl https://dlang.org/install.sh > $(INSTALLER)

$(OUT_DIR):
	mkdir -p $(OUT_DIR)