PDK_ROOT ?= ../gf180mcu
PDK ?= gf180mcuD

fa16: ## Run LibreLane flow (synthesis, PnR, verification)
	librelane config.yaml --pdk ${PDK} --pdk-root ${PDK_ROOT} --manual-pdk --skip KLayout.DRC --skip Magic.DRC
.PHONY: fa16

fa16-drc: ## Run LibreLane flow (synthesis, PnR, verification)
	librelane config.yaml --pdk ${PDK} --pdk-root ${PDK_ROOT} --manual-pdk
.PHONY: fa16

